import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../tutor/tutor_session_enrollments.dart';

class QrTestScreen extends StatefulWidget {
  const QrTestScreen({super.key});

  @override
  State<QrTestScreen> createState() => _QrTestScreenState();
}

class _QrTestScreenState extends State<QrTestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // All of the tutor's upcoming/active sessions
  List<Map<String, dynamic>> _sessions = [];
  // The currently selected session
  String? _selectedSessionId;
  String? _selectedSessionLabel;
  // The QR code doc ID for the selected session
  String? _qrCodeId;
  bool _loadingSessions = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load all upcoming/active sessions for this tutor
  Future<void> _loadSessions() async {
    final uid = _auth.currentUser!.uid;

    final snap = await _db
        .collection('sessions')
        .where('tutorId', isEqualTo: uid)
        .get();

    final docs = snap.docs
        .where((d) {
      final status = (d.data())['status'];
      return status == 'upcoming' || status == 'active';
    })
        .toList()
      ..sort((a, b) {
        final aDate = (a.data())['dateTime'] ?? '';
        final bDate = (b.data())['dateTime'] ?? '';
        return aDate.compareTo(bDate);
      });

    if (!mounted) return;

    if (docs.isEmpty) {
      setState(() => _loadingSessions = false);
      return;
    }

    final sessionList = docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'courseCode': data['courseCode'] ?? '',
        'courseName': data['courseName'] ?? '',
        'dateTime': data['dateTime'] ?? '',
        'room': data['room'] ?? '',
        'status': data['status'] ?? 'upcoming',
      };
    }).toList();

    setState(() {
      _sessions = sessionList;
      _loadingSessions = false;
    });

    // Auto-select the first active session, or just the first one
    final activeSession = sessionList.firstWhere(
          (s) => s['status'] == 'active',
      orElse: () => sessionList.first,
    );
    await _selectSession(activeSession['id'] as String,
        _buildSessionLabel(activeSession));

    // Also listen for new sessions being added in real time
    _db
        .collection('sessions')
        .where('tutorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final updated = snap.docs
          .where((d) {
        final status = (d.data())['status'];
        return status == 'upcoming' || status == 'active';
      })
          .toList()
        ..sort((a, b) {
          final aDate = (a.data())['dateTime'] ?? '';
          final bDate = (b.data())['dateTime'] ?? '';
          return aDate.compareTo(bDate);
        });

      setState(() {
        _sessions = updated.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'courseCode': data['courseCode'] ?? '',
            'courseName': data['courseName'] ?? '',
            'dateTime': data['dateTime'] ?? '',
            'room': data['room'] ?? '',
            'status': data['status'] ?? 'upcoming',
          };
        }).toList();
      });
    });
  }

  String _buildSessionLabel(Map<String, dynamic> session) {
    final code = session['courseCode'] ?? '';
    final dt = _formatDateShort(session['dateTime'] ?? '');
    return '$code  •  $dt';
  }

  String _formatDateShort(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return iso;
    }
  }

  // Switch to a different session and load/create its QR code
  Future<void> _selectSession(String sessionId, String label) async {
    setState(() {
      _selectedSessionId = sessionId;
      _selectedSessionLabel = label;
      _qrCodeId = null;
    });

    // Find existing active QR for this session
    final qrSnap = await _db
        .collection('qrCodes')
        .where('sessionId', isEqualTo: sessionId)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    String qrId;
    if (qrSnap.docs.isNotEmpty) {
      qrId = qrSnap.docs.first.id;
    } else {
      // Create one if it doesn't exist
      final uid = _auth.currentUser!.uid;
      final ref = await _db.collection('qrCodes').add({
        'sessionId': sessionId,
        'tutorId': uid,
        'active': true,
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15)),
        ),
      });
      qrId = ref.id;
    }

    if (!mounted) return;
    setState(() => _qrCodeId = qrId);
    _listenToPendingCount(sessionId);
  }

  void _listenToPendingCount(String sessionId) {
    _db
        .collection('checkins')
        .where('sessionId', isEqualTo: sessionId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _pendingCount = s.docs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0047AB),
        foregroundColor: Colors.white,
        title: const Text('QR Code Generator', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: [
            const Tab(text: 'QR Code'),
            const Tab(text: 'Sessions'),
            Tab(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('Confirmation'),
                  ),
                  if (_pendingCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 18, minHeight: 18),
                        child: Text(
                          '$_pendingCount',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loadingSessions
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF0047AB)))
          : TabBarView(
        controller: _tabController,
        children: [
          _QrCodeTab(
            sessions: _sessions,
            selectedSessionId: _selectedSessionId,
            selectedSessionLabel: _selectedSessionLabel,
            qrCodeId: _qrCodeId,
            onSessionChanged: (id, label) => _selectSession(id, label),
          ),
          _SessionsTab(tutorId: _auth.currentUser!.uid),
          _ConfirmationTab(
            sessionId: _selectedSessionId,
            sessions: _sessions,
          ),
        ],
      ),
    );
  }
}


