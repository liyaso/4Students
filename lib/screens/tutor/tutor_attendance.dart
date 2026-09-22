import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tutor_attendance_details.dart';

class TutorAttendance extends StatelessWidget {
  const TutorAttendance({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutor Attendance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF0047AB),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('sessions')
            .where('tutorId', isEqualTo: uid)
            .snapshots(),
        builder: (context, sessionSnap) {
          if (sessionSnap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFF0047AB)));
          }

          final allSessions = sessionSnap.data?.docs ?? [];
          final sessionIds = allSessions.map((d) => d.id).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('checkins')
                .where('status', isEqualTo: 'confirmed')
                .snapshots(),
            builder: (context, checkinSnap) {
              // Only count checkins for this tutor's sessions
              final confirmedCheckins = (checkinSnap.data?.docs ?? [])
                  .where((d) => sessionIds
                  .contains((d.data() as Map)['sessionId']))
                  .toList();

              final totalSessions = allSessions.length;
              final totalCheckins = confirmedCheckins.length;
              final avgRate = totalSessions > 0 && totalCheckins > 0
                  ? '${((totalCheckins / (totalSessions * 30)) * 100).clamp(0, 100).toStringAsFixed(0)}%'
                  : '0%';

              // Completed sessions only for history
              final completed = allSessions
                  .where((d) =>
              (d.data() as Map)['status'] == 'completed')
                  .toList()
                ..sort((a, b) {
                  final aD =
                      (a.data() as Map)['dateTime'] ?? '';
                  final bD =
                      (b.data() as Map)['dateTime'] ?? '';
                  return bD.compareTo(aD);
                });

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Stats card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0047AB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Session Statistics',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                  child: _statBox(
                                      '$totalSessions',
                                      'Total Sessions')),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _statBox(
                                      '$totalCheckins', 'Check-Ins')),
                              const SizedBox(width: 10),
                              Expanded(
                                  child:
                                  _statBox(avgRate, 'Avg Rate')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Previous sessions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0047AB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Previous Sessions',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 15),
                          if (completed.isEmpty)
                            const Text(
                                'No completed sessions yet.',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14))
                          else
                            ...completed.map((doc) {
                              final d =
                              doc.data() as Map<String, dynamic>;
                              // Count confirmed checkins for this session
                              final sessionCheckins = confirmedCheckins
                                  .where((c) =>
                              (c.data() as Map)[
                              'sessionId'] ==
                                  doc.id)
                                  .length;
                              final max =
                              (d['maxStudents'] ?? 30) as int;
                              final rate = max > 0
                                  ? '${((sessionCheckins / max) * 100).clamp(0, 100).toStringAsFixed(0)}%'
                                  : '0%';
                              final rateVal = max > 0
                                  ? (sessionCheckins / max * 100)
                                  .clamp(0, 100)
                                  : 0.0;
                              final statusColor = rateVal >= 75
                                  ? Colors.green
                                  : rateVal >= 50
                                  ? Colors.orange
                                  : Colors.red;

                              return Padding(
                                padding:
                                const EdgeInsets.only(bottom: 15),
                                child: _SessionCard(
                                  sessionId: doc.id,
                                  courseName:
                                  '${d['courseCode']} - ${d['courseName']}',
                                  dateTime: d['dateTime'] ?? '',
                                  room: d['room'] ?? '',
                                  attendanceRate: rate,
                                  statusColor: statusColor,
                                  confirmedCount: sessionCheckins,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String sessionId;
  final String courseName;
  final String dateTime;
  final String room;
  final String attendanceRate;
  final Color statusColor;
  final int confirmedCount;

  const _SessionCard({
    required this.sessionId,
    required this.courseName,
    required this.dateTime,
    required this.room,
    required this.attendanceRate,
    required this.statusColor,
    required this.confirmedCount,
  });

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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $ampm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TutorAttendanceDetails(
            sessionId: sessionId,
            courseName: courseName,
            time: _formatDateTime(dateTime),
            room: room,
            attendanceRate: attendanceRate,
            statusColor: statusColor,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(courseName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ID: ${sessionId.substring(0, 8)}...',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(attendanceRate,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(_formatDateTime(dateTime),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.room, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(room,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ]),
          ],
        ),
      ),
    );
  }
}