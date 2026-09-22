import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/bottom_nav_bar.dart';
import 'student_schedule_session.dart';
import 'student_profile.dart';
import 'student_scan_qr.dart';
import 'student_attendance.dart';

class StudentHomeDashboard extends StatefulWidget {
  const StudentHomeDashboard({super.key});

  @override
  State<StudentHomeDashboard> createState() =>
      _StudentHomeDashboardState();
}

class _StudentHomeDashboardState extends State<StudentHomeDashboard> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) =>
      setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      StudentHomeContent(onScanTap: () => _onItemTapped(2)),
      const StudentScheduleSession(),
      StudentScanQR(onBack: () => _onItemTapped(0)),
      const StudentAttendance(),
      const StudentProfile(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        role: 'student',
      ),
    );
  }
}


class StudentHomeContent extends StatelessWidget {
  final VoidCallback onScanTap;
  const StudentHomeContent({super.key, required this.onScanTap});

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
      return '${months[dt.month - 1]} ${dt.day}  •  $hour:$min $ampm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    return Container(
      color: const Color(0xFF0047AB),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Home Dashboard',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<DocumentSnapshot>(
                    future: db.collection('users').doc(uid).get(),
                    builder: (context, snap) {
                      final name = snap.hasData
                          ? ((snap.data!.data() as Map<String,
                          dynamic>?)?['fullName'] ??
                          'Student')
                          : 'Student';
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0066FF),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          'Welcome Back, $name!',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // Quick Check-In
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0066FF),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Check-In',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: onScanTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize:
                              const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Scan QR Code',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // My Reserved Sessions — only sessions this student enrolled in
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0066FF),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Upcoming Sessions',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 15),

                          // Step 1: get student's enrollments
                          StreamBuilder<QuerySnapshot>(
                            stream: db
                                .collection('enrollments')
                                .where('studentId', isEqualTo: uid)
                                .snapshots(),
                            builder: (context, enrollSnap) {
                              if (!enrollSnap.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white));
                              }

                              final enrolledSessionIds = enrollSnap
                                  .data!.docs
                                  .map((d) => (d.data()
                              as Map)['sessionId'] as String)
                                  .toList();

                              if (enrolledSessionIds.isEmpty) {
                                return Column(
                                  children: [
                                    const Text(
                                      'You haven\'t reserved any sessions yet.',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: () {
                                        // Navigate to schedule tab (index 1)
                                        final dashboard = context
                                            .findAncestorStateOfType<
                                            _StudentHomeDashboardState>();
                                        dashboard?._onItemTapped(1);
                                      },
                                      icon: const Icon(
                                          Icons.search,
                                          color: Colors.white),
                                      label: const Text(
                                        'Browse Sessions',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                            FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              // Step 2: fetch those sessions
                              return StreamBuilder<QuerySnapshot>(
                                stream: db
                                    .collection('sessions')
                                    .snapshots(),
                                builder: (context, sessionSnap) {
                                  if (!sessionSnap.hasData) {
                                    return const Center(
                                        child:
                                        CircularProgressIndicator(
                                            color: Colors.white));
                                  }

                                  final now = DateTime.now();

                                  // Only show enrolled sessions that are upcoming/active
                                  final mySessions = sessionSnap
                                      .data!.docs
                                      .where((doc) {
                                    if (!enrolledSessionIds
                                        .contains(doc.id)) {
                                      return false;
                                    }
                                    final data = doc.data()
                                    as Map<String, dynamic>;
                                    final status =
                                        data['status'] ?? '';
                                    if (status != 'upcoming' &&
                                        status != 'active') {
                                      return false;
                                    }
                                    try {
                                      return DateTime.parse(
                                          data['dateTime'] ??
                                              '')
                                          .isAfter(now);
                                    } catch (_) {
                                      return false;
                                    }
                                  })
                                      .toList()
                                    ..sort((a, b) {
                                      final aD = (a.data()
                                      as Map)['dateTime'] ??
                                          '';
                                      final bD = (b.data()
                                      as Map)['dateTime'] ??
                                          '';
                                      return aD.compareTo(bD);
                                    });

                                  if (mySessions.isEmpty) {
                                    return const Text(
                                      'No upcoming reserved sessions.',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14),
                                    );
                                  }

                                  return Column(
                                    children: mySessions
                                        .take(3)
                                        .map((doc) {
                                      final d = doc.data()
                                      as Map<String, dynamic>;
                                      return Padding(
                                        padding:
                                        const EdgeInsets.only(
                                            bottom: 10),
                                        child: _ReservedSessionCard(
                                          courseCode:
                                          d['courseCode'] ?? '',
                                          courseName:
                                          d['courseName'] ?? '',
                                          tutorId:
                                          d['tutorId'] ?? '',
                                          dateTime: _formatDateTime(
                                              d['dateTime'] ?? ''),
                                          room: d['room'] ?? '',
                                          status: d['status'] ??
                                              'upcoming',
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Attendance stats
                    StreamBuilder<QuerySnapshot>(
                      stream: db
                          .collection('checkins')
                          .where('studentId', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final all = snap.data?.docs ?? [];
                        final confirmed = all
                            .where((d) =>
                        (d.data() as Map)['status'] ==
                            'confirmed')
                            .length;

                        final now = DateTime.now();
                        final weekStart = now.subtract(
                            Duration(days: now.weekday - 1));
                        final thisWeek = all.where((d) {
                          final ts =
                          (d.data() as Map)['scannedAt'];
                          if (ts == null) return false;
                          return (ts as Timestamp)
                              .toDate()
                              .isAfter(weekStart);
                        }).length;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: const Color(0xFF0066FF),
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Attendance',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                      child: _statCard(
                                          '$confirmed',
                                          'Sessions\nAttended')),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _statCard(
                                          '$thisWeek',
                                          'This Week\nAttended')),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String number, String label) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF0047AB), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(number,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0047AB))),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}


class _ReservedSessionCard extends StatelessWidget {
  final String courseCode;
  final String courseName;
  final String tutorId;
  final String dateTime;
  final String room;
  final String status;

  const _ReservedSessionCard({
    required this.courseCode,
    required this.courseName,
    required this.tutorId,
    required this.dateTime,
    required this.room,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course + active badge
          Row(
            children: [
              Expanded(
                child: Text(
                  '$courseCode - $courseName',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('Active',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 5),

          // Tutor name
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(tutorId)
                .get(),
            builder: (context, snap) {
              final name = snap.hasData
                  ? ((snap.data!.data() as Map<String,
                  dynamic>?)?['fullName'] ??
                  'Unknown Tutor')
                  : '...';
              return Row(children: [
                const Icon(Icons.person, size: 13, color: Colors.black54),
                const SizedBox(width: 4),
                Text('Tutor: $name',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ]);
            },
          ),
          const SizedBox(height: 3),

          Row(children: [
            const Icon(Icons.access_time,
                size: 13, color: Colors.black54),
            const SizedBox(width: 4),
            Text(dateTime,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
          ]),
          const SizedBox(height: 3),

          Row(children: [
            const Icon(Icons.location_on,
                size: 13, color: Colors.black54),
            const SizedBox(width: 4),
            Text(room,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
          ]),

          // Reserved badge
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.bookmark,
                size: 13, color: Color(0xFF0047AB)),
            const SizedBox(width: 4),
            const Text('Reserved',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0047AB),
                    fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}