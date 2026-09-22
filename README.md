# 4Students

This project is a mobile application that allows the check-in process to be faster by letting students use dynamic QR Codes. When QR Codes are used, it will allow students and tutors to streamline the check-in process, making it more efficient and convenient for both students and tutors.

Once a tutor creates a tutoring session, a QR Code will be available for display for students to scan at the time of the session. When students scan the QR Code, the tutor will be able to see the attendance data for that session and any other session from the past, including who has signed up for a session.

When a student wants to sign up for a tutoring session, they can search for a session and sign up. The student will then enter the session and scan the QR Code for attendance. Both students and tutors will receive push notifications about any upcoming sessions they have and check-in times.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Setup
This project requires Firebase configuration files that are not included in
this repo. Run `flutterfire configure` after cloning to generate:
- lib/firebase_options.dart
- android/app/google-services.json
