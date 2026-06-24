// lib/screens/active_contracts_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'advanced_chat_screen.dart';
import 'job_details_screen.dart';

class ActiveContractsScreen extends StatelessWidget {
  const ActiveContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Active Contracts')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('contracts')
            .where('freelancerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active contracts'));
          }

          final contracts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contractDoc = contracts[index];
              final contract = contractDoc.data() as Map<String, dynamic>;
              final clientId = contract['clientId'] as String? ?? '';
              final jobId = contract['jobId'] as String? ?? '';
              final status = (contract['status'] ?? 'active').toString();
              final createdAt = contract['createdAt'] as Timestamp?;
              final updatedAt = contract['updatedAt'] as Timestamp?;
              final amount = contract['amount'] ?? contract['budget'] ?? 0;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(clientId)
                    .get(),
                builder: (context, clientSnap) {
                  final clientData =
                      clientSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final clientName =
                      (clientData['name'] as String?) ?? 'Client';
                  final clientPhoto = clientData['photoUrl'] as String?;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: clientPhoto != null
                                    ? NetworkImage(clientPhoto)
                                    : null,
                                child: clientPhoto == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contract['jobTitle'] ?? 'Untitled',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Client: $clientName',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                              Chip(
                                label: Text(status.toUpperCase()),
                                backgroundColor: status == 'active'
                                    ? Colors.green.shade50
                                    : Colors.grey.shade200,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (createdAt != null)
                                Text(
                                  'Started: ${createdAt.toDate().toLocal().toString().split(' ')[0]}',
                                ),
                              const SizedBox(width: 12),
                              if (updatedAt != null)
                                Text(
                                  'Updated: ${updatedAt.toDate().toLocal().toString().split(' ')[0]}',
                                ),
                              const Spacer(),
                              Text(
                                '৳${(amount is num ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            contract['summary'] ??
                                contract['description'] ??
                                '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdvancedChatScreen(
                                        otherUserId: clientId,
                                        otherUserName: clientName,
                                        jobId: jobId,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.message, size: 16),
                                label: const Text('Message'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  if (jobId.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JobDetailsScreen(
                                          jobId: jobId,
                                          isClient: false,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('View Job'),
                              ),
                              const SizedBox(width: 8),
                              if (status != 'completed')
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await contractDoc.reference.update({
                                        'status': 'completed',
                                        'updatedAt': Timestamp.now(),
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Contract marked completed',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Mark Complete'),
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
          );
        },
      ),
    );
  }
}
