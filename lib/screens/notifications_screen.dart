// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'job_details_screen.dart';
import 'messages_screen.dart';
import 'wallet_screen.dart';
import 'review_screen.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // When the user opens the notifications screen, mark all as read so the
    // unread badge clears. New notifications will re-appear automatically.
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Mark all as read?'),
                  content: const Text(
                    'This will mark all your notifications as read.',
                  ),
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All marked as read')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: notificationService.getAllNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return NotificationTile(
                notification: notif,
                onTap: () async {
                  await notificationService.markAsRead(notif.id);
                  if (!mounted)
                    return; // avoid using context after widget disposed
                  // Navigate based on actionUrl
                  if (notif.actionUrl != null) {
                    final url = notif.actionUrl!;
                    if (url.startsWith('/contracts/')) {
                      final contractId = url.split('/contracts/').last;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewScreen(contractId: contractId),
                        ),
                      );
                      return;
                    }
                    if (url.startsWith('/job/')) {
                      final jobId = url.split('/job/').last;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              JobDetailsScreen(jobId: jobId, isClient: false),
                        ),
                      );
                      return;
                    }
                    if (url.startsWith('/messages')) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessagesScreen(),
                        ),
                      );
                      return;
                    }
                    if (url.startsWith('/wallet')) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                      return;
                    }
                    // unknown route
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Action: $url')));
                    }
                  }
                },
                onDismiss: () async {
                  await notificationService.deleteNotification(notif.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getNotificationIcon(notification.type);
    final color = _getNotificationColor(notification.type);

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: notification.read ? Colors.white : Colors.blue.withOpacity(0.05),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.read
                              ? FontWeight.normal
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(notification.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!notification.read)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newProposal:
        return Icons.mail;
      case NotificationType.proposalApproved:
        return Icons.check_circle;
      case NotificationType.jobStarted:
        return Icons.play_circle;
      case NotificationType.messageReceived:
        return Icons.message;
      case NotificationType.paymentReceived:
        return Icons.payment;
      case NotificationType.paymentSent:
        return Icons.send;
      case NotificationType.contractCompleted:
        return Icons.done_all;
      case NotificationType.jobClosed:
        return Icons.close;
      case NotificationType.reviewReceived:
        return Icons.star;
      case NotificationType.bidIncreased:
        return Icons.trending_up;
      case NotificationType.deadlineReminder:
        return Icons.schedule;
      case NotificationType.connectLow:
        return Icons.warning;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.newProposal:
        return Colors.blue;
      case NotificationType.proposalApproved:
        return Colors.green;
      case NotificationType.jobStarted:
        return Colors.orange;
      case NotificationType.messageReceived:
        return Colors.purple;
      case NotificationType.paymentReceived:
        return Colors.green;
      case NotificationType.paymentSent:
        return Colors.blue;
      case NotificationType.contractCompleted:
        return Colors.green;
      case NotificationType.jobClosed:
        return Colors.red;
      case NotificationType.reviewReceived:
        return Colors.amber;
      case NotificationType.bidIncreased:
        return Colors.orange;
      case NotificationType.deadlineReminder:
        return Colors.red;
      case NotificationType.connectLow:
        return Colors.red;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return dateTime.toString().split(' ')[0];
    }
  }
}
