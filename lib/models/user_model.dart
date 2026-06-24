class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? username;
  final DateTime? dateOfBirth;
  final String? country;
  final String? location;
  final List<String>? skills;
  final List<String>? languages;
  final String? companyName;
  final String? bio;
  final String? portfolioGithub;
  final String? portfolioWebsite;
  final List<String>? portfolioUrls;
  final String? role;
  final bool onboarded;
  final double totalEarnings;
  final int totalConnects;
  final int totalProposals;
  final double totalSpent;
  final double walletBalance;
  final double rating;
  final int totalReviews;
  final int unreadNotifications;
  final int profileCompletion;
  final List<String>? savedJobs;
  final bool isVerified;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.username,
    this.dateOfBirth,
    this.country,
    this.location,
    this.skills,
    this.languages,
    this.companyName,
    this.bio,
    this.portfolioGithub,
    this.portfolioWebsite,
    this.portfolioUrls,
    this.role,
    required this.onboarded,
    this.totalEarnings = 0,
    this.totalConnects = 50,
    this.totalProposals = 0,
    this.totalSpent = 0,
    this.walletBalance = 0,
    this.rating = 0,
    this.totalReviews = 0,
    this.unreadNotifications = 0,
    this.profileCompletion = 0,
    this.savedJobs,
    this.isVerified = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      username: map['username'],
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.tryParse(map['dateOfBirth'].toString())
          : null,
      country: map['country'],
      location: map['location'],
      skills: map['skills'] is List ? List<String>.from(map['skills']) : null,
      languages: map['languages'] is List
          ? List<String>.from(map['languages'])
          : null,
      companyName: map['companyName'],
      bio: map['bio'],
      portfolioGithub: map['portfolioGithub'],
      portfolioWebsite: map['portfolioWebsite'],
      portfolioUrls: map['portfolioUrls'] is List
          ? List<String>.from(map['portfolioUrls'])
          : null,
      role: map['role'],
      onboarded: map['onboarded'] ?? false,
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      totalConnects: (map['totalConnects'] ?? 50) is int
          ? map['totalConnects']
          : int.tryParse(map['totalConnects'].toString()) ?? 50,
      totalProposals: (map['totalProposals'] ?? 0) is int
          ? map['totalProposals']
          : int.tryParse(map['totalProposals'].toString()) ?? 0,
      totalSpent: (map['totalSpent'] ?? 0).toDouble(),
      walletBalance: (map['walletBalance'] ?? 0).toDouble(),
      rating: (map['rating'] ?? 0).toDouble(),
      totalReviews: (map['totalReviews'] ?? 0) is int
          ? map['totalReviews']
          : int.tryParse(map['totalReviews'].toString()) ?? 0,
      unreadNotifications: (map['unreadNotifications'] ?? 0) is int
          ? map['unreadNotifications']
          : int.tryParse(map['unreadNotifications'].toString()) ?? 0,
      profileCompletion: (map['profileCompletion'] ?? 0) is int
          ? map['profileCompletion']
          : int.tryParse(map['profileCompletion'].toString()) ?? 0,
      savedJobs: map['savedJobs'] is List
          ? List<String>.from(map['savedJobs'])
          : null,
      isVerified: map['isVerified'] == true,
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
    'location': location,
    'skills': skills,
    'languages': languages,
    'companyName': companyName,
    'bio': bio,
    'portfolioGithub': portfolioGithub,
    'portfolioWebsite': portfolioWebsite,
    'portfolioUrls': portfolioUrls,
    'role': role,
    'onboarded': onboarded,
    'totalEarnings': totalEarnings,
    'totalConnects': totalConnects,
    'totalProposals': totalProposals,
    'totalSpent': totalSpent,
    'walletBalance': walletBalance,
    'rating': rating,
    'totalReviews': totalReviews,
    'unreadNotifications': unreadNotifications,
    'profileCompletion': profileCompletion,
    'savedJobs': savedJobs,
    'isVerified': isVerified,
  };
}
