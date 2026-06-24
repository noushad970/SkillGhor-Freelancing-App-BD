// lib/screens/client_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_edit_profile_screen.dart';
import 'post_job_screen.dart';
import 'applicant_list_screen.dart';
import 'messages_screen.dart';
import 'my_jobs_screen.dart';
import 'hired_freelancers_screen.dart';
import 'client_profile_screen.dart';
import 'invoices_payments_screen.dart';
import '../services/payment_service.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    final screens = [
      _buildHomeScreen(context, user),
      const MyJobsScreen(),
      const HiredFreelancersScreen(),
      const MessagesScreen(),
      const ClientProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'SkillGhor',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where('clientId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                for (final job in snapshot.data!.docs) {
                  unreadCount += (job['proposalsCount'] ?? 0) as int;
                }
              }
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ApplicantListScreen(),
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          CircleAvatar(
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade600,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'My Jobs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Freelancers',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (idx) => setState(() => _currentIndex = idx),
      ),
    );
  }

  Widget _buildHomeScreen(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? user.displayName ?? 'Client';
        final company = data['companyName'] ?? 'Your Company';
        final isVerified = data['isVerified'] == true;
        final walletBalance = (data['walletBalance'] ?? data['wallet'] ?? 0);

        // Dynamic Profile Completion for Client
        int completed = 0;
        if ((data['name'] as String?)?.isNotEmpty ?? false) completed++;
        if ((data['username'] as String?)?.isNotEmpty ?? false) completed++;
        if (data['country'] != null) completed++;
        if ((data['companyName'] as String?)?.isNotEmpty ?? false) {
          completed++;
        }
        if (((data['bio'] as String?)?.length ?? 0) >= 100) completed++;

        final profileCompletion = (completed / 5 * 100).round();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WELCOME CARD
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: user.photoURL == null
                                ? const Icon(Icons.business, size: 40)
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
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isVerified
                                          ? Icons.verified
                                          : Icons.verified_user_outlined,
                                      color: isVerified
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                                Text(
                                  company,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Wallet: ৳${(walletBalance is num ? walletBalance.toDouble() : double.tryParse(walletBalance.toString()) ?? 0).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: profileCompletion / 100,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation(
                                          profileCompletion >= 90
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$profileCompletion% Complete',
                                      style: const TextStyle(
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClientEditProfileScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Quick Top-up button
                          OutlinedButton.icon(
                            onPressed: () async {
                              final amountController = TextEditingController();
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Top-up Wallet'),
                                  content: TextField(
                                    controller: amountController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      hintText: 'Amount (e.g. 500)',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Top-up'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              final amt =
                                  double.tryParse(
                                    amountController.text.trim(),
                                  ) ??
                                  0;
                              if (amt <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid amount'),
                                  ),
                                );
                                return;
                              }

                              // perform demo top-up
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              try {
                                await PaymentService().topUpBalance(
                                  amount: amt,
                                );
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Wallet topped up'),
                                  ),
                                );
                              } catch (e) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Top-up failed: $e')),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.green,
                            ),
                            label: const Text('Top-up'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // POST A JOB BIG BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PostJobScreen()),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 32),
                  label: const Text(
                    'Post a New Job',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // STATS ROW
              Row(
                children: [
                  _buildStatCard(
                    'Total Spent',
                    '৳${(data['totalSpent'] ?? 0).toStringAsFixed(0)}',
                    Icons.paid,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Active Jobs',
                    (data['activeJobs'] ?? 0).toString(),
                    Icons.work,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Hired',
                    (data['hiredFreelancers'] ?? 0).toString(),
                    Icons.people,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // QUICK ACTIONS
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                context,
                'My Jobs',
                Icons.folder_open,
                Colors.blue,
                () => setState(() => _currentIndex = 1),
              ),
              _buildActionTile(
                context,
                'Hired Freelancers',
                Icons.person_search,
                Colors.purple,
                () => setState(() => _currentIndex = 2),
              ),
              _buildActionTile(
                context,
                'Invoices & Payments',
                Icons.receipt_long,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InvoicesPaymentsScreen(),
                  ),
                ),
              ),
              _buildActionTile(
                context,
                'Messages',
                Icons.message,
                Colors.green,
                () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: Colors.green.shade600, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
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

  Widget _buildActionTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
