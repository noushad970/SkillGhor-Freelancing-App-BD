// lib/screens/hired_freelancers_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'advanced_chat_screen.dart';
import '../services/notification_service.dart';

class HiredFreelancersScreen extends StatelessWidget {
  const HiredFreelancersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Hired Freelancers'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query by clientId only, keep status filtering in code to support
        // both numeric enum indexes and older string statuses in the DB.
        stream: FirebaseFirestore.instance
            .collection('contracts')
            .where('clientId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final raw = snapshot.data?.docs ?? const [];

          // Filter active contracts client-side to handle both numeric and string status
          final contracts = raw.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final status = data['status'];
            if (status == null) return false;
            if (status is int) {
              return status == 0; // ContractStatus.active.index
            }
            if (status is String) {
              final s = status.toLowerCase();
              return s == 'active' || s == 'ongoing' || s == 'in_progress';
            }
            return false;
          }).toList();

          if (contracts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No hired freelancers yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: contracts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final c = contracts[idx];
              final cData = c.data() as Map<String, dynamic>;
              final freelancerId = cData['freelancerId'] as String? ?? '';
              final jobId = cData['jobId'] as String? ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(freelancerId)
                    .get(),
                builder: (context, userSnap) {
                  final uData =
                      userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final name = (uData['name'] as String?) ?? 'Freelancer';
                  final photoUrl = uData['photoUrl'] as String?;
                  final rating = (uData['rating'] ?? 0) as num;
                  final totalReviews = (uData['totalReviews'] ?? 0) as int;
                  final skills = (uData['skills'] as List<dynamic>? ?? [])
                      .cast<String>();

                  return Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber[700],
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('($totalReviews)'),
                                      ],
                                    ),
                                    Text(
                                      'Hired for: ${cData['jobTitle'] ?? 'Unknown Job'}',
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
                          if (skills.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 4,
                                children: skills
                                    .take(3)
                                    .map(
                                      (s) => Chip(
                                        label: Text(s),
                                        labelStyle: const TextStyle(
                                          fontSize: 10,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AdvancedChatScreen(
                                          otherUserId: freelancerId,
                                          otherUserName: name,
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
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final contract =
                                          c.data() as Map<String, dynamic>;
                                      final freelancerId =
                                          contract['freelancerId'] as String? ??
                                          '';
                                      final jobId =
                                          contract['jobId'] as String? ?? '';
                                      final amountRaw =
                                          contract['amount'] ??
                                          contract['budget'] ??
                                          0;
                                      final amount = (amountRaw is num)
                                          ? amountRaw.toDouble()
                                          : double.tryParse(
                                                  amountRaw.toString(),
                                                ) ??
                                                0.0;

                                      if (contract['completedByFreelancer'] ==
                                          true) {
                                        // Create a pending invoice instead of immediate payment
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Create invoice and release later?',
                                            ),
                                            content: Text(
                                              'This will create a pending invoice of \u09F3${amount.toStringAsFixed(0)} for the freelancer. You can release the payment from Invoices & Payments when ready.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text(
                                                  'Create Invoice',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true) return;

                                        // show progress
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );

                                        try {
                                          // create pending payment document (invoice)
                                          final paymentRef = FirebaseFirestore
                                              .instance
                                              .collection('payments')
                                              .doc();
                                          await paymentRef.set({
                                            'userId': uid,
                                            'freelancerId': freelancerId,
                                            'jobId': jobId,
                                            'amount': amount,
                                            'method': 'wallet',
                                            'status': 'pending',
                                            'type': 'jobPayment',
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                          });

                                          // update contract to indicate invoice created / awaiting release
                                          await c.reference.update({
                                            'status': 'awaiting_release',
                                            'invoiceId': paymentRef.id,
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          });

                                          // notify freelancer about invoice creation
                                          try {
                                            await NotificationService()
                                                .sendNotification(
                                                  userId: freelancerId,
                                                  type: NotificationType
                                                      .contractCompleted,
                                                  title: 'Invoice created',
                                                  message:
                                                      'An invoice of \u09F3${amount.toStringAsFixed(0)} was created for "${cData['jobTitle'] ?? 'your job'}". Waiting for client to release payment.',
                                                  actionUrl: '/invoices',
                                                  relatedJobId: jobId,
                                                );
                                          } catch (_) {}

                                          Navigator.of(
                                            context,
                                          ).pop(); // close progress

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Invoice created. Release the payment from Invoices & Payments.',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to create invoice: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        // Client marking complete (inform freelancer)
                                        await c.reference.update({
                                          'completedByClient': true,
                                          'completionReviewedAt':
                                              FieldValue.serverTimestamp(),
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                          // Move out of active list while awaiting review
                                          'status': 'awaiting_review',
                                        });

                                        // notify freelancer to check
                                        try {
                                          await NotificationService()
                                              .sendNotification(
                                                userId: freelancerId,
                                                type: NotificationType
                                                    .contractCompleted,
                                                title:
                                                    'Client marked completed',
                                                message:
                                                    'Client marked "${contract['jobTitle'] ?? 'the job'}" as completed. Please review.',
                                                actionUrl: '/contracts/${c.id}',
                                                relatedJobId:
                                                    contract['jobId'] ?? '',
                                              );
                                        } catch (_) {}

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Marked as completed — awaiting freelancer review',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(
                                    (c.data()
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['completedByFreelancer'] ==
                                            true
                                        ? 'Finalize & Release'
                                        : 'Complete',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton(
                                  onPressed: () async {
                                    try {
                                      await c.reference.update({
                                        'status':
                                            2, // ContractStatus.cancelled.index
                                        'cancelledAt':
                                            FieldValue.serverTimestamp(),
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                      final contract =
                                          c.data() as Map<String, dynamic>;
                                      try {
                                        await NotificationService()
                                            .sendNotification(
                                              userId:
                                                  contract['freelancerId'] ??
                                                  '',
                                              type: NotificationType.jobClosed,
                                              title: 'Contract cancelled',
                                              message:
                                                  'A contract for ${contract['jobTitle'] ?? 'a job'} was cancelled.',
                                              actionUrl: '/contracts/${c.id}',
                                            );
                                      } catch (_) {}

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Contract cancelled'),
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
                                  child: const Text('Cancel'),
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
          );
        },
      ),
    );
  }
}
