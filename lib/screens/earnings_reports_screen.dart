// lib/screens/earnings_reports_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EarningsReportsScreen extends StatelessWidget {
  const EarningsReportsScreen({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate().toLocal();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings & Reports')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final earnings = (data['totalEarnings'] ?? 0);
          final wallet = (data['walletBalance'] ?? data['wallet'] ?? 0);
          final pendingWithdrawals = (data['pendingWithdrawals'] ?? 0);

          return RefreshIndicator(
            onRefresh: () async {
              // simple refresh by re-reading user doc
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Earnings',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '৳${(earnings is num ? earnings.toDouble() : double.tryParse(earnings.toString()) ?? 0).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All-time earnings received',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Wallet Balance',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '৳${(wallet is num ? wallet.toDouble() : double.tryParse(wallet.toString()) ?? 0).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Available for withdrawal',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_actions,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pending Withdrawals',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pendingWithdrawals ?? 0} request(s) pending',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              // navigate to withdrawal / wallet screen if exists
                              Navigator.pushNamed(context, '/wallet');
                            },
                            child: const Text('Manage'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Recent Payments',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('payments')
                        .where('freelancerId', isEqualTo: user.uid)
                        .limit(10)
                        .snapshots(),
                    builder: (context, paySnap) {
                      if (paySnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (paySnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Error: ${paySnap.error}'),
                        );
                      }
                      final docs = paySnap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('No recent payments'),
                        );
                      }
                      return Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d =
                                docs[i].data() as Map<String, dynamic>? ?? {};
                            final amount = d['amount'] ?? d['paidAmount'] ?? 0;
                            final jobTitle =
                                d['jobTitle'] ?? d['description'] ?? '';
                            final createdAt = d['createdAt'] as Timestamp?;
                            return ListTile(
                              leading: const Icon(
                                Icons.payment,
                                color: Colors.green,
                              ),
                              title: Text(
                                '৳${(amount is num ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0).toStringAsFixed(0)}',
                              ),
                              subtitle: Text(jobTitle),
                              trailing: Text(
                                _formatDate(createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Recent Withdrawals',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('withdrawals')
                        .where('userId', isEqualTo: user.uid)
                        .limit(10)
                        .snapshots(),
                    builder: (context, wSnap) {
                      if (wSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (wSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Error: ${wSnap.error}'),
                        );
                      }
                      final docs = wSnap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('No withdrawals'),
                        );
                      }

                      return Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d =
                                docs[i].data() as Map<String, dynamic>? ?? {};
                            final amount = d['amount'] ?? 0;
                            final status = (d['status'] ?? 'pending')
                                .toString();
                            final requestedAt = d['requestedAt'] as Timestamp?;
                            return ListTile(
                              leading: Icon(
                                status.toLowerCase() == 'completed'
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color: status.toLowerCase() == 'completed'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              title: Text(
                                '৳${(amount is num ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0).toStringAsFixed(0)}',
                              ),
                              subtitle: Text(
                                'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                              ),
                              trailing: Text(
                                _formatDate(requestedAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
