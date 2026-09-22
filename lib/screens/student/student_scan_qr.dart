import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentScanQR extends StatefulWidget {
  final VoidCallback onBack;
  const StudentScanQR({super.key, required this.onBack});

  @override
  State<StudentScanQR> createState() => _StudentScanQRState();
}

class _StudentScanQRState extends State<StudentScanQR> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _scanned = false;

  Future<void> _onQRDetected(String qrCodeId) async {
    if (_scanned) return;
    setState(() => _scanned = true);

    final uid = _auth.currentUser!.uid;

    try {
      // 1. Look up the QR code doc
      final qrDoc = await _db.collection('qrCodes').doc(qrCodeId).get();

      if (!qrDoc.exists) {
        _showMessage('Invalid QR code. Not found.');
        setState(() => _scanned = false);
        return;
      }

      if (qrDoc['active'] == false) {
        _showMessage('This QR code is no longer active.');
        setState(() => _scanned = false);
        return;
      }

      // Check expiry
      final expiresAt = (qrDoc['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        _showMessage('This QR code has expired.');
        setState(() => _scanned = false);
        return;
      }

      final sessionId = qrDoc['sessionId'] as String;

      // 2. Check for duplicate checkin
      final existing = await _db
          .collection('checkins')
          .where('studentId', isEqualTo: uid)
          .where('sessionId', isEqualTo: sessionId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final status = existing.docs.first['status'];
        if (status == 'confirmed') {
          _showMessage('You are already checked in for this session.');
        } else if (status == 'pending') {
          _showMessage('Your check-in is pending tutor confirmation.');
        } else {
          _showMessage(
              'Your check-in was denied. Please speak to your tutor.');
        }
        setState(() => _scanned = false);
        return;
      }

      // 3. Write pending checkin
      await _db.collection('checkins').add({
        'studentId': uid,
        'sessionId': sessionId,
        'qrCodeId': qrCodeId,
        'status': 'pending',
        'scannedAt': Timestamp.now(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Check-in request sent! Waiting for tutor confirmation.'),
          backgroundColor: Color(0xFF0047AB),
          duration: Duration(seconds: 3),
        ),
      );

      // Go back to home dashboard with bottom nav intact
      widget.onBack();
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
      setState(() => _scanned = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0047AB),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Text('Scan QR Code',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcode = capture.barcodes.first;
              final value = barcode.rawValue;
              if (value != null) {
                _onQRDetected(value);
              }
            },
          ),
          // Viewfinder overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Hint text
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.black54,
              child: const Text(
                'Point your camera at the tutor\'s QR code to check in',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}