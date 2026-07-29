// lib/screens/notifications_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'job_details_screen.dart';
import 'messages_screen.dart';
import 'wallet_screen.dart';
import 'review_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  String _filter = 'all'; // 'all' | 'unread'
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _notificationService.markAllAsRead();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = _notificationService;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            height: 168,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _HeaderIconButton(
                      icon: Icons.refresh,
                      tooltip: 'Refresh',
                      onPressed: () => setState(() {}),
                    ),
                    const SizedBox(width: 8),
                    _HeaderIconButton(
                      icon: Icons.done_all,
                      tooltip: 'Mark all as read',
                      onPressed: () => _confirmMarkAllRead(notificationService),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<AppNotification>>(
                  stream: notificationService.getAllNotifications(),
                  builder: (context, snapshot) {
                    final unread = (snapshot.data ?? [])
                        .where((n) => !n.read)
                        .length;
                    if (unread != _unreadCount) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _unreadCount = unread);
                      });
                    }
                    return Row(
                      children: [
                        PillBadge(
                          label: unread == 0
                              ? 'All caught up'
                              : '$unread unread',
                          color: unread == 0 ? Colors.white : AppColors.accent,
                          icon: unread == 0
                              ? Icons.check_circle
                              : Icons.notifications_active,
                        ),
                        const Spacer(),
                        Text(
                          'Tap any item to open',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _FilterRow(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: notificationService.getAllNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final notifications = (snapshot.data ?? []).where((n) {
                  if (_filter == 'unread') return !n.read;
                  return true;
                }).toList();

                if (notifications.isEmpty) {
                  return EmptyState(
                    icon: _filter == 'unread'
                        ? Icons.mark_email_read
                        : Icons.notifications_none,
                    title: _filter == 'unread'
                        ? 'Nothing unread'
                        : 'No notifications yet',
                    subtitle: _filter == 'unread'
                        ? 'You have read all your notifications.'
                        : 'New job proposals, messages, and payments will show up here.',
                    action: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      onPressed: () => setState(() {}),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return _NotificationTile(
                        notification: notif,
                        onTap: () =>
                            _onTap(context, notificationService, notif),
                        onDismiss: () =>
                            notificationService.deleteNotification(notif.id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMarkAllRead(
    NotificationService notificationService,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: const Text('This will mark all your notifications as read.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await notificationService.markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All marked as read')));
      }
    }
  }

  Future<void> _onTap(
    BuildContext context,
    NotificationService notificationService,
    AppNotification notif,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await notificationService.markAsRead(notif.id);
    if (!mounted) return;
    final url = notif.actionUrl;
    if (url == null) return;

    if (url.startsWith('/contracts/')) {
      final contractId = url.split('/contracts/').last;
      navigator.push(
        MaterialPageRoute(builder: (_) => ReviewScreen(contractId: contractId)),
      );
      return;
    }
    if (url.startsWith('/job/')) {
      final jobId = url.split('/job/').last;
      String userRole = 'freelancer';
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final r = userDoc.data()?['role'];
          if (r is String && r.toLowerCase() == 'client') {
            userRole = 'client';
          }
        }
      } catch (_) {}
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              JobDetailsScreen(jobId: jobId, isClient: userRole == 'client'),
        ),
      );
      return;
    }
    if (url.startsWith('/messages')) {
      navigator.push(MaterialPageRoute(builder: (_) => const MessagesScreen()));
      return;
    }
    if (url.startsWith('/wallet')) {
      navigator.push(MaterialPageRoute(builder: (_) => const WalletScreen()));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('Action: $url')));
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _FilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: value == 'all',
            onTap: () => onChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Unread',
            selected: value == 'unread',
            onTap: () => onChanged('unread'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(notification.type);
    final color = _colorFor(notification.type);
    final isRead = notification.read;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isRead
                  ? Colors.white
                  : AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead
                    ? AppColors.outline
                    : AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeAgo(notification.createdAt),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          PillBadge(
                            label: _labelFor(notification.type),
                            color: color,
                            icon: icon,
                          ),
                          const Spacer(),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.newProposal:
        return Icons.mail_outline;
      case NotificationType.proposalApproved:
        return Icons.check_circle_outline;
      case NotificationType.jobStarted:
        return Icons.play_circle_outline;
      case NotificationType.messageReceived:
        return Icons.chat_bubble_outline;
      case NotificationType.paymentReceived:
        return Icons.payments_outlined;
      case NotificationType.paymentSent:
        return Icons.send;
      case NotificationType.contractCompleted:
        return Icons.task_alt;
      case NotificationType.jobClosed:
        return Icons.cancel_outlined;
      case NotificationType.reviewReceived:
        return Icons.star_rate_rounded;
      case NotificationType.bidIncreased:
        return Icons.trending_up;
      case NotificationType.deadlineReminder:
        return Icons.alarm;
      case NotificationType.connectLow:
        return Icons.warning_amber_rounded;
    }
  }

  static Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.newProposal:
        return AppColors.secondary;
      case NotificationType.proposalApproved:
        return AppColors.success;
      case NotificationType.jobStarted:
        return AppColors.warning;
      case NotificationType.messageReceived:
        return AppColors.info;
      case NotificationType.paymentReceived:
        return AppColors.primary;
      case NotificationType.paymentSent:
        return AppColors.secondary;
      case NotificationType.contractCompleted:
        return AppColors.success;
      case NotificationType.jobClosed:
        return AppColors.danger;
      case NotificationType.reviewReceived:
        return AppColors.accent;
      case NotificationType.bidIncreased:
        return AppColors.warning;
      case NotificationType.deadlineReminder:
        return AppColors.danger;
      case NotificationType.connectLow:
        return AppColors.danger;
    }
  }

  static String _labelFor(NotificationType type) {
    switch (type) {
      case NotificationType.newProposal:
        return 'Proposal';
      case NotificationType.proposalApproved:
        return 'Approved';
      case NotificationType.jobStarted:
        return 'Job started';
      case NotificationType.messageReceived:
        return 'Message';
      case NotificationType.paymentReceived:
        return 'Payment';
      case NotificationType.paymentSent:
        return 'Sent';
      case NotificationType.contractCompleted:
        return 'Completed';
      case NotificationType.jobClosed:
        return 'Closed';
      case NotificationType.reviewReceived:
        return 'Review';
      case NotificationType.bidIncreased:
        return 'Bid';
      case NotificationType.deadlineReminder:
        return 'Reminder';
      case NotificationType.connectLow:
        return 'Alert';
    }
  }

  static String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateTime.toString().split(' ')[0];
  }
}
