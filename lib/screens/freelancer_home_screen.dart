// lib/screens/freelancer_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'freelancer_edit_profile_screen.dart'; // Import the freelancer-specific edit screen
import 'find_jobs_screen.dart'; // Find Work
import 'my_proposals_screen.dart'; // Proposals
import 'messages_screen.dart'; // Messages
import 'profile_screen.dart'; // Profile
import 'active_contracts_screen.dart'; // Active Contracts
import 'earnings_reports_screen.dart'; // Earnings

class FreelancerHomeScreen extends StatelessWidget {
  const FreelancerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      // TOP HEADER (like Upwork)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'SkillGhor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindJobsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: const Icon(Icons.person, color: Colors.green),
          ),
          const SizedBox(width: 12),
        ],
      ),

      // MAIN BODY
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome + Profile Completion (Dynamic)
            _buildWelcomeCard(context),
            const SizedBox(height: 20),

            // Quick Stats
            _buildStatsRow(),
            const SizedBox(height: 20),

            // Section Buttons
            _buildSectionCard(
              context,
              "Matched Jobs",
              Icons.auto_awesome,
              Colors.purple,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FindJobsScreen()),
                );
              },
            ),
            _buildSectionCard(
              context,
              "Recent Jobs",
              Icons.work_outline,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FindJobsScreen()),
                );
              },
            ),
            _buildSectionCard(
              context,
              "Saved Jobs",
              Icons.bookmark_border,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FindJobsScreen()),
                );
              },
            ),
            _buildSectionCard(
              context,
              "My Proposals",
              Icons.send,
              Colors.teal,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProposalsScreen()),
                );
              },
            ),
            _buildSectionCard(
              context,
              "Active Contracts",
              Icons.handshake_outlined,
              Colors.green,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActiveContractsScreen(),
                  ),
                );
              },
            ),
            _buildSectionCard(
              context,
              "Earnings & Reports",
              Icons.bar_chart,
              Colors.indigo,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EarningsReportsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Best Matches Section (Real-time Jobs from Firestore)
            _buildBestMatchesSection(context),
          ],
        ),
      ),

      // BOTTOM NAVIGATION (like Upwork)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Find Work'),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Proposals'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindJobsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyProposalsScreen()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(); // Or loading indicator
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'User';
        final completion = data['profileCompletion'] ?? 0;
        final connects = data['connects'] ?? 20;
        final isVerified = data['isVerified'] == true;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: data['photoUrl'] != null
                          ? NetworkImage(data['photoUrl'])
                          : null,
                      child: data['photoUrl'] == null
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
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isVerified
                                    ? Icons.verified
                                    : Icons.verified_user_outlined,
                                color: isVerified ? Colors.blue : Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                          Text(
                            'Available Connects: $connects',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
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
                              Text(
                                '$completion% Complete',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FreelancerEditProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (!isVerified)
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ID Verification with NID/Passport coming soon!',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: const Text('Verify ID'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: BorderSide(color: Colors.orange.shade300),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final connects = data['connects'] ?? 20;
        final earnings = data['totalEarnings'] ?? 0;
        final proposals = data['proposalsSent'] ?? 0;

        return Row(
          children: [
            _buildStatCard("Connects", connects.toString(), Icons.vpn_key),
            const SizedBox(width: 12),
            _buildStatCard("Proposals", proposals.toString(), Icons.send),
            const SizedBox(width: 12),
            _buildStatCard(
              "Earnings",
              "৳${earnings.toStringAsFixed(0)}",
              Icons.account_balance_wallet,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
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

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Null Function() param4,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$title clicked')));
        },
      ),
    );
  }

  Widget _buildBestMatchesSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recommended Jobs",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .where('status', isEqualTo: 'open')
              .orderBy('postedAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      Text('Error loading jobs: ${snapshot.error}'),
                      ElevatedButton(
                        onPressed: () {}, // Retry disabled in StatelessWidget
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No jobs available yet. Check back soon!',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final jobs = snapshot.data!.docs;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jobs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final jobDoc = jobs[index];
                final job = jobDoc.data() as Map<String, dynamic>;
                final jobId = jobDoc.id;
                final applicants = List<String>.from(job['applicants'] ?? []);
                final isApplied = applicants.contains(user.uid);

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Client Info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: job['clientPhotoUrl'] != null
                                  ? NetworkImage(job['clientPhotoUrl'])
                                  : null,
                              child: job['clientPhotoUrl'] == null
                                  ? const Icon(Icons.business, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        job['clientName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        job['isClientVerified']
                                            ? Icons.verified
                                            : Icons.verified_user_outlined,
                                        color: job['isClientVerified']
                                            ? Colors.blue
                                            : Colors.grey,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _timeAgo(job['postedAt']),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Job Title
                        Text(
                          job['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          job['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),

                        // Required Skills
                        Wrap(
                          spacing: 6,
                          children: (job['requiredSkills'] as List<dynamic>)
                              .map(
                                (skill) => Chip(
                                  label: Text(skill.toString()),
                                  backgroundColor: Colors.green.shade100,
                                  labelStyle: const TextStyle(fontSize: 12),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),

                        // Budget & Deadline
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${job['budgetType']} • ৳${job['budget']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'Deadline: ${_formatDate(job['deadline'])}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Apply Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isApplied
                                  ? Colors.grey
                                  : Colors.green.shade600,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: isApplied
                                ? null
                                : () => _applyToJob(jobId, context, user.uid),
                            child: Text(
                              isApplied ? 'Applied' : 'Apply (1 Connect)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            // Navigate to full jobs list
          },
          child: const Text('View All Jobs →'),
        ),
      ],
    );
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    final date = (timestamp as Timestamp).toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDate(dynamic timestamp) {
    return (timestamp as Timestamp).toDate().toLocal().toString().split(' ')[0];
  }

  Future<void> _applyToJob(
    String jobId,
    BuildContext context,
    String uid,
  ) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);

      // Get current connects
      final userSnap = await userRef.get();
      final connects = userSnap.data()?['connects'] ?? 0;

      if (connects < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough connects! Buy more to apply.'),
          ),
        );
        return;
      }

      // Transaction to apply and deduct connect
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final jobSnap = await transaction.get(jobRef);
        final applicants = List<String>.from(
          jobSnap.data()?['applicants'] ?? [],
        );
        if (applicants.contains(uid)) {
          throw Exception('Already applied');
        }

        transaction.update(jobRef, {
          'applicants': FieldValue.arrayUnion([uid]),
        });
        transaction.update(userRef, {'connects': FieldValue.increment(-1)});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Applied successfully! (1 Connect deducted)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Apply failed: $e')));
    }
  }
}
