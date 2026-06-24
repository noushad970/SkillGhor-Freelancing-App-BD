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
                      subtitle: Text(t.type.name.toUpperCase()),
                      trailing: Text(t.status.name.toUpperCase()),
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
