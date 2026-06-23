// lib/services/job_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      final batch = _db.batch();

      // Update job status
      batch.update(_db.collection('jobs').doc(jobId), {
        'status': JobStatus.ongoing.index,
        'freelancerId': freelancerId,
        'startedAt': FieldValue.serverTimestamp(),
        'estimatedCompletion': Timestamp.fromDate(estimatedCompletion),
      });

      // Create contract record
      final contractRef = _db.collection('contracts').doc();
      batch.set(contractRef, {
        'jobId': jobId,
        'clientId': uid,
        'freelancerId': freelancerId,
        'status': ContractStatus.active.index,
        'startedAt': FieldValue.serverTimestamp(),
        'estimatedCompletion': Timestamp.fromDate(estimatedCompletion),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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

      // Update job status
      batch.update(_db.collection('jobs').doc(jobId), {
        'status': JobStatus.completed.index,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update contract status
      batch.update(_db.collection('contracts').doc(contractId), {
        'status': ContractStatus.completed.index,
        'completedAt': FieldValue.serverTimestamp(),
        'feedback': feedback,
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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
      await _db.collection('jobs').doc(jobId).update({
        'status': JobStatus.cancelled.index,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'cancelledBy': uid,
      });
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

      batch.update(_db.collection('jobs').doc(jobId), {
        'status': JobStatus.onHold.index,
      });

      batch.update(_db.collection('contracts').doc(contractId), {
        'status': ContractStatus.paused.index,
        'pausedAt': FieldValue.serverTimestamp(),
        'pauseReason': reason,
      });

      await batch.commit();
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

      batch.update(_db.collection('jobs').doc(jobId), {
        'status': JobStatus.ongoing.index,
      });

      batch.update(_db.collection('contracts').doc(contractId), {
        'status': ContractStatus.active.index,
        'resumedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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
          // Filter by status and sort in code
          contracts.removeWhere(
            (c) => c['status'] != ContractStatus.active.index,
          );
          contracts.sort(
            (a, b) =>
                (b['startedAt'] as Timestamp?)?.compareTo(
                  a['startedAt'] as Timestamp? ?? Timestamp.now(),
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
          // Filter by status and sort in code
          contracts.removeWhere(
            (c) => c['status'] != ContractStatus.active.index,
          );
          contracts.sort(
            (a, b) =>
                (b['startedAt'] as Timestamp?)?.compareTo(
                  a['startedAt'] as Timestamp? ?? Timestamp.now(),
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

      // TODO: Process payment to freelancer
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
