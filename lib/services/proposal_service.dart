// lib/services/proposal_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ProposalStatus { pending, approved, rejected, withdrawn, completed }

class Proposal {
  final String id;
  final String jobId;
  final String freelancerId;
  final String clientId;
  final String coverLetter;
  final double bidAmount;
  final int deliveryDays;
  final ProposalStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? rejectionReason;

  Proposal({
    required this.id,
    required this.jobId,
    required this.freelancerId,
    required this.clientId,
    required this.coverLetter,
    required this.bidAmount,
    required this.deliveryDays,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.rejectionReason,
  });

  factory Proposal.fromMap(Map<String, dynamic> data, String docId) {
    return Proposal(
      id: docId,
      jobId: data['jobId'] ?? '',
      freelancerId: data['freelancerId'] ?? '',
      clientId: data['clientId'] ?? '',
      coverLetter: data['coverLetter'] ?? '',
      bidAmount: (data['bidAmount'] ?? 0).toDouble(),
      deliveryDays: data['deliveryDays'] ?? 0,
      status: ProposalStatus.values[data['status'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() => {
    'jobId': jobId,
    'freelancerId': freelancerId,
    'clientId': clientId,
    'coverLetter': coverLetter,
    'bidAmount': bidAmount,
    'deliveryDays': deliveryDays,
    'status': status.index,
    'createdAt': Timestamp.fromDate(createdAt),
    'respondedAt': respondedAt != null
        ? Timestamp.fromDate(respondedAt!)
        : null,
    'rejectionReason': rejectionReason,
  };
}

class ProposalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a new proposal for a job
  Future<void> submitProposal({
    required String jobId,
    required String coverLetter,
    required double bidAmount,
    required int deliveryDays,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      // Get job details to extract clientId
      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      if (!jobDoc.exists) throw Exception('Job not found');

      final jobData = jobDoc.data()!;
      final clientId = jobData['clientId'] as String;

      // Create proposal
      await _db.collection('proposals').add({
        'jobId': jobId,
        'freelancerId': uid,
        'clientId': clientId,
        'coverLetter': coverLetter,
        'bidAmount': bidAmount,
        'deliveryDays': deliveryDays,
        'status': ProposalStatus.pending.index,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add freelancer to job applicants
      await _db.collection('jobs').doc(jobId).update({
        'applicants': FieldValue.arrayUnion([uid]),
        'applicantCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to submit proposal: $e');
    }
  }

  /// Get all proposals for current freelancer
  Stream<List<Proposal>> getFreelancerProposals() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('proposals')
        .where('freelancerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Proposal.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get all proposals for a specific job (for client)
  Stream<List<Proposal>> getJobProposals(String jobId) {
    return _db
        .collection('proposals')
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Proposal.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Approve a proposal and start the job
  Future<void> approveProposal({
    required String proposalId,
    required String jobId,
    required DateTime estimatedCompletion,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final batch = _db.batch();

      // Get proposal details
      final proposalDoc = await _db
          .collection('proposals')
          .doc(proposalId)
          .get();
      final proposalData = proposalDoc.data()!;
      final freelancerId = proposalData['freelancerId'] as String;

      // Update proposal status
      batch.update(_db.collection('proposals').doc(proposalId), {
        'status': ProposalStatus.approved.index,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Update job status
      batch.update(_db.collection('jobs').doc(jobId), {
        'status': 1, // ongoing
        'freelancerId': freelancerId,
        'selectedProposalId': proposalId,
        'startedAt': FieldValue.serverTimestamp(),
        'estimatedCompletion': Timestamp.fromDate(estimatedCompletion),
      });

      // Create contract
      final contractRef = _db.collection('contracts').doc();
      batch.set(contractRef, {
        'jobId': jobId,
        'proposalId': proposalId,
        'clientId': uid,
        'freelancerId': freelancerId,
        'status': 0, // active
        'bidAmount': proposalData['bidAmount'],
        'deliveryDays': proposalData['deliveryDays'],
        'startedAt': FieldValue.serverTimestamp(),
        'estimatedCompletion': Timestamp.fromDate(estimatedCompletion),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reject all other proposals for this job
      final otherProposals = await _db
          .collection('proposals')
          .where('jobId', isEqualTo: jobId)
          .where('status', isEqualTo: ProposalStatus.pending.index)
          .get();

      for (final doc in otherProposals.docs) {
        if (doc.id != proposalId) {
          batch.update(doc.reference, {
            'status': ProposalStatus.rejected.index,
            'respondedAt': FieldValue.serverTimestamp(),
            'rejectionReason': 'Another proposal was selected',
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to approve proposal: $e');
    }
  }

  /// Reject a proposal
  Future<void> rejectProposal({
    required String proposalId,
    required String reason,
  }) async {
    try {
      await _db.collection('proposals').doc(proposalId).update({
        'status': ProposalStatus.rejected.index,
        'respondedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });
    } catch (e) {
      throw Exception('Failed to reject proposal: $e');
    }
  }

  /// Withdraw a proposal (freelancer only)
  Future<void> withdrawProposal(String proposalId) async {
    try {
      await _db.collection('proposals').doc(proposalId).update({
        'status': ProposalStatus.withdrawn.index,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to withdraw proposal: $e');
    }
  }

  /// Get proposal details with job info
  Future<Map<String, dynamic>> getProposalWithJob(String proposalId) async {
    try {
      final proposalDoc = await _db
          .collection('proposals')
          .doc(proposalId)
          .get();
      if (!proposalDoc.exists) throw Exception('Proposal not found');

      final proposalData = proposalDoc.data()!;
      final jobDoc = await _db
          .collection('jobs')
          .doc(proposalData['jobId'])
          .get();

      return {
        'proposal': Proposal.fromMap(proposalData, proposalDoc.id),
        'job': jobDoc.data(),
      };
    } catch (e) {
      throw Exception('Failed to fetch proposal details: $e');
    }
  }

  /// Check if freelancer has already proposed for this job
  Future<bool> hasProposed(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final result = await _db
          .collection('proposals')
          .where('jobId', isEqualTo: jobId)
          .where('freelancerId', isEqualTo: uid)
          .limit(1)
          .get();

      return result.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
