import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get upcoming sessions for a student
  Stream<List<Session>> getUpcomingSessions() {
    return _firestore
        .collection('sessions')
        .where('dateTime', isGreaterThan: DateTime.now().toIso8601String())
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Session.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get sessions for a specific tutor
  Stream<List<Session>> getTutorSessions(String tutorId) {
    return _firestore
        .collection('sessions')
        .where('tutorId', isEqualTo: tutorId)
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Session.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get today's sessions for a tutor
  Stream<List<Session>> getTodaySessions(String tutorId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('sessions')
        .where('tutorId', isEqualTo: tutorId)
        .where('dateTime',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
            isLessThanOrEqualTo: endOfDay.toIso8601String())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Session.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Create a new session (for tutors)
  Future<String?> createSession(Session session) async {
    try {
      DocumentReference doc =
          await _firestore.collection('sessions').add(session.toMap());
      return doc.id;
    } catch (e) {
      print('Error creating session: $e');
      return null;
    }
  }

  // Delete a session
  Future<bool> deleteSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).delete();
      return true;
    } catch (e) {
      print('Error deleting session: $e');
      return false;
    }
  }

  // Update session
  Future<bool> updateSession(String sessionId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update(updates);
      return true;
    } catch (e) {
      print('Error updating session: $e');
      return false;
    }
  }
}
