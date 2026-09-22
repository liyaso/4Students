import 'package:flutter/material.dart';

// App Colors - Georgia State University Brand Colors
class AppColors {
  static const Color primaryBlue = Color(0xFF0047AB); // Royal Blue
  static const Color secondaryBlue = Color(0xFF0066FF);
  static const Color accentRed = Color(0xFFCC0000);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  
  // Status Colors
  static const Color activeGreen = Colors.green;
  static const Color upcomingOrange = Colors.orange;
  static const Color warningYellow = Colors.yellow;
  static const Color errorRed = Colors.red;
}

// Text Styles
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.black,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryBlue,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.black,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.black,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.grey,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
}

// App Dimensions
class AppDimensions {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 15.0;
  static const double paddingLarge = 20.0;
  
  static const double borderRadiusSmall = 5.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 10.0;
  static const double borderRadiusXLarge = 20.0;
  
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeXLarge = 40.0;
}

// App Strings
class AppStrings {
  // App Name
  static const String appName = 'FourStudents';
  
  // Student Strings
  static const String welcomeStudent = 'Welcome Back, Student!';
  static const String quickCheckin = 'Quick Check-In';
  static const String scanQRCode = 'Scan QR Code';
  static const String upcomingSessions = 'Upcoming Sessions';
  static const String yourAttendance = 'Your Attendance';
  static const String sessionsAttended = 'sessions attended';
  static const String thisWeek = 'This Week';
  static const String attended = 'Attended';
  
  // Tutor Strings
  static const String welcomeTutor = 'Welcome Back, Tutor!';
  static const String sessionManagement = 'Session Management';
  static const String newSession = 'New Session';
  static const String todaysSessions = 'Today\'s Sessions';
  static const String thisWeekStats = 'This Week';
  static const String sessions = 'Sessions';
  static const String checkIns = 'Check-Ins';
  static const String attendance = 'Attendance';
  
  // Common Strings
  static const String homeDashboard = 'Home Dashboard';
  static const String scheduleSession = 'Schedule Session';
  static const String profile = 'Profile';
  static const String history = 'History';
  static const String signOut = 'Sign Out';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String save = 'Save';
  static const String edit = 'Edit';
  
  // Form Labels
  static const String fullName = 'Full Name';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String personalInfo = 'Personal Information';
  
  // Session Details
  static const String tutor = 'Tutor';
  static const String room = 'Room';
  static const String sessionId = 'Session ID';
  static const String active = 'Active';
  static const String upcoming = 'Upcoming';
  static const String completed = 'Completed';
  
  // Messages
  static const String signOutConfirm = 'Are you sure you want to sign out?';
  static const String deleteSessionConfirm = 'Are you sure you want to delete this session?';
  static const String sessionCreated = 'Session created successfully!';
  static const String sessionDeleted = 'Session deleted';
  static const String fillAllFields = 'Please fill all fields';
  static const String qrCodeGenerated = 'QR Code generated';
}

// Firebase Collection Names
class FirebaseCollections {
  static const String users = 'users';
  static const String sessions = 'sessions';
  static const String attendance = 'attendance';
}

// User Roles
enum UserRole {
  student,
  tutor,
  admin,
}

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.tutor:
        return 'tutor';
      case UserRole.admin:
        return 'admin';
    }
  }
}

// Session Status
enum SessionStatus {
  active,
  upcoming,
  completed,
}

extension SessionStatusExtension on SessionStatus {
  String get value {
    switch (this) {
      case SessionStatus.active:
        return 'active';
      case SessionStatus.upcoming:
        return 'upcoming';
      case SessionStatus.completed:
        return 'completed';
    }
  }
  
  Color get color {
    switch (this) {
      case SessionStatus.active:
        return AppColors.activeGreen;
      case SessionStatus.upcoming:
        return AppColors.upcomingOrange;
      case SessionStatus.completed:
        return AppColors.grey;
    }
  }
}