class _QrCodeTab extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final String? selectedSessionId;
  final String? selectedSessionLabel;
  final String? qrCodeId;
  final void Function(String id, String label) onSessionChanged;

  const _QrCodeTab({
    required this.sessions,
    required this.selectedSessionId,
    required this.selectedSessionLabel,
    required this.qrCodeId,
    required this.onSessionChanged,
  });

  String _buildLabel(Map<String, dynamic> s) {
    final code = s['courseCode'] ?? '';
    final iso = s['dateTime'] ?? '';
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '$code  •  ${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No active sessions found.\nCreate a session in the Schedule tab first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // ── Session switcher dropdown ──
            if (sessions.length > 1)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0047AB).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF0047AB).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz,
                        color: Color(0xFF0047AB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedSessionId,
                          items: sessions.map((s) {
                            final id = s['id'] as String;
                            final label = _buildLabel(s);
                            return DropdownMenuItem(
                              value: id,
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF0047AB),
                                      fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id == null) return;
                            final s = sessions
                                .firstWhere((s) => s['id'] == id);
                            onSessionChanged(id, _buildLabel(s));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ── QR code ──
            const Text(
              'Session Check-In QR Code',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0047AB),
              ),
            ),
            const SizedBox(height: 20),

            if (qrCodeId == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                    color: Color(0xFF0047AB)),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrCodeId!,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0047AB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  qrCodeId!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Students can scan this code to check in',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}


class _SessionsTab extends StatelessWidget {
  final String tutorId;
  const _SessionsTab({required this.tutorId});

  Color _color(String status) {
    switch (status) {
      case 'completed': return Colors.green.shade600;
      case 'rescheduled': return Colors.orange.shade700;
      case 'active': return Colors.blue.shade700;
      default: return Colors.blue.shade600;
    }
  }

  Color _bg(String status) {
    switch (status) {
      case 'completed': return Colors.green.shade50;
      case 'rescheduled': return Colors.orange.shade50;
      default: return Colors.blue.shade50;
    }
  }

  IconData _icon(String status) {
    switch (status) {
      case 'completed': return Icons.check_circle_outline;
      case 'rescheduled': return Icons.update;
      case 'active': return Icons.play_circle_outline;
      default: return Icons.event_available;
    }
  }

  String _label(String status) {
    switch (status) {
      case 'completed': return 'Completed';
      case 'rescheduled': return 'Rescheduled';
      case 'active': return 'Active';
      default: return 'Upcoming';
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return raw; }
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('tutorId', isEqualTo: tutorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0047AB)));
        }

        final docs = (snapshot.data?.docs ?? [])
          ..sort((a, b) {
            final aDate =
                (a.data() as Map<String, dynamic>)['dateTime'] ?? '';
            final bDate =
                (b.data() as Map<String, dynamic>)['dateTime'] ?? '';
            return bDate.compareTo(aDate); // newest first
          });

        if (docs.isEmpty) {
          return const Center(
            child: Text('No sessions found.',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'upcoming';
            final color = _color(status);
            final bg = _bg(status);

            return _SessionCard(
              sessionId: docs[index].id,
              data: data,
              color: color,
              bg: bg,
              statusLabel: _label(status),
              statusIcon: _icon(status),
              formattedDate: _formatDate(data['dateTime'] ?? ''),
              formattedTime: _formatTime(data['dateTime'] ?? ''),
            );
          },
        );
      },
    );
  }
}


class _SessionCard extends StatelessWidget {
  final String sessionId;
  final Map<String, dynamic> data;
  final Color color;
  final Color bg;
  final String statusLabel;
  final IconData statusIcon;
  final String formattedDate;
  final String formattedTime;

