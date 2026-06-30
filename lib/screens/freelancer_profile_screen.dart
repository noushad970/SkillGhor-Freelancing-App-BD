import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'freelancer_edit_profile_screen.dart';

class FreelancerProfileScreen extends StatelessWidget {
  const FreelancerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Freelancer Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: currentUser == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Profile not found'));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'Freelancer';
                final username = data['username'] ?? '';
                final photoUrl = data['photoUrl'];
                final country = data['country'] ?? '';
                // profileCompletion unused in enhanced UI; keep in DB but not displayed here
                final isVerified = data['isVerified'] == true;
                final bio = (data['bio'] ?? '') as String;
                final skills = List<String>.from(data['skills'] ?? const []);
                final languages = List<String>.from(
                  data['languages'] ?? const [],
                );
                final education = List<Map<String, dynamic>>.from(
                  data['education'] ?? const [],
                );
                final portfolioGithub = data['portfolioGithub'] ?? '';
                final portfolioWebsite = data['portfolioWebsite'] ?? '';
                final connects = (data['totalConnects'] ?? 20) as int;
                final proposals = (data['totalProposals'] ?? 0) as int;
                final earnings = (data['totalEarnings'] ?? 0) as num;
                final rating = (data['rating'] ?? 0) as num;
                final totalReviews = (data['totalReviews'] ?? 0) as int;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Header with gradient background
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade600,
                                  Colors.green.shade400,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            child: Row(
                              children: [
                                // left empty to let avatar overlap
                                const SizedBox(width: 110),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (isVerified)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              color: Colors.white70,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Verified',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (username.isNotEmpty)
                                            Text(
                                              '@$username',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          if (username.isNotEmpty &&
                                              country.isNotEmpty)
                                            const SizedBox(width: 8),
                                          if (country.isNotEmpty)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.public,
                                                  size: 14,
                                                  color: Colors.white70,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  country,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  rating.toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '($totalReviews)',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              // message action
                                              // If you want, route to chat screen
                                            },
                                            icon: const Icon(
                                              Icons.message,
                                              size: 16,
                                            ),
                                            label: const Text('Message'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  Colors.green.shade700,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const FreelancerEditProfileScreen(),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 16,
                                            ),
                                            label: const Text('Edit'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: BorderSide(
                                                color: Colors.white24,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Avatar overlapping the header
                          Positioned(
                            left: 16,
                            top: 20,
                            child: Material(
                              elevation: 6,
                              shape: const CircleBorder(),
                              child: CircleAvatar(
                                radius: 54,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.green,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Stats - improved cards
                      Row(
                        children: [
                          _smallStatCard(
                            'Connects',
                            connects.toString(),
                            Icons.vpn_key,
                          ),
                          const SizedBox(width: 10),
                          _smallStatCard(
                            'Proposals',
                            proposals.toString(),
                            Icons.send,
                          ),
                          const SizedBox(width: 10),
                          _smallStatCard(
                            'Earnings',
                            '৳${earnings.toStringAsFixed(0)}',
                            Icons.account_balance_wallet,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // About - nicer typography
                      _sectionTitle('About'),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            bio.isNotEmpty
                                ? bio
                                : 'Add a professional bio so clients can learn more about you.',
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Skills as chips with color
                      _sectionTitle('Skills'),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: skills.isNotEmpty
                              ? Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: skills
                                      .map(
                                        (s) => Chip(
                                          label: Text(s),
                                          backgroundColor: Colors.green.shade50,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                )
                              : const Text(
                                  'Add at least 5 skills to get better job matches.',
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Languages
                      _sectionTitle('Languages'),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: languages.isNotEmpty
                              ? Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: languages
                                      .map(
                                        (l) => Chip(
                                          label: Text(l),
                                          backgroundColor: Colors.blue.shade50,
                                        ),
                                      )
                                      .toList(),
                                )
                              : const Text(
                                  'Add languages you are comfortable with.',
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Education (reinserted)
                      if (education.isNotEmpty) ...[
                        _sectionTitle('Education'),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: education
                                  .map(
                                    (e) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.school),
                                      title: Text(
                                        (e['degree'] ?? '') as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${e['school'] ?? ''} • ${e['year'] ?? ''}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Reviews - polished list
                      _sectionTitle('Reviews'),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('reviews')
                                .where('revieweeId', isEqualTo: currentUser.uid)
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, reviewsSnap) {
                              if (reviewsSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (reviewsSnap.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text('Error: ${reviewsSnap.error}'),
                                );
                              }
                              final docs = reviewsSnap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Text('No reviews yet.'),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final r =
                                      docs[index].data()
                                          as Map<String, dynamic>;
                                  final reviewerId =
                                      r['reviewerId'] as String? ?? '';
                                  final ratingVal = (r['rating'] ?? 0) as num;
                                  final comment =
                                      (r['comment'] ?? '') as String;
                                  final ts = r['createdAt'] as Timestamp?;
                                  final dateStr = ts != null
                                      ? DateTime.fromMillisecondsSinceEpoch(
                                          ts.millisecondsSinceEpoch,
                                        ).toLocal().toString()
                                      : '';

                                  return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(reviewerId)
                                        .get(),
                                    builder: (context, reviewerSnap) {
                                      final reviewerData =
                                          reviewerSnap.data?.data()
                                              as Map<String, dynamic>? ??
                                          {};
                                      final reviewerName =
                                          (reviewerData['name'] as String?) ??
                                          'Client';
                                      final reviewerPhoto =
                                          (reviewerData['photoUrl']
                                              as String?);

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: reviewerPhoto != null
                                              ? NetworkImage(reviewerPhoto)
                                              : null,
                                          child: reviewerPhoto == null
                                              ? Text(
                                                  reviewerName.isNotEmpty
                                                      ? reviewerName[0]
                                                      : 'C',
                                                )
                                              : null,
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                reviewerName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(ratingVal.toString()),
                                              ],
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (comment.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6.0,
                                                  bottom: 6.0,
                                                ),
                                                child: Text(comment),
                                              ),
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Portfolio
                      _sectionTitle('Portfolio'),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _portfolioRow('GitHub', portfolioGithub),
                              const SizedBox(height: 8),
                              _portfolioRow('Website', portfolioWebsite),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _smallStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.green.shade600, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portfolioRow(String label, String value) {
    return Row(
      children: [
        const Icon(Icons.link, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'No $label added',
            style: TextStyle(
              color: value.isNotEmpty ? Colors.blue : Colors.grey[700],
              decoration: value.isNotEmpty ? TextDecoration.underline : null,
            ),
          ),
        ),
      ],
    );
  }
}
