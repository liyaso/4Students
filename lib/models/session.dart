// This will map to the sessions collection in Firestore, which is used to for tutoring sessions

class Session {
  final String id;            // Unique session identifier
  final String courseCode;    // Course Number like CSC 4352
  final String courseName;    // Course Name
  final String tutor;         // Tutor's name/ID - person that is hosting the session
  final DateTime dateTime;    // Date and time of session
  final String room;          // Room Location
  final String status;        // Status of session (active, upcoming, completed)
  final int currentStudents;  // Number of student checked in
  final int maxStudents;      // Maximum number students in one session

  // Costructor for creating a session instance
  Session({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.tutor,
    required this.dateTime,
    required this.room,
    this.status = 'upcoming',
    this.currentStudents = 0,
    this.maxStudents = 0,
  });

  // Create session from Firestore document data
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] ?? '',
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      tutor: map['tutor'] ?? '',
      dateTime: DateTime.parse(map['dateTime'] ?? DateTime.now().toString()),
      room: map['room'] ?? '',
      status: map['status'] ?? 'upcoming',
      currentStudents: map['currentStudents'] ?? 0,
      maxStudents: map['maxStudents'] ?? 0,
    );
  }

  // Covert session to Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseCode': courseCode,
      'courseName': courseName,
      'tutor': tutor,
      'dateTime': dateTime.toIso8601String(),
      'room': room,
      'status': status,
      'currentStudents': currentStudents,
      'maxStudents': maxStudents,
    };
  }

  // Helper method to check if session is full
  bool get isFull => currentStudents >= maxStudents && maxStudents > 0;

  // Helper method to check if session is active
  bool get isActive => status == 'active';

  // Helper method to check if session is in the future
  bool get isUpcoming => status == 'upcoming' && dateTime.isAfter(DateTime.now());
}