import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/bottom_nav_bar.dart';
import 'tutor_schedule_session.dart';
import 'tutor_profile.dart';
import 'tutor_attendance.dart';
import '../shared/qr_test_screen.dart';

class TutorHomeDashboard extends StatefulWidget {
  const TutorHomeDashboard({super.key});

  @override
  State<TutorHomeDashboard> createState() => _TutorHomeDashboardState();
}

class _TutorHomeDashboardState extends State<TutorHomeDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const TutorHomeContent(),
    const TutorScheduleSession(),
    const QrTestScreen(),
    const TutorAttendance(),
    const TutorProfile(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        role: 'tutor',
      ),
    );
  }
}

class TutorHomeContent extends StatefulWidget {
  const TutorHomeContent({super.key});

  @override
  State<TutorHomeContent> createState() => _TutorHomeContentState();
}

class _TutorHomeContentState extends State<TutorHomeContent> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  void _navigateToTab(int index) {
    final state =
    context.findAncestorStateOfType<_TutorHomeDashboardState>();
    state?._onItemTapped(index);
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final hour =
      dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    } catch (_) {
      return iso;
    }
  }

  bool _isToday(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      return dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0047AB),
      ),
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
                  // Live welcome with real name
                  FutureBuilder<DocumentSnapshot>(
                    future: _db.collection('users').doc(_uid).get(),
                    builder: (context, snap) {
                      final name = snap.hasData
                          ? (snap.data!.data() as Map<String, dynamic>)['fullName'] ?? 'Tutor'
                          : 'Tutor';
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0066FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                    // Session Management buttons
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
                          const Text('Session Management',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _navigateToTab(2),
                                  icon: const Icon(
                                      Icons.qr_code_scanner,
                                      size: 20),
                                  label: const Text('Generate QR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _navigateToTab(1),
                                  icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 20),
                                  label: const Text('New Session'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Today's Sessions — live
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
                          const Text("Today's Sessions",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 15),
                          StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('sessions')
                                .where('tutorId', isEqualTo: _uid)
                                .snapshots(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white));
                              }
                              final today = snap.data!.docs
                                  .where((d) => _isToday(
                                  (d.data() as Map)['dateTime'] ?? ''))
                                  .toList();
                              if (today.isEmpty) {
                                return const Text(
                                    'No sessions today.',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14));
                              }
                              return Column(
                                children: today.map((doc) {
                                  final d =
                                  doc.data() as Map<String, dynamic>;
                                  final status = d['status'] ?? 'upcoming';
                                  final statusColor =
                                  status == 'active'
                                      ? Colors.green
                                      : Colors.orange;
                                  return Padding(
                                    padding:
                                    const EdgeInsets.only(bottom: 10),
                                    child: _buildSessionCard(
                                      '${d['courseCode']} - ${d['courseName']}',
                                      _formatTime(d['dateTime'] ?? ''),
                                      '${d['currentStudents'] ?? 0}/${d['maxStudents'] ?? 0} students',
                                      status[0].toUpperCase() +
                                          status.substring(1),
                                      statusColor,
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // This Week Stats — live
                    StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('sessions')
                          .where('tutorId', isEqualTo: _uid)
                          .snapshots(),
                      builder: (context, sessionSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: _db
                              .collection('checkins')
                              .where('status', isEqualTo: 'confirmed')
                              .snapshots(),
                          builder: (context, checkinSnap) {
                            final now = DateTime.now();
                            final weekStart = now
                                .subtract(Duration(days: now.weekday - 1));

                            // Sessions this week
                            int weekSessions = 0;
                            int weekCheckins = 0;
                            int totalCheckins = 0;
                            int totalSessions = 0;

                            if (sessionSnap.hasData) {
                              final sessionIds = <String>{};
                              for (final doc in sessionSnap.data!.docs) {
                                final d =
                                doc.data() as Map<String, dynamic>;
                                totalSessions++;
                                sessionIds.add(doc.id);
                                try {
                                  final dt =
                                  DateTime.parse(d['dateTime'] ?? '');
                                  if (dt.isAfter(weekStart)) {
                                    weekSessions++;
                                  }
                                } catch (_) {}
                              }

                              if (checkinSnap.hasData) {
                                for (final doc
                                in checkinSnap.data!.docs) {
                                  final d =
                                  doc.data() as Map<String, dynamic>;
                                  if (sessionIds
                                      .contains(d['sessionId'])) {
                                    totalCheckins++;
                                    final scannedAt = d['scannedAt'];
                                    if (scannedAt != null) {
                                      final dt =
                                      (scannedAt as Timestamp)
                                          .toDate();
                                      if (dt.isAfter(weekStart)) {
                                        weekCheckins++;
                                      }
                                    }
                                  }
                                }
                              }
                            }

                            final rate = totalSessions > 0 &&
                                totalCheckins > 0
                                ? '${((totalCheckins / (totalSessions * 30)) * 100).clamp(0, 100).toStringAsFixed(0)}%'
                                : '0%';

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0066FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('This Week',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  const SizedBox(height: 15),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: _buildStatCard(
                                              '$weekSessions',
                                              'Sessions')),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildStatCard(
                                              '$weekCheckins',
                                              'Check-Ins')),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildStatCard(
                                              rate, 'Attendance')),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
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

  Widget _buildSessionCard(String title, String time, String students,
      String status, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(status,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(time,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text(students,
              style:
              const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF0047AB), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0047AB))),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}