  const _SessionCard({
    required this.sessionId,
    required this.data,
    required this.color,
    required this.bg,
    required this.statusLabel,
    required this.statusIcon,
    required this.formattedDate,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                  BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(statusIcon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                // Session info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['courseCode'] ?? ''} – ${data['courseName'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0047AB)),
                      ),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(formattedDate,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(formattedTime,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(data['room'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Enrollment count + Details button
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('enrollments')
                  .where('sessionId', isEqualTo: sessionId)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                const max = 15;
                final isFull = count >= max;

                return Row(
                  children: [
                    // Enrolled count chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isFull
                            ? Colors.red.shade50
                            : const Color(0xFF0047AB).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isFull
                              ? Colors.red.shade200
                              : const Color(0xFF0047AB).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people,
                              size: 13,
                              color: isFull
                                  ? Colors.red.shade500
                                  : const Color(0xFF0047AB)),
                          const SizedBox(width: 5),
                          Text(
                            '$count / $max reserved${isFull ? ' • Full' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isFull
                                  ? Colors.red.shade500
                                  : const Color(0xFF0047AB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Details button
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TutorSessionEnrollments(
                            sessionId: sessionId,
                            courseCode: data['courseCode'] ?? '',
                            courseName: data['courseName'] ?? '',
                            dateTime:
                            '$formattedDate  •  $formattedTime',
                            room: data['room'] ?? '',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.people_alt_outlined,
                          size: 16, color: Color(0xFF0047AB)),
                      label: const Text(
                        'Details',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0047AB)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        backgroundColor:
                        const Color(0xFF0047AB).withOpacity(0.07),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _ConfirmationTab extends StatefulWidget {
  final String? sessionId;
  final List<Map<String, dynamic>> sessions;

  const _ConfirmationTab({
    required this.sessionId,
    required this.sessions,
  });

  @override
  State<_ConfirmationTab> createState() => _ConfirmationTabState();
}

class _ConfirmationTabState extends State<_ConfirmationTab> {
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _selectedSessionId = widget.sessionId;
  }

  @override
  void didUpdateWidget(_ConfirmationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent's selected session changes and we haven't picked one yet, sync
    if (oldWidget.sessionId != widget.sessionId &&
        _selectedSessionId == null) {
      _selectedSessionId = widget.sessionId;
    }
  }

  Future<void> _resolve(String docId, bool confirm) async {
    await FirebaseFirestore.instance
        .collection('checkins')
        .doc(docId)
        .update({
      'status': confirm ? 'confirmed' : 'denied',
      'resolvedAt': Timestamp.now(),
    });
  }

  String _buildLabel(Map<String, dynamic> s) {
    final code = s['courseCode'] ?? '';
    final iso = s['dateTime'] ?? '';
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '$code  •  ${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No active sessions.\nCreate and start a session to see check-in requests.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ),
      );
    }

    // Make sure selectedSessionId is valid
    final validId = widget.sessions.any((s) => s['id'] == _selectedSessionId)
        ? _selectedSessionId
        : widget.sessions.first['id'] as String;

    return Column(
      children: [
        // ── Session dropdown ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0047AB).withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF0047AB).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz,
                  color: Color(0xFF0047AB), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: validId,
                    items: widget.sessions.map((s) {
                      final id = s['id'] as String;
                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          _buildLabel(s),
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0047AB),
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setState(() => _selectedSessionId = id);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Checkin list for selected session ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('checkins')
                .where('sessionId', isEqualTo: validId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0047AB)));
              }

              final docs = (snapshot.data?.docs ?? [])
                ..sort((a, b) {
                  final aT = (a.data() as Map)['scannedAt'];
                  final bT = (b.data() as Map)['scannedAt'];
                  if (aT == null || bT == null) return 0;
                  return (aT as Timestamp).compareTo(bT as Timestamp);
                });

              final pending = docs
                  .where((d) => (d['status'] as String) == 'pending')
                  .toList();
              final resolved = docs
                  .where((d) => (d['status'] as String) != 'pending')
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (pending.isNotEmpty) ...[
                    Row(children: [
                      Text('Awaiting Confirmation',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${pending.length}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    ...pending.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _PendingCard(
                        studentId: data['studentId'] ?? '',
                        scannedAt: data['scannedAt'],
                        onConfirm: () => _resolve(doc.id, true),
                        onDeny: () => _resolve(doc.id, false),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  if (resolved.isNotEmpty) ...[
                    const Text('Resolved',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey)),
                    const SizedBox(height: 10),
                    ...resolved.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _ResolvedCard(
                        studentId: data['studentId'] ?? '',
                        scannedAt: data['scannedAt'],
                        status: data['status'] ?? 'denied',
                      );
                    }),
                  ],

                  if (docs.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Text('No check-in requests yet.',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 15)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}


class _PendingCard extends StatelessWidget {
  final String studentId;
  final dynamic scannedAt;
  final VoidCallback onConfirm;
  final VoidCallback onDeny;

  const _PendingCard({
    required this.studentId,
    required this.scannedAt,
    required this.onConfirm,
    required this.onDeny,
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
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, snap) {
        final name = snap.hasData
            ? ((snap.data!.data() as Map<String, dynamic>?)?['fullName'] ??
            'Unknown')
            : '...';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Text('Scanned at ${_formatTime(scannedAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDeny,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Icon(Icons.close,
                        color: Colors.red.shade500, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Icon(Icons.check,
                        color: Colors.green.shade600, size: 20),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _ResolvedCard extends StatelessWidget {
  final String studentId;
  final dynamic scannedAt;
  final String status;

  const _ResolvedCard({
    required this.studentId,
    required this.scannedAt,
    required this.status,
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
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = status == 'confirmed';
    final color = confirmed ? Colors.green.shade600 : Colors.red.shade400;
    final bg = confirmed ? Colors.green.shade50 : Colors.red.shade50;
    final label = confirmed ? 'Confirmed' : 'Denied';
    final icon = confirmed ? Icons.check_circle : Icons.cancel;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, snap) {
        final name = snap.hasData
            ? ((snap.data!.data() as Map<String, dynamic>?)?['fullName'] ??
            'Unknown')
            : '...';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: bg,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
            subtitle: Text('Scanned at ${_formatTime(scannedAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}