class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? username;
  final DateTime? dateOfBirth;
  final String? country;
  final List<String>? skills;
  final String? companyName;
  final String? bio;
  final String? role;
  final bool onboarded;
  final int totalEarnings;
  final int totalConnects;
  final int totalProposals;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.username,
    this.dateOfBirth,
    this.country,
    this.skills,
    this.companyName,
    this.bio,
    this.role,
    required this.onboarded,
    this.totalEarnings = 0,
    this.totalConnects = 50, // Initial 50 on signup
    this.totalProposals = 0,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      username: map['username'],
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.tryParse(map['dateOfBirth'])
          : null,
      country: map['country'],
      skills: map['skills'] is List ? List<String>.from(map['skills']) : null,
      companyName: map['companyName'],
      bio: map['bio'],
      role: map['role'],
      onboarded: map['onboarded'] ?? false,
      totalEarnings: map['totalEarnings'] ?? 0,
      totalConnects: map['totalConnects'] ?? 50,
      totalProposals: map['totalProposals'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'photoUrl': photoUrl,
    'username': username,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'country': country,
    'skills': skills,
    'companyName': companyName,
    'bio': bio,
    'role': role,
    'onboarded': onboarded,
    'totalEarnings': totalEarnings,
    'totalConnects': totalConnects,
    'totalProposals': totalProposals,
  };
}
