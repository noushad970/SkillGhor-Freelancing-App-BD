// lib/screens/hired_freelancers_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'advanced_chat_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class HiredFreelancersScreen extends StatelessWidget {
  const HiredFreelancersScreen({super.key});

  String _formatAmount(dynamic raw) {
    if (raw == null) return '0';
    final n = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString()) ?? 0.0;
    return n.toStringAsFixed(0);
  }

  bool _isActive(dynamic s) {
    if (s == null) return false;
    if (s is int) return s == 0;
    if (s is String) {
      final v = s.toLowerCase();
      return v == 'active' ||
          v == 'ongoing' ||
          v == 'in_progress' ||
          v == 'awaiting_review' ||
          v == 'awaiting release';
    }
    return false;
  }

  bool _isAwaitingReview(dynamic s) {
    if (s is String) {
      final v = s.toLowerCase();
      return v == 'awaiting_review' || v == 'awaiting review';
    }
    return false;
  }

  Future<void> _handleFinalize(
    BuildContext context,
    DocumentSnapshot contractDoc,
    Map<String, dynamic> contract,
    String uid,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = _formatAmount(contract['amount'] ?? contract['budget'] ?? 0);
    final freelancerId = (contract['freelancerId'] as String?) ?? '';

    try {
      final completedByFreelancer = contract['completedByFreelancer'] == true;

      if (completedByFreelancer) {
        // Create a pending invoice for the freelancer
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Create invoice and release later?'),
            content: Text(
              'This will create a pending invoice of ৳$amount for the freelancer. You can release the payment from Invoices & Payments when ready.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create Invoice'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
        if (!context.mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final paymentRef = FirebaseFirestore.instance
              .collection('payments')
              .doc();
          await paymentRef.set({
            'userId': uid,
            'freelancerId': freelancerId,
            'jobId': contract['jobId'],
            'amount': double.tryParse(amount) ?? 0.0,
            'method': 'wallet',
            'status': 'pending',
            'type': 'jobPayment',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await contractDoc.reference.update({
            'status': 'awaiting_release',
            'invoiceId': paymentRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          try {
            await NotificationService().sendNotification(
              userId: freelancerId,
              type: NotificationType.contractCompleted,
              title: 'Invoice created',
              message:
                  'An invoice of ৳$amount was created for "${contract['jobTitle'] ?? 'your job'}". Waiting for client to release payment.',
              actionUrl: '/invoices',
              relatedJobId: contract['jobId']?.toString(),
            );
          } catch (_) {}

          if (!context.mounted) return;
          Navigator.of(context).pop(); // close progress
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Invoice created. Release the payment from Invoices & Payments.',
              ),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to create invoice: $e')),
          );
        }
      } else {
        await contractDoc.reference.update({
          'completedByClient': true,
          'completionReviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'status': 'awaiting_review',
        });

        try {
          await NotificationService().sendNotification(
            userId: freelancerId,
            type: NotificationType.contractCompleted,
            title: 'Client marked completed',
            message:
                'Client marked "${contract['jobTitle'] ?? 'the job'}" as completed. Please review.',
            actionUrl: '/contracts/${contractDoc.id}',
            relatedJobId: contract['jobId']?.toString(),
          );
        } catch (_) {}

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Marked as completed — awaiting freelancer review'),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _handleCancel(
    BuildContext context,
    DocumentSnapshot contractDoc,
    Map<String, dynamic> contract,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this contract?'),
        content: Text(
          'This will cancel the contract for "${contract['jobTitle'] ?? 'this job'}". The freelancer will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel contract'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await contractDoc.reference.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      try {
        await NotificationService().sendNotification(
          userId: (contract['freelancerId'] as String?) ?? '',
          type: NotificationType.jobClosed,
          title: 'Contract cancelled',
          message:
              'A contract for ${contract['jobTitle'] ?? 'a job'} was cancelled.',
          actionUrl: '/contracts/${contractDoc.id}',
        );
      } catch (_) {}
      messenger.showSnackBar(
        const SnackBar(content: Text('Contract cancelled')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('contracts')
            .where('clientId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                GradientHeader(
                  height: 168,
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Hired Freelancers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Loading your team...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final raw = snapshot.data?.docs ?? const [];
          final contracts = raw
              .where(
                (d) => _isActive(
                  (d.data() as Map<String, dynamic>? ?? {})['status'],
                ),
              )
              .toList();

          final awaitingReview = contracts
              .where(
                (d) => _isAwaitingReview(
                  (d.data() as Map<String, dynamic>? ?? {})['status'],
                ),
              )
              .length;
          final inProgress = contracts.length - awaitingReview;

          double totalSpend = 0;
          for (final d in contracts) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final raw = data['amount'] ?? data['budget'] ?? 0;
            totalSpend += raw is num
                ? raw.toDouble()
                : double.tryParse(raw.toString()) ?? 0.0;
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: GradientHeader(
                  height: 240,
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Hired Freelancers',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          PillBadge(
                            label: '${contracts.length} active',
                            color: Colors.white,
                            icon: Icons.people_alt_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        contracts.isEmpty
                            ? 'No active hires yet'
                            : 'Your working team and contract status',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Active',
                              value: '$inProgress',
                              icon: Icons.play_circle_outline,
                              accent: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              title: 'Awaiting',
                              value: '$awaitingReview',
                              icon: Icons.hourglass_top,
                              accent: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              title: 'Spend',
                              value: '৳${totalSpend.toStringAsFixed(0)}',
                              icon: Icons.account_balance_wallet_outlined,
                              accent: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (contracts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.people_outline,
                    title: 'No hired freelancers yet',
                    subtitle:
                        'When you accept a proposal, the freelancer and their contract will appear here for messaging, review, and payment release.',
                    action: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Post a job'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: contracts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final c = contracts[idx];
                      final cData = c.data() as Map<String, dynamic>;
                      final freelancerId =
                          (cData['freelancerId'] as String?) ?? '';
                      final jobId = (cData['jobId'] as String?) ?? '';
                      final completedByFreelancer =
                          cData['completedByFreelancer'] == true;

                      return FutureBuilder<DocumentSnapshot>(
                        future: freelancerId.isEmpty
                            ? null
                            : FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(freelancerId)
                                  .get(),
                        builder: (context, userSnap) {
                          final uData =
                              userSnap.data?.data() as Map<String, dynamic>? ??
                              const <String, dynamic>{};
                          final name =
                              (uData['name'] as String?) ?? 'Freelancer';
                          final photoUrl = uData['photoUrl'] as String?;
                          final rating = ((uData['rating'] ?? 0) as num)
                              .toDouble();
                          final totalReviews =
                              ((uData['totalReviews'] ?? 0) as num).toInt();
                          final skills =
                              (uData['skills'] as List<dynamic>?)
                                  ?.cast<String>() ??
                              const <String>[];

                          final status = cData['status'];
                          final awaitingReview = _isAwaitingReview(status);
                          final amount = _formatAmount(
                            cData['amount'] ?? cData['budget'] ?? 0,
                          );
                          final rate = _formatAmount(cData['rate']);

                          final pillColor = awaitingReview
                              ? AppColors.warning
                              : AppColors.success;
                          final pillLabel = awaitingReview
                              ? 'Awaiting'
                              : 'Active';

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.outline),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      backgroundImage: photoUrl != null
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: photoUrl == null
                                          ? const Icon(
                                              Icons.person,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                color: AppColors.accent,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '($totalReviews reviews)',
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    PillBadge(
                                      label: pillLabel,
                                      color: pillColor,
                                      icon: awaitingReview
                                          ? Icons.hourglass_top
                                          : Icons.check_circle_outline,
                                    ),
                                  ],
                                ),
                                if (skills.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: skills
                                        .take(4)
                                        .map(
                                          (s) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              s,
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.work_outline,
                                            size: 14,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              (cData['jobTitle'] as String?) ??
                                                  'Untitled job',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Rate',
                                                  style: TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  '৳$rate',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Total',
                                                  style: TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  '৳$amount',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.chat_bubble_outline,
                                          size: 16,
                                        ),
                                        label: const Text('Message'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AdvancedChatScreen(
                                                    otherUserId: freelancerId,
                                                    otherUserName: name,
                                                    jobId: jobId,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: Icon(
                                          completedByFreelancer
                                              ? Icons.payments_outlined
                                              : Icons.check,
                                          size: 16,
                                        ),
                                        label: Text(
                                          completedByFreelancer
                                              ? 'Finalize & release'
                                              : 'Mark complete',
                                        ),
                                        onPressed: () => _handleFinalize(
                                          context,
                                          c,
                                          cData,
                                          uid,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: AppColors.danger,
                                    ),
                                    label: const Text(
                                      'Cancel contract',
                                      style: TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _handleCancel(context, c, cData),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
