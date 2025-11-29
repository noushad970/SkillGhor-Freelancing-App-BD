class AppUser {
  final String uid;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String? role; // 'freelancer' or 'client' or null
  final bool verified;
  final bool onboarded;

  AppUser({
    required this.uid,
    this.name,
    this.email,
    this.photoUrl,
    this.role,
    this.verified = false,
    this.onboarded = false,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      role: data['role'] as String?,
      verified: data['verified'] as bool? ?? false,
      onboarded: data['onboarded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'verified': verified,
      'onboarded': onboarded,
    };
  }
}
