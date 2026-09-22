import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TutorAttendanceDetails extends StatelessWidget {
  final String sessionId;
  final String courseName;
  final String time;
  final String room;
  final String attendanceRate;
  final Color statusColor;

  const TutorAttendanceDetails({
    super.key,
    required this.sessionId,
    required this.courseName,
    required this.time,
    required this.room,
    required this.attendanceRate,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        backgroundColor: const Color(0xFF0066FF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0066FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(courseName,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Session ID: $sessionId',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Session info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session Info',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.access_time, 'Time', time),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.room, 'Room', room),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Attendance rate
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance Rate',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 15),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: statusColor, width: 2),
                      ),
                      child: Text(attendanceRate,
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live student checkin list
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF0066FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Student Check-Ins',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 15),
                  StreamBuilder<QuerySnapshot>(
                    stream: db
                        .collection('checkins')
                        .where('sessionId', isEqualTo: sessionId)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white));
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Text('No check-ins recorded.',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14));
                      }
                      return Column(
                        children: docs.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return _CheckinRow(
                            studentId: d['studentId'] ?? '',
                            status: d['status'] ?? 'pending',
                            scannedAt: d['scannedAt'],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0066FF)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
          ],
        ),
      ],
    );
  }
}

class _CheckinRow extends StatelessWidget {
  final String studentId;
  final String status;
  final dynamic scannedAt;

  const _CheckinRow({
    required this.studentId,
    required this.status,
    required this.scannedAt,
  });

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as Timestamp).toDate();
      final hour =
      dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = status == 'confirmed';
    final denied = status == 'denied';
    final color = confirmed
        ? Colors.green.shade600
        : denied
        ? Colors.red.shade400
        : Colors.orange.shade700;
    final icon = confirmed
        ? Icons.check_circle
        : denied
        ? Icons.cancel
        : Icons.hourglass_empty;
    final label = confirmed
        ? 'Confirmed'
        : denied
        ? 'Denied'
        : 'Pending';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, snap) {
        final name = snap.hasData
            ? ((snap.data!.data()
        as Map<String, dynamic>?)?['fullName'] ??
            'Unknown')
            : '...';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                const Color(0xFF0047AB).withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFF0047AB),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    Text('Scanned at ${_formatTime(scannedAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        );
      },
    );
  }
}