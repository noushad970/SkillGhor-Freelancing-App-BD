import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'freelancer_edit_profile_screen.dart';
import 'buy_connects_screen.dart';

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
                final completion = (data['profileCompletion'] ?? 0) as int;
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

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 40,
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
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isVerified
                                              ? Icons.verified
                                              : Icons.verified_user_outlined,
                                          color: isVerified
                                              ? Colors.blue
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (username.isNotEmpty)
                                          Text(
                                            '@$username',
                                            style: TextStyle(
                                              color: Colors.grey[700],
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
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(country),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: completion / 100,
                                            backgroundColor: Colors.grey[300],
                                            valueColor: AlwaysStoppedAnimation(
                                              completion >= 90
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('$completion% complete'),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
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
                                            size: 18,
                                          ),
                                          label: const Text('Edit Profile'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (!isVerified)
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'ID Verification coming soon',
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.badge_outlined,
                                              size: 18,
                                            ),
                                            label: const Text('Verify ID'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.orange,
                                              side: BorderSide(
                                                color: Colors.orange.shade300,
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
                      ),

                      const SizedBox(height: 16),

                      // Stats
                      Row(
                        children: [
                          _statCard(
                            title: 'totalConnects',
                            value: connects.toString(),
                            icon: Icons.vpn_key,
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            title: 'totalProposals',
                            value: proposals.toString(),
                            icon: Icons.send,
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            title: 'totalEarnings',
                            value: '৳${earnings.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (connects < 10)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BuyConnectsScreen(),
                                ),
                              );
                            },
                            child: const Text('Buy More Connects'),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // About
                      _sectionTitle('About'),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            bio.isNotEmpty
                                ? bio
                                : 'Add a professional bio so clients can learn more about you.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Skills
                      _sectionTitle('Skills'),
                      Card(
                        elevation: 2,
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
                                          backgroundColor:
                                              Colors.green.shade100,
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
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: languages.isNotEmpty
                              ? Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: languages
                                      .map((l) => Chip(label: Text(l)))
                                      .toList(),
                                )
                              : const Text(
                                  'Add languages you are comfortable with.',
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Education
                      _sectionTitle('Education'),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: education.isNotEmpty
                              ? Column(
                                  children: education
                                      .map(
                                        (e) => ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                          title: Text(
                                            (e['degree'] ?? '') as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${e['school'] ?? ''} • ${e['year'] ?? ''}',
                                          ),
                                          leading: const Icon(Icons.school),
                                        ),
                                      )
                                      .toList(),
                                )
                              : const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Add your education history.'),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Colors.green.shade600),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
