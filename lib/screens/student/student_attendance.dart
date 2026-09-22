import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAttendance extends StatelessWidget {
  const StudentAttendance({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
        backgroundColor: const Color(0xFF0047AB),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('checkins')
            .where('studentId', isEqualTo: uid)
            .snapshots(),
        builder: (context, checkinSnap) {
          if (checkinSnap.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFF0047AB)));
          }

          final checkins = (checkinSnap.data?.docs ?? [])
            ..sort((a, b) {
              final aT = (a.data() as Map)['scannedAt'];
              final bT = (b.data() as Map)['scannedAt'];
              if (aT == null || bT == null) return 0;
              return (bT as Timestamp).compareTo(aT as Timestamp);
            });

          final totalCheckins = checkins.length;
          final confirmed =
              checkins.where((d) => (d.data() as Map)['status'] == 'confirmed').length;

          // Avg rate — confirmed / total (if any)
          final avgRate = totalCheckins > 0
              ? '${((confirmed / totalCheckins) * 100).toStringAsFixed(0)}%'
              : '0%';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: const Color(0xFF0047AB),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attendance Summary',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                              child: _statBox(
                                  '$totalCheckins', 'Total\nSessions')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _statBox(
                                  '$confirmed', 'Check-Ins')),
                          const SizedBox(width: 10),
                          Expanded(
                              child:
                              _statBox(avgRate, 'Confirmed\nRate')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // History list
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: const Color(0xFF0047AB),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Session History',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 15),
                      if (checkins.isEmpty)
                        const Text('No sessions yet.',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14))
                      else
                        ...checkins.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: _CheckinCard(
                              sessionId: d['sessionId'] ?? '',
                              status: d['status'] ?? 'pending',
                              scannedAt: d['scannedAt'],
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
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
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

class _CheckinCard extends StatelessWidget {
  final String sessionId;
  final String status;
  final dynamic scannedAt;

  const _CheckinCard({
    required this.sessionId,
    required this.status,
    required this.scannedAt,
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = status == 'confirmed';
    final denied = status == 'denied';
    final statusColor = confirmed
        ? Colors.green
        : denied
        ? Colors.red
        : Colors.orange;
    final statusLabel = confirmed
        ? 'Confirmed'
        : denied
        ? 'Denied'
        : 'Pending';
    final statusIcon = confirmed
        ? Icons.check_circle
        : denied
        ? Icons.cancel
        : Icons.hourglass_empty;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .get(),
      builder: (context, snap) {
        final d = snap.hasData
            ? (snap.data!.data() as Map<String, dynamic>? ?? {})
            : <String, dynamic>{};
        final courseName = d.isEmpty
            ? 'Loading...'
            : '${d['courseCode'] ?? ''} - ${d['courseName'] ?? ''}';
        final room = d['room'] ?? '';

        // Fetch tutor name
        final tutorId = d['tutorId'] ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(courseName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusLabel,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (tutorId.isNotEmpty)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(tutorId)
                      .get(),
                  builder: (context, tSnap) {
                    final tName = tSnap.hasData
                        ? ((tSnap.data!.data() as Map<String,
                        dynamic>?)?['fullName'] ??
                        '')
                        : '';
                    if (tName.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.person_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(tName,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ]),
                    );
                  },
                ),

              Row(children: [
                const Icon(Icons.access_time,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 5),
                Text(_formatTimestamp(scannedAt),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ]),

              if (room.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.room, size: 14, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(room,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}