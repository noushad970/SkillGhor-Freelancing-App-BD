// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum NotificationType {
  newProposal,
  proposalApproved,
  jobStarted,
  messageReceived,
  paymentReceived,
  paymentSent,
  contractCompleted,
  jobClosed,
  reviewReceived,
  bidIncreased,
  deadlineReminder,
  connectLow,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? actionUrl;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool read;
  final String? relatedUserId;
  final String? relatedJobId;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.actionUrl,
    this.data,
    required this.createdAt,
    this.read = false,
    this.relatedUserId,
    this.relatedJobId,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      userId: map['userId'] ?? '',
      type: NotificationType.values[map['type'] ?? 0],
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      actionUrl: map['actionUrl'],
      data: map['data'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: map['read'] ?? false,
      relatedUserId: map['relatedUserId'],
      relatedJobId: map['relatedJobId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type.index,
    'title': title,
    'message': message,
    'actionUrl': actionUrl,
    'data': data,
    'createdAt': Timestamp.fromDate(createdAt),
    'read': read,
    'relatedUserId': relatedUserId,
    'relatedJobId': relatedJobId,
  };
}

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send notification to user
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? actionUrl,
    Map<String, dynamic>? data,
    String? relatedUserId,
    String? relatedJobId,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'type': type.index,
        'title': title,
        'message': message,
        'actionUrl': actionUrl,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'relatedUserId': relatedUserId,
        'relatedJobId': relatedJobId,
      });

      // Update unread count
      await _db.collection('users').doc(userId).update({
        'unreadNotifications': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }

  /// Get unread notifications
  Stream<List<AppNotification>> getUnreadNotifications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          final notifications = snap.docs
              .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
              .toList();
          // Filter unread in code
          notifications.removeWhere((n) => n.read);
          return notifications.take(50).toList();
        });
  }

  /// Get all notifications
  Stream<List<AppNotification>> getAllNotifications({int limit = 100}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'read': true,
      });

      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).update({
          'unreadNotifications': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final batch = _db.batch();
      final notifications = await _db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in notifications.docs) {
        if (!(doc.data()['read'] ?? false)) {
          batch.update(doc.reference, {'read': true});
        }
      }

      // Reset unread count
      batch.update(_db.collection('users').doc(uid), {
        'unreadNotifications': 0,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Get notification count
  Future<int> getUnreadCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      return (doc.data()?['unreadNotifications'] ?? 0) as int;
    } catch (e) {
      return 0;
    }
  }

  /// Notify proposal received
  Future<void> notifyProposalReceived({
    required String jobId,
    required String jobTitle,
    required String freelancerName,
    required String clientId,
  }) async {
    await sendNotification(
      userId: clientId,
      type: NotificationType.newProposal,
      title: 'New Proposal',
      message: '$freelancerName submitted a proposal for "$jobTitle"',
      actionUrl: '/applicants/$jobId',
      relatedJobId: jobId,
    );
  }

  /// Notify proposal approved
  Future<void> notifyProposalApproved({
    required String jobId,
    required String jobTitle,
    required String freelancerId,
    required String clientName,
  }) async {
    await sendNotification(
      userId: freelancerId,
      type: NotificationType.proposalApproved,
      title: 'Proposal Approved!',
      message: '$clientName approved your proposal for "$jobTitle"',
      actionUrl: '/contracts/$jobId',
      relatedJobId: jobId,
    );
  }

  /// Notify job started
  Future<void> notifyJobStarted({
    required String jobId,
    required String jobTitle,
    required String clientId,
    required String freelancerId,
  }) async {
    await sendNotification(
      userId: clientId,
      type: NotificationType.jobStarted,
      title: 'Job Started',
      message: 'Work has started on "$jobTitle"',
      actionUrl: '/job/$jobId',
      relatedJobId: jobId,
    );

    await sendNotification(
      userId: freelancerId,
      type: NotificationType.jobStarted,
      title: 'Job Started',
      message: 'You have started work on "$jobTitle"',
      actionUrl: '/job/$jobId',
      relatedJobId: jobId,
    );
  }

  /// Notify message received
  Future<void> notifyMessageReceived({
    required String userId,
    required String senderName,
    required String message,
    String? jobId,
  }) async {
    await sendNotification(
      userId: userId,
      type: NotificationType.messageReceived,
      title: 'New Message from $senderName',
      message: message,
      actionUrl: '/messages',
      relatedJobId: jobId,
    );
  }

  /// Notify payment received
  Future<void> notifyPaymentReceived({
    required String userId,
    required double amount,
    required String jobTitle,
  }) async {
    await sendNotification(
      userId: userId,
      type: NotificationType.paymentReceived,
      title: 'Payment Received',
      message: 'You received ৳$amount for "$jobTitle"',
      actionUrl: '/wallet',
    );
  }

  /// Notify contract completed
  Future<void> notifyContractCompleted({
    required String jobId,
    required String jobTitle,
    required String clientId,
    required String freelancerId,
  }) async {
    await sendNotification(
      userId: clientId,
      type: NotificationType.contractCompleted,
      title: 'Contract Completed',
      message: 'Contract for "$jobTitle" has been completed',
      actionUrl: '/job/$jobId',
      relatedJobId: jobId,
    );

    await sendNotification(
      userId: freelancerId,
      type: NotificationType.contractCompleted,
      title: 'Contract Completed',
      message: 'You completed "$jobTitle"',
      actionUrl: '/job/$jobId',
      relatedJobId: jobId,
    );
  }
}
