// lib/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_service.dart';
import 'buy_connects_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final paymentService = PaymentService();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Wallet & Earnings'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Balance Card
            FutureBuilder<double>(
              future: paymentService.getWalletBalance(uid),
              builder: (context, snapshot) {
                final balance = snapshot.data ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.green.shade600,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '৳${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showWithdrawDialog(context),
                                  icon: const Icon(Icons.payments),
                                  label: const Text('Withdraw'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.green.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const BuyConnectsScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Money'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Tabs: Transactions & Withdrawals
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Colors.green.shade600,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.green.shade600,
                      tabs: const [
                        Tab(text: 'Transactions'),
                        Tab(text: 'Withdrawals'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        children: [
                          // Transactions Tab
                          StreamBuilder<List<Payment>>(
                            stream: paymentService.getPaymentHistory(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final transactions = snapshot.data ?? [];
                              if (transactions.isEmpty) {
                                return const Center(
                                  child: Text('No transactions yet'),
                                );
                              }

                              return ListView.separated(
                                itemCount: transactions.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final txn = transactions[index];
                                  final isIncome =
                                      txn.type == 'jobPayment' ||
                                      txn.type == 'bonus';

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isIncome
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : Colors.red.withValues(alpha: 0.2),
                                      child: Icon(
                                        isIncome
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color: isIncome
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    title: Text(_getTransactionTitle(txn.type)),
                                    subtitle: Text(
                                      txn.createdAt.toString().split('.')[0],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    trailing: Text(
                                      '${isIncome ? '+' : '-'}৳${txn.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isIncome
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          // Withdrawals Tab
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: paymentService.getWithdrawalHistory(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final withdrawals = snapshot.data ?? [];
                              if (withdrawals.isEmpty) {
                                return const Center(
                                  child: Text('No withdrawals yet'),
                                );
                              }

                              return ListView.separated(
                                itemCount: withdrawals.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final withdrawal = withdrawals[index];

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange.withValues(
                                        alpha: 0.2,
                                      ),
                                      child: const Icon(
                                        Icons.money,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    title: const Text('Withdrawal Request'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          withdrawal['bankName'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          withdrawal['status'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _getStatusColor(
                                              withdrawal['status'],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '৳${(withdrawal['amount'] ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTransactionTitle(String type) {
    switch (type) {
      case 'jobPayment':
        return 'Job Payment';
      case 'connectPurchase':
        return 'Connect Purchase';
      case 'withdrawal':
        return 'Withdrawal';
      case 'refund':
        return 'Refund';
      case 'bonus':
        return 'Bonus';
      default:
        return type;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showWithdrawDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final paymentService = PaymentService();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Request Withdrawal'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (BDT)',
                  prefixText: '\u09F3 ',
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Bank Name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bankCtrl,
                decoration: const InputDecoration(labelText: 'Account Number'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await paymentService.requestWithdrawal(
                  amount: double.parse(amountCtrl.text.trim()),
                  bankName: nameCtrl.text.trim(),
                  bankAccount: bankCtrl.text.trim(),
                );
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Withdrawal request submitted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(
                    content: Text('Withdrawal failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
