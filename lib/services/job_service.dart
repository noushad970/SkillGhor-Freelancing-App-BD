// lib/services/job_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'payment_service.dart';

enum JobStatus { open, ongoing, completed, cancelled, onHold }

enum ContractStatus { active, completed, cancelled, paused }

class JobService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Start a job (approve contract)
  Future<void> startJob({
    required String jobId,
    required String freelancerId,
    required DateTime estimatedCompletion,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      // Fetch job title first
      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      final jobTitle = jobDoc.data()?['title'] as String? ?? '';

      final batch = _db.batch();

      // Update job status (use string to match schema)
      batch.update(_db.collection('jobs').doc(jobId), {
        'status': 'ongoing',
        'freelancerId': freelancerId,
      });

      // Create contract record matching schema exactly
      final contractRef = _db.collection('contracts').doc();
      batch.set(contractRef, {
        'jobId': jobId,
        'jobTitle': jobTitle,
        'clientId': uid,
        'freelancerId': freelancerId,
        'status': 'active',
        'completedByClient': false,
        'completionReviewedAt': null,
        'reviewed': false,
        'reviewedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      try {
        await NotificationService().notifyJobStarted(
          jobId: jobId,
          jobTitle: jobTitle,
          clientId: uid,
          freelancerId: freelancerId,
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to start job: $e');
    }
  }

  /// Complete a job
  Future<void> completeJob({
    required String jobId,
    required String contractId,
    String? feedback,
    double? rating,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final batch = _db.batch();

      // Update job status (string matches schema)
      batch.update(_db.collection('jobs').doc(jobId), {'status': 'completed'});

      // Update contract status (string matches schema)
      batch.update(_db.collection('contracts').doc(contractId), {
        'status': 'completed',
        'completedByClient': true,
        'completionReviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      try {
        // Notify both parties about job completion
        final jobDoc = await _db.collection('jobs').doc(jobId).get();
        final jobTitle = jobDoc.data()?['title'] as String? ?? 'your job';
        final contractDoc = await _db
            .collection('contracts')
            .doc(contractId)
            .get();
        final clientId = contractDoc.data()?['clientId'] as String? ?? '';
        final freelancerId =
            contractDoc.data()?['freelancerId'] as String? ?? '';
        if (clientId.isNotEmpty && freelancerId.isNotEmpty) {
          await NotificationService().notifyContractCompleted(
            jobId: jobId,
            jobTitle: jobTitle,
            clientId: clientId,
            freelancerId: freelancerId,
          );
        }
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to complete job: $e');
    }
  }

  /// Cancel a job
  Future<void> cancelJob({
    required String jobId,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      await _db.collection('jobs').doc(jobId).update({'status': 'cancelled'});
      try {
        final jobDoc = await _db.collection('jobs').doc(jobId).get();
        final jobTitle = jobDoc.data()?['title'] as String? ?? 'your job';
        // notify job participants - simplistic: notify owner
        await NotificationService().sendNotification(
          userId: jobDoc.data()?['clientId'] ?? uid,
          type: NotificationType.jobClosed,
          title: 'Job cancelled',
          message: 'Job "$jobTitle" was cancelled',
          actionUrl: '/job/$jobId',
          relatedJobId: jobId,
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to cancel job: $e');
    }
  }

  /// Pause a job
  Future<void> pauseJob({
    required String jobId,
    required String contractId,
    required String reason,
  }) async {
    try {
      final batch = _db.batch();

      batch.update(_db.collection('jobs').doc(jobId), {'status': 'onHold'});

      batch.update(_db.collection('contracts').doc(contractId), {
        'status': 'paused',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      try {
        final contractDoc = await _db
            .collection('contracts')
            .doc(contractId)
            .get();
        final clientId = contractDoc.data()?['clientId'] as String? ?? '';
        final freelancerId =
            contractDoc.data()?['freelancerId'] as String? ?? '';
        final jobDoc = await _db.collection('jobs').doc(jobId).get();
        final jobTitle = jobDoc.data()?['title'] as String? ?? 'your job';
        if (clientId.isNotEmpty && freelancerId.isNotEmpty) {
          await NotificationService().sendNotification(
            userId: freelancerId,
            type: NotificationType.messageReceived,
            title: 'Job paused',
            message: 'Job "$jobTitle" was paused',
            actionUrl: '/job/$jobId',
            relatedJobId: jobId,
          );
        }
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to pause job: $e');
    }
  }

  /// Resume a paused job
  Future<void> resumeJob({
    required String jobId,
    required String contractId,
  }) async {
    try {
      final batch = _db.batch();

      batch.update(_db.collection('jobs').doc(jobId), {'status': 'ongoing'});

      batch.update(_db.collection('contracts').doc(contractId), {
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      try {
        final contractDoc = await _db
            .collection('contracts')
            .doc(contractId)
            .get();
        final clientId = contractDoc.data()?['clientId'] as String? ?? '';
        final freelancerId =
            contractDoc.data()?['freelancerId'] as String? ?? '';
        final jobDoc = await _db.collection('jobs').doc(jobId).get();
        final jobTitle = jobDoc.data()?['title'] as String? ?? 'your job';
        if (clientId.isNotEmpty && freelancerId.isNotEmpty) {
          await NotificationService().sendNotification(
            userId: freelancerId,
            type: NotificationType.jobStarted,
            title: 'Job resumed',
            message: 'Job "$jobTitle" was resumed',
            actionUrl: '/job/$jobId',
            relatedJobId: jobId,
          );
        }
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to resume job: $e');
    }
  }

  /// Get contract details
  Future<Map<String, dynamic>?> getContractDetails(String contractId) async {
    try {
      final doc = await _db.collection('contracts').doc(contractId).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get contract details: $e');
    }
  }

  /// Stream active contracts for client
  Stream<List<Map<String, dynamic>>> getClientActiveContracts() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('contracts')
        .where('clientId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final contracts = snap.docs.map((doc) => doc.data()).toList();
          // Filter by string status to match schema
          contracts.removeWhere((c) {
            final s = (c['status'] ?? '').toString().toLowerCase();
            return s != 'active' && s != 'ongoing' && s != 'in_progress';
          });
          contracts.sort(
            (a, b) =>
                (b['createdAt'] as Timestamp?)?.compareTo(
                  a['createdAt'] as Timestamp? ?? Timestamp.now(),
                ) ??
                0,
          );
          return contracts;
        });
  }

  /// Stream active contracts for freelancer
  Stream<List<Map<String, dynamic>>> getFreelancerActiveContracts() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('contracts')
        .where('freelancerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final contracts = snap.docs.map((doc) => doc.data()).toList();
          // Filter by string status to match schema
          contracts.removeWhere((c) {
            final s = (c['status'] ?? '').toString().toLowerCase();
            return s != 'active' && s != 'ongoing' && s != 'in_progress';
          });
          contracts.sort(
            (a, b) =>
                (b['createdAt'] as Timestamp?)?.compareTo(
                  a['createdAt'] as Timestamp? ?? Timestamp.now(),
                ) ??
                0,
          );
          return contracts;
        });
  }

  /// Get contract completion percentage
  Future<double> getContractProgress(String contractId) async {
    try {
      final doc = await _db.collection('contracts').doc(contractId).get();
      final data = doc.data();
      if (data == null) return 0;

      final progress = (data['progress'] ?? 0).toDouble();
      return progress.clamp(0, 100);
    } catch (e) {
      return 0;
    }
  }

  /// Update contract progress
  Future<void> updateContractProgress({
    required String contractId,
    required double progress,
  }) async {
    try {
      await _db.collection('contracts').doc(contractId).update({
        'progress': progress.clamp(0, 100),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update progress: $e');
    }
  }

  /// Add milestone to contract
  Future<void> addMilestone({
    required String contractId,
    required String description,
    required double amount,
    required DateTime dueDate,
  }) async {
    try {
      await _db.collection('contracts').doc(contractId).update({
        'milestones': FieldValue.arrayUnion([
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'description': description,
            'amount': amount,
            'dueDate': Timestamp.fromDate(dueDate),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          },
        ]),
      });
    } catch (e) {
      throw Exception('Failed to add milestone: $e');
    }
  }

  /// Release milestone payment
  Future<void> releaseMilestonePayment({
    required String contractId,
    required String milestoneId,
  }) async {
    try {
      final contractDoc = await _db
          .collection('contracts')
          .doc(contractId)
          .get();
      final milestones = contractDoc.data()?['milestones'] as List? ?? [];

      final milestone = milestones.firstWhere(
        (m) => m['id'] == milestoneId,
        orElse: () => null,
      );

      if (milestone == null) throw Exception('Milestone not found');

      // Update milestone status
      await _db.collection('contracts').doc(contractId).update({
        'milestones': milestones
            .map(
              (m) => m['id'] == milestoneId ? {...m, 'status': 'released'} : m,
            )
            .toList(),
      });

      try {
        final contractData = contractDoc.data() ?? {};
        final freelancerId = contractData['freelancerId'] as String? ?? '';
        final jobId = contractData['jobId'] as String? ?? '';
        final amount = (milestone['amount'] as num?)?.toDouble() ?? 0.0;
        if (freelancerId.isNotEmpty && amount > 0) {
          final paymentService = PaymentService();
          await paymentService.processJobPayment(
            jobId: jobId,
            freelancerId: freelancerId,
            amount: amount,
          );
        }

        // Notify parties about milestone release
        final jobDoc = await _db.collection('jobs').doc(jobId).get();
        final jobTitle = jobDoc.data()?['title'] as String? ?? 'your job';
        if (freelancerId.isNotEmpty) {
          await NotificationService().notifyPaymentReceived(
            userId: freelancerId,
            amount: amount,
            jobTitle: jobTitle,
          );
        }
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to release payment: $e');
    }
  }

  /// Add timeline update
  Future<void> addTimelineUpdate({
    required String contractId,
    required String description,
    String? attachmentUrl,
  }) async {
    try {
      await _db.collection('contracts').doc(contractId).update({
        'timeline': FieldValue.arrayUnion([
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'description': description,
            'attachmentUrl': attachmentUrl,
            'createdAt': FieldValue.serverTimestamp(),
          },
        ]),
      });
    } catch (e) {
      throw Exception('Failed to add timeline update: $e');
    }
  }
}
