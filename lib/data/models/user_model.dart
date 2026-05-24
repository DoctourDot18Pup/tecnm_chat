import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String institutionalEmail;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final String career;
  final int? semester;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.institutionalEmail,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.career,
    this.semester,
    required this.createdAt,
  });

  bool get isProfessor => role == 'professor';
  bool get isStudent => role == 'student';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      phoneNumber: json['phoneNumber'] as String,
      institutionalEmail: json['institutionalEmail'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String,
      career: json['career'] as String,
      semester: json['semester'] as int?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'institutionalEmail': institutionalEmail,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'role': role,
      'career': career,
      'semester': semester,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? institutionalEmail,
    String? role,
    String? career,
    int? semester,
  }) {
    return UserModel(
      uid: uid,
      phoneNumber: phoneNumber,
      institutionalEmail: institutionalEmail ?? this.institutionalEmail,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      career: career ?? this.career,
      semester: semester ?? this.semester,
      createdAt: createdAt,
    );
  }
}
