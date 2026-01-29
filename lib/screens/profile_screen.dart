import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'client_edit_profile_screen.dart';
import 'freelancer_edit_profile_screen.dart';
import 'saved_jobs_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please sign in to view profile.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<DocumentSnapshot>(
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
          final name = data['name'] ?? 'User';
          final email = data['email'] ?? currentUser.email ?? '';
          final username = data['username'] ?? '';
          final photoUrl = data['photoUrl'];
          final country = data['country'] ?? '';
          final role = (data['role'] ?? '').toString();
          final isFreelancer = role.toLowerCase() == 'freelancer';
          final completion = (data['profileCompletion'] ?? 0) as int;
          final isVerified = data['isVerified'] == true;
          final bio = (data['bio'] ?? '') as String;
          final skills = List<String>.from(data['skills'] ?? const []);
          final languages = List<String>.from(data['languages'] ?? const []);
          final education = List<Map<String, dynamic>>.from(
            data['education'] ?? const [],
          );
          final portfolioGithub = data['portfolioGithub'] ?? '';
          final portfolioWebsite = data['portfolioWebsite'] ?? '';
          final connects = (data['totalConnects'] ?? 0) as int;
          final proposals = (data['totalProposals'] ?? 0) as int;
          final earnings = (data['totalEarnings'] ?? 0) as num;
          final totalSpent = (data['totalSpent'] ?? 0) as num;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(
                  name: name,
                  email: email,
                  username: username,
                  country: country,
                  role: role,
                  photoUrl: photoUrl,
                  completion: completion,
                  isVerified: isVerified,
                  isFreelancer: isFreelancer,
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isFreelancer
                            ? const FreelancerEditProfileScreen()
                            : const ClientEditProfileScreen(),
                      ),
                    );
                  },
                  onSavedJobs: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedJobsScreen(),
                      ),
                    );
                  },
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
                      title: isFreelancer ? 'totalEarnings' : 'totalSpent',
                      value:
                          '৳${(isFreelancer ? earnings : totalSpent).toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _sectionTitle('About'),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      bio.isNotEmpty
                          ? bio
                          : 'Add a professional bio so others can learn more about you.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                                    backgroundColor: Colors.green.shade100,
                                  ),
                                )
                                .toList(),
                          )
                        : const Text(
                            'Add at least 5 skills to get better matches.',
                          ),
                  ),
                ),

                const SizedBox(height: 16),

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
                            'Add the languages you are comfortable with.',
                          ),
                  ),
                ),

                const SizedBox(height: 16),

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
                          )
                        : const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Add your education history.'),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

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

  Widget _headerCard({
    required String name,
    required String email,
    required String username,
    required String country,
    required String role,
    required dynamic photoUrl,
    required int completion,
    required bool isVerified,
    required bool isFreelancer,
    required VoidCallback onEdit,
    required VoidCallback onSavedJobs,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: 40, color: Colors.green)
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
                            color: isVerified ? Colors.blue : Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (email.isNotEmpty)
                        Text(email, style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          if (username.isNotEmpty && country.isNotEmpty)
                            const SizedBox(width: 8),
                          if (country.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.public, size: 16),
                                const SizedBox(width: 4),
                                Text(country),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role.isNotEmpty ? role.toUpperCase() : 'ROLE',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
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
                                Text('$completion%'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (isFreelancer)
                  OutlinedButton.icon(
                    onPressed: onSavedJobs,
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text('Saved Jobs'),
                  ),
              ],
            ),
          ],
        ),
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
    final canTap = value.isNotEmpty;
    return Row(
      children: [
        const Icon(Icons.link, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: canTap ? () => _launch(value) : null,
            child: Text(
              canTap ? value : 'No $label added',
              style: TextStyle(
                color: canTap ? Colors.blue : Colors.grey[700],
                decoration: canTap ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launch(String urlStr) async {
    String url = urlStr.trim();
    
    // Add scheme if not present
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Handle error silently
    }
  }
}
