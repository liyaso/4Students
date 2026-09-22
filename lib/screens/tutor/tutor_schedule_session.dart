import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TutorScheduleSession extends StatefulWidget {
  const TutorScheduleSession({super.key});

  @override
  State<TutorScheduleSession> createState() => _TutorScheduleSessionState();
}

class _TutorScheduleSessionState extends State<TutorScheduleSession> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _selectedTopic;
  DateTime? _selectedDate;
  String? _selectedTime;
  final TextEditingController _roomController = TextEditingController();
  bool _creating = false;

  final List<String> _topics = [
    'MATH 2212 - Calculus of One Variable II',
    'MATH 2211 - Calculus of One Variable I',
    'MATH 1113 - Pre Calculus',
    'MATH 2641 - Linear Algebra I',
    'CSC 1301 - Principles of Computer Science I',
    'CSC 2720 - Data Structures',
    'CSC 3320 - System Level Programming',
  ];

  final List<String> _timeSlots = [
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 1:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:30 PM',
    '5:00 PM - 6:00 PM',
  ];

  String _parseCourseCode(String topic) => topic.split(' - ').first.trim();
  String _parseCourseName(String topic) {
    final parts = topic.split(' - ');
    return parts.length > 1 ? parts[1].trim() : topic;
  }

  DateTime _buildDateTime(DateTime date, String timeSlot) {
    final startTime = timeSlot.split(' - ').first.trim();
    final parts = startTime.split(':');
    int hour = int.parse(parts[0]);
    final minPart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
    final int minute = int.parse(minPart);
    final bool isPm = startTime.contains('PM') && hour != 12;
    if (isPm) hour += 12;
    if (startTime.contains('AM') && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0047AB)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _createSession() async {
    if (_selectedTopic == null ||
        _selectedTime == null ||
        _selectedDate == null ||
        _roomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      final uid = _auth.currentUser!.uid;
      final sessionDateTime = _buildDateTime(_selectedDate!, _selectedTime!);

      // 1. Create the session
      final sessionRef = await _db.collection('sessions').add({
        'tutorId': uid,
        'courseCode': _parseCourseCode(_selectedTopic!),
        'courseName': _parseCourseName(_selectedTopic!),
        'dateTime': sessionDateTime.toIso8601String(),
        'room': _roomController.text.trim(),
        'status': 'upcoming',
        'currentStudents': 0,
        'maxStudents': 30,
        'createdAt': Timestamp.now(),
      });

      // 2. Create a QR code for it immediately
      await _db.collection('qrCodes').add({
        'sessionId': sessionRef.id,
        'tutorId': uid,
        'active': true,
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(
          sessionDateTime.add(const Duration(hours: 24)),
        ),
      });

      if (!mounted) return;

      setState(() {
        _selectedTopic = null;
        _selectedTime = null;
        _selectedDate = null;
        _roomController.clear();
        _creating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session created and QR code generated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating session: $e')),
      );
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await _db.collection('sessions').doc(sessionId).delete();

      final qrSnap = await _db
          .collection('qrCodes')
          .where('sessionId', isEqualTo: sessionId)
          .get();
      for (final doc in qrSnap.docs) {
        await doc.reference.update({'active': false});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Session deleted'), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting session: $e')),
      );
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour =
      dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$min $ampm';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0047AB),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Schedule Session', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form header
            const Text('Generate An',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0047AB))),
            const Text('Upcoming Session',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0047AB))),
            const SizedBox(height: 20),

            // Topic dropdown
            _FormCard(
              label: 'Choose Topic...',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedTopic,
                  hint: const Text('Select a topic'),
                  items: _topics
                      .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t,
                          style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTopic = v),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Date picker
            _FormCard(
              label: 'Choose Date...',
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        _selectedDate == null
                            ? 'Select a date'
                            : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedDate == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Time slot
            _FormCard(
              label: 'Choose Available Time...',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedTime,
                  hint: const Text('Select time slot'),
                  items: _timeSlots
                      .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTime = v),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Room input
            _FormCard(
              label: 'Input Scheduled Room',
              child: TextField(
                controller: _roomController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Room 204',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creating ? null : _createSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0047AB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _creating
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'Create Session & Generate QR',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Upcoming sessions header
            const Text('Upcoming',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0047AB))),
            const Text('Sessions',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0047AB))),
            const SizedBox(height: 15),


            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('sessions')
                  .where('tutorId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0047AB)),
                  );

                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                // Filter and sort in Dart — no composite index needed
                final docs = (snapshot.data?.docs ?? [])
                    .where((doc) {
                  final status =
                  (doc.data() as Map<String, dynamic>)['status'];
                  return status == 'upcoming' || status == 'active';
                })
                    .toList()
                  ..sort((a, b) {
                    final aDate =
                        (a.data() as Map<String, dynamic>)['dateTime'] ?? '';
                    final bDate =
                        (b.data() as Map<String, dynamic>)['dateTime'] ?? '';
                    return aDate.compareTo(bDate);
                  });

                if (docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0047AB).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'No upcoming sessions. Create one above!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: _buildSessionCard(doc.id, data),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(String sessionId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'upcoming';
    final statusColor = status == 'active' ? Colors.green : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0047AB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['courseCode'] ?? ''} - ${data['courseName'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text('Session ID: $sessionId',
                    style:
                    const TextStyle(fontSize: 11, color: Colors.white54)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _formatDateTime(data['dateTime'] ?? ''),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(data['room'] ?? '',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Session'),
                    content: const Text(
                        'Are you sure you want to delete this session?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteSession(sessionId);
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                child: const Text('Delete',
                    style:
                    TextStyle(fontSize: 12, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              if (status == 'upcoming')
                ElevatedButton(
                  onPressed: () async {
                    await _db
                        .collection('sessions')
                        .doc(sessionId)
                        .update({'status': 'active'});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session is now active!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  child: const Text('Start Session',
                      style:
                      TextStyle(fontSize: 10, color: Colors.white)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }
}

class _FormCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0047AB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}