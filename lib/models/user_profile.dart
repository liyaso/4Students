// This will map the users collection in Firestore

class UserProfile {
  final String uid;       // Firebase Auth user ID (unique identifier)
  final String fullName;  // User's full name
  final String email;     // User's email address
  final String role;      // User's role (student or tutor)
  final String? password; // Hashed, stored securely

  // Constructor for creating a UserProfile instance
  UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.password,
  });

  // Create UserProfile from Firestore document data
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      password: map['password'],
    );
  }

  // Convert UserProfile to Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role,
    };
  }
}
