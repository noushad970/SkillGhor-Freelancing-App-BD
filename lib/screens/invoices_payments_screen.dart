// lib/screens/invoices_payments_screen.dart
import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class InvoicesPaymentsScreen extends StatelessWidget {
  const InvoicesPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final paymentService = PaymentService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices & Payments'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Payment>>(
              stream: paymentService.getPaymentHistoryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                final transactions = snapshot.data!;

                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = transactions[index];

                    // Show actionable Release button for pending job payments
                    final isPendingInvoice =
                        t.status == 'pending' && t.type == 'jobPayment';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: t.amount >= 0
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        child: Icon(
                          t.amount >= 0
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: t.amount >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text('\u09F3${t.amount.toStringAsFixed(0)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.type.toUpperCase()),
                          if (t.jobId != null && t.jobId!.isNotEmpty)
                            Text('Job: ${t.jobId}'),
                        ],
                      ),
                      trailing: isPendingInvoice
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: const Text('Release'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Release Payment'),
                                    content: Text(
                                      'Are you sure you want to release \u09F3${t.amount.toStringAsFixed(0)} to the freelancer? This will deduct the amount from your wallet.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Release'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true) return;

                                // show progress
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                try {
                                  await paymentService.finalizePendingPayment(
                                    t.id,
                                  );
                                  Navigator.of(
                                    context,
                                  ).pop(); // dismiss progress
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Payment released'),
                                    ),
                                  );
                                } catch (e) {
                                  Navigator.of(
                                    context,
                                  ).pop(); // dismiss progress
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Release failed: $e'),
                                    ),
                                  );
                                }
                              },
                            )
                          : Text(t.status.toUpperCase()),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
