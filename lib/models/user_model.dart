// models/user_model.dart
class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? role; // 'freelancer' or 'client'
  final bool? onboarded;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.role,
    this.onboarded,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? 'User',
      photoUrl: map['photoUrl'],
      role: map['role'],
      onboarded: map['onboarded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'role': role,
      'onboarded': onboarded,
    };
  }
}
