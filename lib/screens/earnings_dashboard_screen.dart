// lib/screens/earnings_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_service.dart';

class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final paymentService = PaymentService();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Earnings Dashboard'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stats Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Total Earnings
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get(),
                    builder: (context, snapshot) {
                      final totalEarnings =
                          (snapshot.data?.get('totalEarnings') ?? 0).toDouble();

                      return StatsCard(
                        title: 'Total Earnings',
                        amount: '৳${totalEarnings.toStringAsFixed(2)}',
                        icon: Icons.trending_up,
                        color: Colors.green,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Monthly Earnings
                  FutureBuilder<double>(
                    future: _getMonthlyEarnings(uid),
                    builder: (context, snapshot) {
                      final monthlyEarnings = snapshot.data ?? 0;

                      return StatsCard(
                        title: 'This Month',
                        amount: '৳${monthlyEarnings.toStringAsFixed(2)}',
                        icon: Icons.calendar_today,
                        color: Colors.blue,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Pending Earnings
                  FutureBuilder<double>(
                    future: _getPendingEarnings(uid),
                    builder: (context, snapshot) {
                      final pendingEarnings = snapshot.data ?? 0;

                      return StatsCard(
                        title: 'Pending Payments',
                        amount: '৳${pendingEarnings.toStringAsFixed(2)}',
                        icon: Icons.schedule,
                        color: Colors.orange,
                      );
                    },
                  ),
                ],
              ),
            ),

            // Charts & Analytics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top Earning Clients',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getTopClients(uid),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final clients = snapshot.data ?? [];
                          if (clients.isEmpty) {
                            return const Center(child: Text('No earnings yet'));
                          }

                          return Column(
                            children: clients
                                .map(
                                  (client) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                client['clientName'] ??
                                                    'Unknown',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${client['jobsCompleted']} jobs',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '৳${(client['totalEarned'] ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Transaction History
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: StreamBuilder<List<Payment>>(
                        stream: paymentService.getPaymentHistory(limit: 10),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final transactions = snapshot.data ?? [];
                          if (transactions.isEmpty) {
                            return const Center(child: Text('No transactions'));
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: transactions.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final txn = transactions[index];
                              final isIncome =
                                  txn.type == TransactionType.jobPayment;

                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getTransactionLabel(
                                            TransactionType.values.firstWhere(
                                              (e) => e.toString() == txn.type,
                                              orElse: () =>
                                                  TransactionType.jobPayment,
                                            ),
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          txn.createdAt.toString().split(
                                            ' ',
                                          )[0],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? '+' : '-'}৳${txn.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isIncome
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<double> _getMonthlyEarnings(String uid) async {
    try {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);

      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: uid)
          .where('type', isEqualTo: TransactionType.jobPayment.index)
          .where('status', isEqualTo: PaymentStatus.completed.index)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay),
          )
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        total += (doc['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<double> _getPendingEarnings(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: PaymentStatus.pending.index)
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        total += (doc['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _getTopClients(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('freelancerId', isEqualTo: uid)
          .where('type', isEqualTo: TransactionType.jobPayment.index)
          .get();

      // Group by client and calculate totals
      final Map<String, Map<String, dynamic>> clientMap = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final clientId = data['userId'] ?? '';

        if (!clientMap.containsKey(clientId)) {
          // Fetch client name
          final clientDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(clientId)
              .get();
          final clientName = clientDoc.get('name') ?? 'Unknown';

          clientMap[clientId] = {
            'clientId': clientId,
            'clientName': clientName,
            'totalEarned': 0.0,
            'jobsCompleted': 0,
          };
        }

        clientMap[clientId]!['totalEarned'] =
            (clientMap[clientId]!['totalEarned'] ?? 0.0) +
            (data['amount'] ?? 0).toDouble();
        clientMap[clientId]!['jobsCompleted'] =
            (clientMap[clientId]!['jobsCompleted'] ?? 0) + 1;
      }

      // Sort by earnings
      final clients = clientMap.values.toList();
      clients.sort(
        (a, b) =>
            (b['totalEarned'] as double).compareTo(a['totalEarned'] as double),
      );

      return clients.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  String _getTransactionLabel(TransactionType type) {
    switch (type) {
      case TransactionType.jobPayment:
        return 'Job Payment Received';
      case TransactionType.connectPurchase:
        return 'Connect Purchase';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.bonus:
        return 'Bonus';
    }
  }
}

class StatsCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const StatsCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
