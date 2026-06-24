// lib/screens/active_contracts_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'advanced_chat_screen.dart';
import 'job_details_screen.dart';
import '../services/notification_service.dart';

class ActiveContractsScreen extends StatelessWidget {
  final String? initialContractId;

  const ActiveContractsScreen({super.key, this.initialContractId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    if (initialContractId != null && initialContractId!.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contract')),
        body: _buildSingleContractView(context, initialContractId!),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Active Contracts')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('contracts')
            .where('freelancerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active contracts'));
          }

          final raw = snapshot.data!.docs;

          final contracts = raw.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final status = data['status'];
            if (status == null) return false;
            if (status is int) return status == 0;
            if (status is String) {
              final s = status.toLowerCase();
              return s == 'active' || s == 'ongoing' || s == 'in_progress';
            }
            return false;
          }).toList();

          if (contracts.isEmpty) {
            return const Center(child: Text('No active contracts'));
          }

          return ListView.builder(
            itemCount: contracts.length,
            itemBuilder: (context, index) =>
                _buildContractCard(context, contracts[index]),
          );
        },
      ),
    );
  }

  Widget _buildSingleContractView(BuildContext context, String contractId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('contracts')
          .doc(contractId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Contract not found'));
        }
        return _buildContractCard(context, snapshot.data!);
      },
    );
  }

  Widget _buildContractCard(
    BuildContext context,
    DocumentSnapshot contractDoc,
  ) {
    final contract = contractDoc.data() as Map<String, dynamic>? ?? {};
    final clientId = contract['clientId'] as String? ?? '';
    final jobId = contract['jobId'] as String? ?? '';
    final statusIdx = (contract['status'] is int)
        ? contract['status'] as int
        : 0;
    final status = [
      'active',
      'completed',
      'cancelled',
      'paused',
    ][statusIdx.clamp(0, 3)];
    final createdAt = contract['createdAt'] as Timestamp?;
    final updatedAt = contract['updatedAt'] as Timestamp?;
    final amount = contract['amount'] ?? contract['budget'] ?? 0;
    final progress = (contract['progress'] ?? 0).toDouble();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(clientId)
          .get(),
      builder: (context, clientSnap) {
        final clientData =
            clientSnap.data?.data() as Map<String, dynamic>? ?? {};
        final clientName = (clientData['name'] as String?) ?? 'Client';
        final clientPhoto = clientData['photoUrl'] as String?;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'active'
                            ? Colors.green.shade50
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'active'
                              ? Colors.green.shade800
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (progress > 0) ...[
                  LinearProgressIndicator(
                    value: (progress.clamp(0, 100)) / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${progress.toStringAsFixed(0)}% Complete',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                ],
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
                  contract['summary'] ?? contract['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
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
                    _buildCompletionButton(context, contractDoc, contract),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletionButton(
    BuildContext context,
    DocumentSnapshot contractDoc,
    Map<String, dynamic> contract,
  ) {
    final completedByFreelancer = contract['completedByFreelancer'] == true;
    final completedByClient = contract['completedByClient'] == true;
    final completionRequestedAt =
        contract['completionRequestedAt'] as Timestamp?;
    final completionReviewedAt = contract['completionReviewedAt'] as Timestamp?;

    if (completedByClient) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.done_all, size: 16),
        label: Text(
          'Client marked completed${completionReviewedAt != null ? ' (${completionReviewedAt.toDate().toLocal().toString().split(' ')[0]})' : ''}',
        ),
      );
    }

    if (completedByFreelancer) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top, size: 16),
        label: Text(
          'Awaiting Client Finalization${completionRequestedAt != null ? ' (${completionRequestedAt.toDate().toLocal().toString().split(' ')[0]})' : ''}',
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () async {
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          await contractDoc.reference.update({
            'completedByFreelancer': true,
            'completionRequestedAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });

          try {
            final clientId = contract['clientId'] as String? ?? '';
            await NotificationService().sendNotification(
              userId: clientId,
              type: NotificationType.contractCompleted,
              title: 'Completion Requested',
              message:
                  'Freelancer marked "${contract['jobTitle'] ?? 'the job'}" as completed. Please review and finalize payment.',
              actionUrl: '/contracts/${contractDoc.id}',
              relatedJobId: contract['jobId'] ?? '',
            );
          } catch (_) {}

          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Completion requested — waiting for client finalization',
              ),
            ),
          );
        } catch (e) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      },
      icon: const Icon(Icons.check, size: 16),
      label: const Text('Mark Complete'),
    );
  }
}
