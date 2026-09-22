import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class TutorProfile extends StatefulWidget {
  const TutorProfile({super.key});

  @override
  State<TutorProfile> createState() => _TutorProfileState();
}

class _TutorProfileState extends State<TutorProfile> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _fullName = '';
  String _email = '';
  bool _loading = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _fullName = data['fullName'] ?? '';
        _email = data['email'] ?? _auth.currentUser!.email ?? '';
        _loading = false;
      });
    } else {
      setState(() {
        _email = _auth.currentUser!.email ?? '';
        _loading = false;
      });
    }
  }

  void _editField(String field) {
    final controller = TextEditingController(
        text: field == 'Full Name' ? _fullName : _email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
              labelText: field, border: const OutlineInputBorder()),
          keyboardType: field == 'Email'
              ? TextInputType.emailAddress
              : TextInputType.name,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final uid = _auth.currentUser!.uid;
              final value = controller.text.trim();
              if (value.isEmpty) return;

              try {
                if (field == 'Full Name') {
                  await _db
                      .collection('users')
                      .doc(uid)
                      .update({'fullName': value});
                  setState(() => _fullName = value);
                } else if (field == 'Email') {
                  await _auth.currentUser!.verifyBeforeUpdateEmail(value);
                  await _db
                      .collection('users')
                      .doc(uid)
                      .update({'email': value});
                  setState(() => _email = value);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('$field updated successfully'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changePassword() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'New Password',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await _auth.currentUser!
                    .updatePassword(controller.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password updated successfully'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF0047AB))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0047AB),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        color: Color(0xFF0047AB),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0047AB),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.person,
                                size: 40, color: Color(0xFF0047AB)),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_fullName.isNotEmpty ? _fullName : 'Tutor',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(height: 5),
                              const Text('Tutor',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Personal Information',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 15),
                          _infoCard(
                              icon: Icons.person,
                              label: 'Full Name',
                              value: _fullName,
                              onEdit: () => _editField('Full Name')),
                          const SizedBox(height: 12),
                          _infoCard(
                              icon: Icons.email,
                              label: 'Email',
                              value: _email,
                              onEdit: () => _editField('Email')),
                          const SizedBox(height: 12),
                          _passwordCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sign out
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign Out'),
                    content:
                    const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () async {
                          await _auth.signOut();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const RoleSelector()),
                                (route) => false,
                          );
                        },
                        child: const Text('Sign Out',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.red, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Sign Out',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(
      {required IconData icon,
        required String label,
        required String value,
        required VoidCallback onEdit}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: const Color(0xFF0066FF),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit,
                  color: Colors.yellow, size: 20)),
        ],
      ),
    );
  }

  Widget _passwordCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: const Color(0xFF0066FF),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.white, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Password',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 3),
                Text(_isPasswordVisible ? '(hidden)' : '••••••••',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
              onPressed: _changePassword,
              icon: const Icon(Icons.edit,
                  color: Colors.yellow, size: 20)),
        ],
      ),
    );
  }
}