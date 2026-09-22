import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentScheduleSession extends StatefulWidget {
  const StudentScheduleSession({super.key});

  @override
  State<StudentScheduleSession> createState() =>
      _StudentScheduleSessionState();
}

class _StudentScheduleSessionState extends State<StudentScheduleSession> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, String> _tutorNameCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
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
      return iso;
    }
  }

  Future<String> _getTutorName(String tutorId) async {
    if (_tutorNameCache.containsKey(tutorId)) {
      return _tutorNameCache[tutorId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(tutorId)
          .get();
      final name =
          (doc.data() as Map<String, dynamic>?)?['fullName'] ?? 'Unknown Tutor';
      _tutorNameCache[tutorId] = name;
      return name;
    } catch (_) {
      return 'Unknown Tutor';
    }
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final course =
    '${data['courseCode'] ?? ''} ${data['courseName'] ?? ''}'.toLowerCase();
    final room = (data['room'] ?? '').toString().toLowerCase();
    final tutorName =
    (_tutorNameCache[data['tutorId']] ?? '').toLowerCase();
    return course.contains(q) || room.contains(q) || tutorName.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0047AB),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Available Sessions', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by course, tutor, or room...',
                prefixIcon:
                const Icon(Icons.search, color: Color(0xFF0047AB)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon:
                  const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFF0047AB).withOpacity(0.06),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF0047AB), width: 1.5),
                ),
              ),
            ),
          ),

          // Session list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF0047AB)));
                }

                final now = DateTime.now();
                final allDocs = (snap.data?.docs ?? []).where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final status = data['status'] ?? '';
                  if (status != 'upcoming' && status != 'active') {
                    return false;
                  }
                  try {
                    return DateTime.parse(data['dateTime'] ?? '')
                        .isAfter(now);
                  } catch (_) {
                    return false;
                  }
                }).toList()
                  ..sort((a, b) {
                    final aD = (a.data() as Map)['dateTime'] ?? '';
                    final bD = (b.data() as Map)['dateTime'] ?? '';
                    return aD.compareTo(bD);
                  });

                // Pre-fetch tutor names for search
                return FutureBuilder<void>(
                  future: Future.wait(
                    allDocs.map((doc) {
                      final tutorId =
                          (doc.data() as Map)['tutorId'] ?? '';
                      return tutorId.isNotEmpty
                          ? _getTutorName(tutorId)
                          : Future.value();
                    }),
                  ),
                  builder: (context, _) {
                    final sessions = allDocs.where((d) {
                      return _matchesSearch(
                          d.data() as Map<String, dynamic>,
                          _searchQuery);
                    }).toList();

                    if (sessions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 60,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No sessions match "$_searchQuery"'
                                  : 'No upcoming sessions available.',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final doc = sessions[index];
                        final d =
                        doc.data() as Map<String, dynamic>;
                        final tutorId = d['tutorId'] ?? '';
                        final cachedName =
                            _tutorNameCache[tutorId] ?? '...';

                        return _SessionCard(
                          sessionId: doc.id,
                          courseCode: d['courseCode'] ?? '',
                          courseName: d['courseName'] ?? '',
                          tutorId: tutorId,
                          tutorName: cachedName,
                          dateTime: _formatDateTime(
                              d['dateTime'] ?? ''),
                          room: d['room'] ?? '',
                          status: d['status'] ?? 'upcoming',
                          currentStudents:
                          d['enrolledCount'] ?? 0,
                          studentUid: uid,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _SessionCard extends StatefulWidget {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String tutorId;
  final String tutorName;
  final String dateTime;
  final String room;
  final String status;
  final int currentStudents;
  final String studentUid;

  static const int maxStudents = 15;

  const _SessionCard({
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.tutorId,
    required this.tutorName,
    required this.dateTime,
    required this.room,
    required this.status,
    required this.currentStudents,
    required this.studentUid,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _reserving = false;

  Future<void> _reserve(bool currentlyEnrolled, int enrolledCount) async {
    if (_reserving) return;
    setState(() => _reserving = true);

    final db = FirebaseFirestore.instance;

    try {
      if (currentlyEnrolled) {
        // Cancel reservation
        final existing = await db
            .collection('enrollments')
            .where('studentId', isEqualTo: widget.studentUid)
            .where('sessionId', isEqualTo: widget.sessionId)
            .limit(1)
            .get();

        for (final doc in existing.docs) {
          await doc.reference.delete();
        }

        // Decrement enrolled count
        await db.collection('sessions').doc(widget.sessionId).update({
          'enrolledCount': enrolledCount > 0 ? enrolledCount - 1 : 0,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservation cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Reserve — check capacity first
        if (enrolledCount >= _SessionCard.maxStudents) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This session is full.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _reserving = false);
          return;
        }

        await db.collection('enrollments').add({
          'studentId': widget.studentUid,
          'sessionId': widget.sessionId,
          'enrolledAt': Timestamp.now(),
        });

        await db.collection('sessions').doc(widget.sessionId).update({
          'enrolledCount': enrolledCount + 1,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session reserved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _reserving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.status == 'active';
    final statusColor = isActive ? Colors.green : Colors.orange;
    final statusLabel = isActive ? 'Active' : 'Upcoming';

    // Listen live to enrolled count + student's enrollment
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('enrollments')
          .where('sessionId', isEqualTo: widget.sessionId)
          .snapshots(),
      builder: (context, snap) {
        final enrollments = snap.data?.docs ?? [];
        final enrolledCount = enrollments.length;
        final isFull = enrolledCount >= _SessionCard.maxStudents;
        final isEnrolled = enrollments.any(
                (d) => (d.data() as Map)['studentId'] == widget.studentUid);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF0047AB),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0047AB).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.courseCode} - ${widget.courseName}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(statusLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tutor
              Row(children: [
                const Icon(Icons.person,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(widget.tutorName,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ]),
              const SizedBox(height: 5),

              // Date/time
              Row(children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(widget.dateTime,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70))),
              ]),
              const SizedBox(height: 5),

              // Room
              Row(children: [
                const Icon(Icons.location_on,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(widget.room,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ]),
              const SizedBox(height: 5),

              // Capacity
              Row(children: [
                const Icon(Icons.people,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  '$enrolledCount / ${_SessionCard.maxStudents} students',
                  style: TextStyle(
                    fontSize: 13,
                    color: isFull && !isEnrolled
                        ? Colors.redAccent.shade100
                        : Colors.white70,
                    fontWeight: isFull && !isEnrolled
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (isFull && !isEnrolled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Full',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ],
              ]),
              const SizedBox(height: 12),

              // Reserve / Cancel / Full button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isFull && !isEnrolled) || _reserving
                      ? null
                      : () => _reserve(isEnrolled, enrolledCount),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnrolled
                        ? Colors.orange
                        : isFull
                        ? Colors.grey
                        : Colors.white,
                    foregroundColor: isEnrolled
                        ? Colors.white
                        : const Color(0xFF0047AB),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Colors.grey.shade600,
                  ),
                  child: _reserving
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                    isEnrolled
                        ? 'Cancel Reservation'
                        : isFull
                        ? 'Session Full'
                        : 'Reserve Spot',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isEnrolled
                          ? Colors.white
                          : isFull
                          ? Colors.white
                          : const Color(0xFF0047AB),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}