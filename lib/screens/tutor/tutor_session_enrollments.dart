import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TutorSessionEnrollments extends StatelessWidget {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String dateTime;
  final String room;

  const TutorSessionEnrollments({
    super.key,
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.dateTime,
    required this.room,
  });

  static const int maxStudents = 15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Reservations'),
        backgroundColor: const Color(0xFF0047AB),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('enrollments')
            .where('sessionId', isEqualTo: sessionId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF0047AB)));
          }

          final enrollments = snap.data?.docs ?? [];
          final enrolledCount = enrollments.length;
          final spotsLeft = maxStudents - enrolledCount;
          final isFull = spotsLeft <= 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Session header ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0047AB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$courseCode – $courseName',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(dateTime,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(room,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Capacity summary ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isFull
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFull
                          ? Colors.red.shade200
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Enrolled count
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$enrolledCount',
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0047AB)),
                            ),
                            const Text('Reserved',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 50,
                          color: Colors.grey.shade300),
                      // Capacity
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$maxStudents',
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54),
                            ),
                            const Text('Capacity',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 50,
                          color: Colors.grey.shade300),
                      // Spots left
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              isFull ? '0' : '$spotsLeft',
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: isFull
                                      ? Colors.red.shade500
                                      : Colors.green.shade600),
                            ),
                            Text(
                              isFull ? 'Full' : 'Spots Left',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isFull
                                      ? Colors.red.shade500
                                      : Colors.green.shade600,
                                  fontWeight: isFull
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Student list ──
                Row(
                  children: [
                    const Text(
                      'Reserved Students',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0047AB)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0047AB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$enrolledCount',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0047AB)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (enrollments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No students have reserved this session yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: enrollments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      return _EnrolledStudentRow(
                        studentId: data['studentId'] ?? '',
                        enrolledAt: data['enrolledAt'],
                        index: index + 1,
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}


class _EnrolledStudentRow extends StatelessWidget {
  final String studentId;
  final dynamic enrolledAt;
  final int index;

  const _EnrolledStudentRow({
    required this.studentId,
    required this.enrolledAt,
    required this.index,
  });

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as Timestamp).toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour =
      dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return 'Reserved ${months[dt.month - 1]} ${dt.day}  $hour:$min $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, snap) {
        final data =
            snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['fullName'] ?? 'Unknown Student';
        final email = data['email'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              // Number badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0047AB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0047AB)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar
              CircleAvatar(
                backgroundColor:
                const Color(0xFF0047AB).withOpacity(0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFF0047AB),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),

              // Name + email + reserved time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snap.hasData ? name : '...',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                    if (email.isNotEmpty)
                      Text(email,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    Text(
                      _formatTimestamp(enrolledAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.bookmark,
                  color: Color(0xFF0047AB), size: 18),
            ],
          ),
        );
      },
    );
  }
}