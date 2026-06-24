// lib/services/payment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

enum PaymentMethod { wallet, card, bkash, nagad }

enum PaymentStatus { pending, completed, failed, refunded }

enum TransactionType { jobPayment, connectPurchase, withdrawal, refund, bonus }

class Payment {
  final String id;
  final String userId;
  final double amount;
  final String method;
  final String status;
  final String type;
  final String? jobId;
  final String? freelancerId;
  final String? note;
  final DateTime createdAt;
  final DateTime? completedAt;

  Payment({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    required this.type,
    this.jobId,
    this.freelancerId,
    this.note,
    required this.createdAt,
    this.completedAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map, String id) {
    // status and type stored as strings in schema
    String _parseString(dynamic raw, List<String> enumNames, int fallback) {
      if (raw is String && raw.isNotEmpty) return raw;
      if (raw is int && raw >= 0 && raw < enumNames.length) {
        return enumNames[raw];
      }
      return enumNames[fallback];
    }

    final statusNames = ['pending', 'completed', 'failed', 'refunded'];
    final typeNames = [
      'jobPayment',
      'connectPurchase',
      'withdrawal',
      'refund',
      'bonus',
    ];

    return Payment(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      method: _parseString(map['method'], [
        'wallet',
        'card',
        'bkash',
        'nagad',
      ], 0),
      status: _parseString(map['status'], statusNames, 0),
      type: _parseString(map['type'], typeNames, 0),
      jobId: map['jobId'],
      freelancerId: map['freelancerId'],
      note: map['note'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'amount': amount,
    'method': method,
    'status': status,
    'type': type,
    'jobId': jobId,
    'freelancerId': freelancerId,
    'note': note,
    'createdAt': Timestamp.fromDate(createdAt),
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
  };
}

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user's wallet balance
  Future<double> getWalletBalance(String userId) async {
    try {
      final doc = await _db.collection('wallets').doc(userId).get();
      return (doc.data()?['balance'] ?? 0).toDouble();
    } catch (e) {
      throw Exception('Failed to get wallet balance: $e');
    }
  }

  /// Purchase connects with wallet or payment method
  Future<void> purchaseConnects({
    required int connectCount,
    required double amount,
    required PaymentMethod method,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final batch = _db.batch();

    try {
      // Create payment record (schema-compliant: strings for status/type/method)
      final paymentRef = _db.collection('payments').doc();
      batch.set(paymentRef, {
        'userId': uid,
        'amount': amount,
        'method': 'wallet',
        'status': 'pending',
        'type': 'connectPurchase',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user connects
      final userRef = _db.collection('users').doc(uid);
      batch.update(userRef, {
        'totalConnects': FieldValue.increment(connectCount),
      });

      // Update wallet balance
      final walletRef = _db.collection('wallets').doc(uid);
      batch.set(walletRef, {
        'balance': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to purchase connects: $e');
    }
  }

  /// Process job payment (client pays freelancer)
  Future<void> processJobPayment({
    required String jobId,
    required String freelancerId,
    required double amount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final batch = _db.batch();

    try {
      // Create payment record (schema-compliant strings)
      final paymentRef = _db.collection('payments').doc();
      batch.set(paymentRef, {
        'userId': uid,
        'freelancerId': freelancerId,
        'jobId': jobId,
        'amount': amount,
        'method': 'wallet',
        'status': 'completed',
        'type': 'jobPayment',
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Deduct from client wallet
      final clientWalletRef = _db.collection('wallets').doc(uid);
      batch.set(clientWalletRef, {
        'balance': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update client's convenience field on users doc
      batch.set(_db.collection('users').doc(uid), {
        'walletBalance': FieldValue.increment(-amount),
      }, SetOptions(merge: true));

      // Add to freelancer wallet
      final freelancerWalletRef = _db.collection('wallets').doc(freelancerId);
      batch.set(freelancerWalletRef, {
        'balance': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update freelancer's convenience field on users doc
      batch.set(_db.collection('users').doc(freelancerId), {
        'walletBalance': FieldValue.increment(amount),
        'totalEarnings': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      // Update freelancer earnings
      // totalEarnings already incremented via users doc above (merge); keep for backwards compatibility
      // ensure field exists
      batch.set(_db.collection('users').doc(freelancerId), {
        'totalEarnings': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      // Update job status
      batch.update(_db.collection('jobs').doc(jobId), {
        'paymentStatus': 'completed',
        'paidAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Notify freelancer and client about the payment
      try {
        final jobDoc = await _db.collection('jobs').doc(jobId).get();
        final jobTitle = jobDoc.data()?['title'] as String? ?? 'your job';
        // Notify freelancer
        await NotificationService().notifyPaymentReceived(
          userId: freelancerId,
          amount: amount,
          jobTitle: jobTitle,
        );

        // Notify client (payment sent)
        await NotificationService().sendNotification(
          userId: uid,
          type: NotificationType.paymentSent,
          title: 'Payment Sent',
          message: 'You paid ৳$amount for "$jobTitle"',
          actionUrl: '/job/$jobId',
          relatedJobId: jobId,
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to process job payment: $e');
    }
  }

  /// Process withdrawal request
  Future<void> requestWithdrawal({
    required double amount,
    required String bankAccount,
    required String bankName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      // Check sufficient balance
      final balance = await getWalletBalance(uid);
      if (balance < amount) throw Exception('Insufficient balance');

      // Create withdrawal request
      await _db.collection('withdrawals').add({
        'userId': uid,
        'amount': amount,
        'bankAccount': bankAccount,
        'bankName': bankName,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'processedAt': null,
      });

      // Deduct from wallet
      await _db.collection('wallets').doc(uid).set({
        'balance': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to request withdrawal: $e');
    }
  }

  /// Get payment history
  Stream<List<Payment>> getPaymentHistory({int limit = 50}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('payments')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Payment.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Convenience stream for UI
  Stream<List<Payment>> getPaymentHistoryStream() {
    return getPaymentHistory();
  }

  /// Get withdrawal history
  Stream<List<Map<String, dynamic>>> getWithdrawalHistory({int limit = 50}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('withdrawals')
        .where('userId', isEqualTo: uid)
        .orderBy('requestedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  /// Add bonus to user wallet
  Future<void> addBonus({
    required String userId,
    required double amount,
  }) async {
    try {
      final batch = _db.batch();

      // Create transaction record (schema-compliant strings)
      final txnRef = _db.collection('payments').doc();
      batch.set(txnRef, {
        'userId': userId,
        'amount': amount,
        'method': 'wallet',
        'status': 'completed',
        'type': 'bonus',
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Add to wallet
      final walletRef = _db.collection('wallets').doc(userId);
      batch.set(walletRef, {
        'balance': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add bonus: $e');
    }
  }

  /// Get transaction details
  Future<Payment?> getTransaction(String paymentId) async {
    try {
      final doc = await _db.collection('payments').doc(paymentId).get();
      if (!doc.exists) return null;
      return Payment.fromMap(doc.data()!, paymentId);
    } catch (e) {
      throw Exception('Failed to get transaction: $e');
    }
  }

  /// Finalize an existing pending payment (created as a pending invoice)
  Future<void> finalizePendingPayment(String paymentId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final paymentRef = _db.collection('payments').doc(paymentId);

    try {
      final paymentSnap = await paymentRef.get();
      if (!paymentSnap.exists) throw Exception('Payment not found');
      final data = paymentSnap.data() ?? {};

      final owner = data['userId'] as String? ?? '';
      if (owner != uid)
        throw Exception('Not authorized to finalize this payment');

      final statusVal = data['status'];
      // status stored as string in schema
      final statusStr = statusVal is String
          ? statusVal.toLowerCase()
          : (statusVal is int
                ? ['pending', 'completed', 'failed', 'refunded'][statusVal
                      .clamp(0, 3)]
                : 'pending');
      if (statusStr != 'pending') throw Exception('Payment is not pending');

      final freelancerId = data['freelancerId'] as String? ?? '';
      final jobId = data['jobId'] as String? ?? '';
      final amount = (data['amount'] ?? 0).toDouble();

      // Check balance
      final balance = await getWalletBalance(uid);
      if (balance < amount) throw Exception('Insufficient wallet balance');

      final batch = _db.batch();

      // Update payment doc to completed (string status)
      batch.update(paymentRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Deduct from client wallet
      final clientWalletRef = _db.collection('wallets').doc(uid);
      batch.set(clientWalletRef, {
        'balance': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add to freelancer wallet
      final freelancerWalletRef = _db.collection('wallets').doc(freelancerId);
      batch.set(freelancerWalletRef, {
        'balance': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update convenience fields on users docs to keep UI fast
      batch.set(_db.collection('users').doc(uid), {
        'walletBalance': FieldValue.increment(-amount),
      }, SetOptions(merge: true));

      batch.set(_db.collection('users').doc(freelancerId), {
        'walletBalance': FieldValue.increment(amount),
        'totalEarnings': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      // Update freelancer earnings
      // Already handled via set with merge above

      // Update job status/payment
      if (jobId.isNotEmpty) {
        batch.update(_db.collection('jobs').doc(jobId), {
          'paymentStatus': 'completed',
          'paidAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Send notifications
      try {
        String jobTitle = 'job';
        if (jobId.isNotEmpty) {
          final jobDoc = await _db.collection('jobs').doc(jobId).get();
          jobTitle = (jobDoc.data()?['title'] as String?) ?? 'your job';
        }

        await NotificationService().notifyPaymentReceived(
          userId: freelancerId,
          amount: amount,
          jobTitle: jobTitle,
        );

        await NotificationService().sendNotification(
          userId: uid,
          type: NotificationType.paymentSent,
          title: 'Payment Sent',
          message: 'You released ৳$amount for "$jobTitle"',
          actionUrl: '/job/$jobId',
          relatedJobId: jobId,
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to finalize pending payment: $e');
    }
  }

  /// Demo top-up: add funds to user's wallet (simulated payment)
  Future<void> topUpBalance({required double amount}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final batch = _db.batch();

      final paymentRef = _db.collection('payments').doc();
      batch.set(paymentRef, {
        'userId': uid,
        'amount': amount,
        'method': 'card',
        'status': 'completed',
        'type': 'bonus',
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'note': 'topup_demo',
      });

      final walletRef = _db.collection('wallets').doc(uid);
      batch.set(walletRef, {
        'balance': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // keep a convenience field on users doc for quick UI access
      final userRef = _db.collection('users').doc(uid);
      batch.set(userRef, {
        'walletBalance': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      await batch.commit();

      try {
        await NotificationService().sendNotification(
          userId: uid,
          type: NotificationType.paymentReceived,
          title: 'Wallet topped up',
          message: 'Your wallet was topped up by ৳$amount',
          actionUrl: '/wallet',
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to top up balance: $e');
    }
  }
}
