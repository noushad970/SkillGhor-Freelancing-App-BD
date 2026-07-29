// lib/screens/active_contracts_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'advanced_chat_screen.dart';
import 'job_details_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class ActiveContractsScreen extends StatefulWidget {
  const ActiveContractsScreen({super.key});

  @override
  State<ActiveContractsScreen> createState() => _ActiveContractsScreenState();
}

class _ActiveContractsScreenState extends State<ActiveContractsScreen> {
  String _formatAmount(dynamic raw) {
    if (raw == null) return '0';
    final n = raw is num
        ? raw.toDouble()
        : double.tryParse(raw.toString()) ?? 0.0;
    return n.toStringAsFixed(0);
  }

  Future<void> _markContractComplete(
    BuildContext context,
    DocumentReference contractRef,
    Map<String, dynamic> contract,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = _formatAmount(contract['amount'] ?? contract['budget'] ?? 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark contract as complete?'),
        content: Text(
          'This will request completion of your work on "${contract['jobTitle'] ?? 'this job'}". The client will need to approve and release the payment of ৳$amount.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Request completion'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    try {
      await contractRef.update({
        'completedByFreelancer': true,
        'freelancerCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'awaiting_review',
      });

      final clientId = contract['clientId']?.toString();
      if (clientId != null && clientId.isNotEmpty) {
        try {
          await NotificationService().sendNotification(
            userId: clientId,
            type: NotificationType.contractCompleted,
            title: 'Freelancer requested completion',
            message:
                '"${contract['jobTitle'] ?? 'Your job'}" is marked complete and waiting for your approval to release payment.',
            actionUrl: '/contracts/${contractRef.id}',
            relatedJobId: contract['jobId']?.toString(),
          );
        } catch (_) {}
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Completion requested — waiting for client finalization',
          ),
        ),
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
            .where('freelancerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingShell();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final raw = snapshot.data?.docs ?? const [];
          // Keep contracts that are in any non-terminal phase. Map numeric
          // indexes to friendly labels.
          bool isActive(dynamic s) {
            if (s == null) return false;
            if (s is int) return s == 0; // 0 = active
            if (s is String) {
              final v = s.toLowerCase();
              return v == 'active' ||
                  v == 'ongoing' ||
                  v == 'in_progress' ||
                  v == 'in progress' ||
                  v == 'awaiting_review' ||
                  v == 'awaiting review' ||
                  v == 'awaiting_release';
            }
            return false;
          }

          final contracts = raw.where((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            return isActive(data['status']);
          }).toList();

          // Stats
          final pendingCount = contracts.where((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final s = data['status'];
            final sStr = s is String
                ? s.toLowerCase()
                : (s is int && s == 0 ? 'active' : '');
            return sStr == 'awaiting_review' || sStr == 'awaiting review';
          }).length;

          final inProgressCount = contracts.length - pendingCount;

          double totalEarnings = 0;
          for (final d in contracts) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final raw = data['amount'] ?? data['budget'] ?? 0;
            totalEarnings += raw is num
                ? raw.toDouble()
                : double.tryParse(raw.toString()) ?? 0.0;
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ActiveHero(
                  count: contracts.length,
                  inProgress: inProgressCount,
                  pending: pendingCount,
                  earnings: totalEarnings.toStringAsFixed(0),
                ),
              ),
              if (contracts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'No active contracts yet',
                    subtitle:
                        'When a client accepts your proposal, the contract will appear here so you can track progress and earnings.',
                    action: ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Browse jobs'),
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
                      return _ContractCard(
                        contractDoc: c,
                        contractData: cData,
                        onComplete: () =>
                            _markContractComplete(context, c.reference, cData),
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

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
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
                'Active Contracts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Loading your work...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

class _ActiveHero extends StatelessWidget {
  final int count;
  final int inProgress;
  final int pending;
  final String earnings;
  const _ActiveHero({
    required this.count,
    required this.inProgress,
    required this.pending,
    required this.earnings,
  });

  @override
  Widget build(BuildContext context) {
    return GradientHeader(
      height: 240,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Active Contracts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PillBadge(
                label: '$count total',
                color: Colors.white,
                icon: Icons.work_outline,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count == 0
                ? 'No active work right now'
                : 'Track progress, earnings and messages in one place',
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
                  title: 'In progress',
                  value: '$inProgress',
                  icon: Icons.play_circle_outline,
                  accent: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  title: 'Awaiting',
                  value: '$pending',
                  icon: Icons.hourglass_top,
                  accent: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  title: 'Earnings',
                  value: '৳$earnings',
                  icon: Icons.payments_outlined,
                  accent: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final DocumentSnapshot contractDoc;
  final Map<String, dynamic> contractData;
  final VoidCallback onComplete;

  const _ContractCard({
    required this.contractDoc,
    required this.contractData,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final jobTitle = (contractData['jobTitle'] as String?) ?? 'Untitled job';
    final jobId = (contractData['jobId'] as String?) ?? '';
    final clientId = (contractData['clientId'] as String?) ?? '';
    final progress = ((contractData['progress'] ?? 0) as num).toDouble();
    final deadline = contractData['deadline'];
    final amountRaw = contractData['amount'] ?? contractData['budget'] ?? 0;
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw.toString()) ?? 0.0;

    final status = contractData['status'];
    final awaitingReview = status is String
        ? (status.toLowerCase() == 'awaiting_review' ||
              status.toLowerCase() == 'awaiting review')
        : false;
    final inProgress = status is int
        ? status == 0
        : (status is String &&
              (status.toLowerCase() == 'active' ||
                  status.toLowerCase() == 'in_progress' ||
                  status.toLowerCase() == 'ongoing'));

    final pillColor = awaitingReview
        ? AppColors.warning
        : (inProgress ? AppColors.success : AppColors.info);
    final pillLabel = awaitingReview
        ? 'Awaiting client'
        : (inProgress ? 'In progress' : 'Active');

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
              Expanded(
                child: Text(
                  jobTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
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
          const SizedBox(height: 12),
          FutureBuilder<DocumentSnapshot>(
            future: clientId.isEmpty
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(clientId)
                      .get(),
            builder: (context, snap) {
              final name =
                  (snap.data?.data() as Map<String, dynamic>? ?? {})['name']
                      as String? ??
                  'Client';
              return Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'with $name',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '৳${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDeadline(deadline),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.update, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatLastUpdate(contractDoc),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (progress.clamp(0, 100)) / 100,
              backgroundColor: AppColors.outline,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message'),
                  onPressed: () async {
                    final clientSnap = clientId.isEmpty
                        ? null
                        : await FirebaseFirestore.instance
                              .collection('users')
                              .doc(clientId)
                              .get();
                    final name =
                        ((clientSnap?.data() ??
                                const <String, dynamic>{})['name'])
                            as String? ??
                        'Client';
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdvancedChatScreen(
                          otherUserId: clientId,
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
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View job'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            JobDetailsScreen(jobId: jobId, isClient: false),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                awaitingReview
                    ? Icons.hourglass_top
                    : Icons.check_circle_outline,
                size: 16,
              ),
              label: Text(
                awaitingReview
                    ? 'Awaiting client approval'
                    : 'Mark as complete',
              ),
              onPressed: awaitingReview || !inProgress ? null : onComplete,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeadline(dynamic raw) {
    if (raw is Timestamp) {
      final dt = raw.toDate();
      return 'Due ${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return 'No deadline set';
  }

  String _formatLastUpdate(DocumentSnapshot doc) {
    final raw = (doc.data() as Map<String, dynamic>? ?? {})['updatedAt'];
    if (raw is Timestamp) {
      final dt = raw.toDate();
      final days = DateTime.now().difference(dt).inDays;
      if (days <= 0) return 'Updated today';
      if (days == 1) return 'Updated 1 day ago';
      return 'Updated $days days ago';
    }
    return 'No updates yet';
  }
}
