// lib/services/payment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PaymentMethod { wallet, card, bkash, nagad }

enum PaymentStatus { pending, completed, failed, refunded }

enum TransactionType { jobPayment, connectPurchase, withdrawal, refund, bonus }

class Payment {
  final String id;
  final String userId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final TransactionType type;
  final String? jobId;
  final String? freelancerId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;
  final String? transactionRef;
  final String? failureReason;

  Payment({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    required this.type,
    this.jobId,
    this.freelancerId,
    required this.createdAt,
    this.completedAt,
    this.metadata,
    this.transactionRef,
    this.failureReason,
  });

  factory Payment.fromMap(Map<String, dynamic> map, String id) {
    return Payment(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      method: PaymentMethod.values[map['method'] ?? 0],
      status: PaymentStatus.values[map['status'] ?? 0],
      type: TransactionType.values[map['type'] ?? 0],
      jobId: map['jobId'],
      freelancerId: map['freelancerId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      metadata: map['metadata'],
      transactionRef: map['transactionRef'],
      failureReason: map['failureReason'],
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'amount': amount,
    'method': method.index,
    'status': status.index,
    'type': type.index,
    'jobId': jobId,
    'freelancerId': freelancerId,
    'createdAt': Timestamp.fromDate(createdAt),
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
    'metadata': metadata,
    'transactionRef': transactionRef,
    'failureReason': failureReason,
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
      // Create payment record
      final paymentRef = _db.collection('payments').doc();
      batch.set(paymentRef, {
        'userId': uid,
        'amount': amount,
        'method': method.index,
        'status': PaymentStatus.pending.index,
        'type': TransactionType.connectPurchase.index,
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
      // Create payment record
      final paymentRef = _db.collection('payments').doc();
      batch.set(paymentRef, {
        'userId': uid,
        'freelancerId': freelancerId,
        'jobId': jobId,
        'amount': amount,
        'method': PaymentMethod.wallet.index,
        'status': PaymentStatus.completed.index,
        'type': TransactionType.jobPayment.index,
        'createdAt': FieldValue.serverTimestamp(),
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

      // Update freelancer earnings
      batch.update(_db.collection('users').doc(freelancerId), {
        'totalEarnings': FieldValue.increment(amount),
      });

      // Update job status
      batch.update(_db.collection('jobs').doc(jobId), {
        'paymentStatus': 'completed',
        'paidAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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

      // Create transaction record
      final txnRef = _db.collection('payments').doc();
      batch.set(txnRef, {
        'userId': userId,
        'amount': amount,
        'method': PaymentMethod.wallet.index,
        'status': PaymentStatus.completed.index,
        'type': TransactionType.bonus.index,
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
}
