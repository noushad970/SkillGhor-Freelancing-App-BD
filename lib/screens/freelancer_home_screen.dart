// lib/screens/freelancer_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'freelancer_edit_profile_screen.dart'; // Edit profile
import 'find_jobs_screen.dart'; // Find Work
import 'my_proposals_screen.dart'; // Proposals
import 'messages_screen.dart'; // Messages
import 'profile_screen.dart'; // Profile
import 'active_contracts_screen.dart'; // Active Contracts
import 'earnings_reports_screen.dart'; // Earnings
import 'buy_connects_screen.dart'; // Buy Connects
import 'apply_job_screen.dart';
import 'saved_jobs_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';

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

          // Notification icon with badge
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: StreamBuilder<List<AppNotification>>(
              stream: NotificationService().getUnreadNotifications(),
              builder: (context, snap) {
                final unread = snap.data?.length ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
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
            _buildStatsRow(context),
            const SizedBox(height: 20),

            // Quick Actions (side-by-side, wrap to multiple lines)
            _buildQuickActions(context),

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

  Future<void> _toggleSaveJob(
    BuildContext context, {
    required String jobId,
    required bool isSaved,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'savedJobs': isSaved
            ? FieldValue.arrayRemove([jobId])
            : FieldValue.arrayUnion([jobId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSaved ? 'Removed from Saved' : 'Saved to your list'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving job: $e')));
    }
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

                    // Right side buttons: will wrap on small screens
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!isVerified)
                          SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
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
                              icon: const Icon(Icons.badge_outlined, size: 16),
                              label: const Text('Verify ID'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: BorderSide(color: Colors.orange.shade300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(0, 36),
                              ),
                            ),
                          ),

                        SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BuyConnectsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.shopping_cart, size: 16),
                            label: const Text('Buy Connects'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: BorderSide(color: Colors.green.shade300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStatsRow(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final connects = data['totalConnects'] ?? 20;
        final earnings = data['totalEarnings'] ?? 0;
        final proposals = data['totalProposals'] ?? 0;

        return Column(
          children: [
            Row(
              children: [
                _buildStatCard(
                  "totalConnects",
                  connects.toString(),
                  Icons.vpn_key,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  "totalProposals",
                  proposals.toString(),
                  Icons.send,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  "totalEarnings",
                  "৳${earnings.toStringAsFixed(0)}",
                  Icons.account_balance_wallet,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (connects < 10) // Show buy button if low on connects
              ElevatedButton(
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

  // New: quick actions as side-by-side buttons that wrap into multiple rows
  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionButton(
          label: 'Matched Jobs',
          icon: Icons.auto_awesome,
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindJobsScreen()),
            );
          },
        ),
        _actionButton(
          label: 'Recent Jobs',
          icon: Icons.work_outline,
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindJobsScreen()),
            );
          },
        ),
        _actionButton(
          label: 'Saved Jobs',
          icon: Icons.bookmark_border,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedJobsScreen()),
            );
          },
        ),
        _actionButton(
          label: 'My Proposals',
          icon: Icons.send,
          color: Colors.teal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyProposalsScreen()),
            );
          },
        ),
        _actionButton(
          label: 'Active Contracts',
          icon: Icons.handshake_outlined,
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActiveContractsScreen()),
            );
          },
        ),
        _actionButton(
          label: 'Earnings & Reports',
          icon: Icons.bar_chart,
          color: Colors.indigo,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EarningsReportsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildBestMatchesSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  Text('Error loading saved jobs: ${userSnapshot.error}'),
                ],
              ),
            ),
          );
        }

        final userData =
            userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final savedJobs = List<String>.from(userData['savedJobs'] ?? []);

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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Retrying...')),
                              );
                            }, // StreamBuilder auto-updates; no manual refresh needed
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
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final jobDoc = jobs[index];
                    final job = jobDoc.data() as Map<String, dynamic>;
                    final jobId = jobDoc.id;
                    final applicants = List<String>.from(
                      job['applicants'] ?? [],
                    );
                    final isApplied = applicants.contains(user.uid);
                    final isSaved = savedJobs.contains(jobId);

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                IconButton(
                                  icon: Icon(
                                    isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    color: isSaved
                                        ? Colors.orange
                                        : Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    _toggleSaveJob(
                                      context,
                                      jobId: jobId,
                                      isSaved: isSaved,
                                    );
                                  },
                                  tooltip: isSaved
                                      ? 'Remove from saved'
                                      : 'Save job',
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

                            // Actions: Save + Apply
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: Icon(
                                      isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                    ),
                                    label: Text(isSaved ? 'Saved' : 'Save Job'),
                                    onPressed: () {
                                      _toggleSaveJob(
                                        context,
                                        jobId: jobId,
                                        isSaved: isSaved,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isApplied
                                          ? Colors.grey
                                          : Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: isApplied
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ApplyJobScreen(
                                                  jobId: jobId,
                                                ),
                                              ),
                                            );
                                          },
                                    child: Text(
                                      isApplied
                                          ? 'Applied'
                                          : 'Apply (1+ Connects)',
                                    ),
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
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FindJobsScreen()),
                );
              },
              child: const Text('View All Jobs →'),
            ),
          ],
        );
      },
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
}
