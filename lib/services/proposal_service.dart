// lib/services/proposal_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'notification_service.dart';

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

  factory Proposal.fromMap(
    Map<String, dynamic> data,
    String docId, {
    String? parentJobId,
  }) {
    // parse status robustly (can be stored as int index or string)
    ProposalStatus status = ProposalStatus.pending;
    final rawStatus = data['status'];
    if (rawStatus is int) {
      int idx = rawStatus;
      if (idx < 0) idx = 0;
      if (idx >= ProposalStatus.values.length)
        idx = ProposalStatus.values.length - 1;
      status = ProposalStatus.values[idx];
    } else if (rawStatus is String) {
      final key = rawStatus.toLowerCase();
      status = ProposalStatus.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == key,
        orElse: () => ProposalStatus.pending,
      );
    }

    // parse bidAmount (could be int, double, string) - support alternate field names
    double bidAmount = 0.0;
    final rawBidCandidates = [
      data['bidAmount'],
      data['budget'],
      data['amount'],
      data['price'],
    ];
    for (final rawBid in rawBidCandidates) {
      if (rawBid == null) continue;
      if (rawBid is num) {
        bidAmount = rawBid.toDouble();
        break;
      } else if (rawBid is String) {
        final parsed = double.tryParse(rawBid);
        if (parsed != null) {
          bidAmount = parsed;
          break;
        }
      }
    }

    // parse deliveryDays - support alternate names
    int deliveryDays = 0;
    final rawDaysCandidates = [
      data['deliveryDays'],
      data['delivery'],
      data['delivery_days'],
    ];
    for (final rawDays in rawDaysCandidates) {
      if (rawDays == null) continue;
      if (rawDays is int) {
        deliveryDays = rawDays;
        break;
      } else if (rawDays is num) {
        deliveryDays = rawDays.toInt();
        break;
      } else if (rawDays is String) {
        deliveryDays = int.tryParse(rawDays) ?? 0;
        break;
      }
    }

    // parse createdAt (Timestamp, int millis, ISO string, or alternate key)
    DateTime createdAt = DateTime.now();
    final createdCandidates = [
      data['createdAt'],
      data['created'],
      data['created_on'],
    ];
    for (final rawCreated in createdCandidates) {
      if (rawCreated == null) continue;
      if (rawCreated is Timestamp) {
        createdAt = rawCreated.toDate();
        break;
      } else if (rawCreated is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
        break;
      } else if (rawCreated is String) {
        createdAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
        break;
      }
    }

    // parse respondedAt
    DateTime? respondedAt;
    final rawResponded = data['respondedAt'] ?? data['responded_at'];
    if (rawResponded is Timestamp)
      respondedAt = rawResponded.toDate();
    else if (rawResponded is int)
      respondedAt = DateTime.fromMillisecondsSinceEpoch(rawResponded);
    else if (rawResponded is String)
      respondedAt = DateTime.tryParse(rawResponded);

    final jobId = (data['jobId'] ?? parentJobId) ?? '';

    return Proposal(
      id: docId,
      jobId: jobId,
      freelancerId: data['freelancerId'] ?? data['freelancer'] ?? '',
      clientId: data['clientId'] ?? data['client'] ?? '',
      coverLetter: data['coverLetter'] ?? data['description'] ?? '',
      bidAmount: bidAmount,
      deliveryDays: deliveryDays,
      status: status,
      createdAt: createdAt,
      respondedAt: respondedAt,
      rejectionReason: data['rejectionReason'] ?? data['rejection_reason'],
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
      // Get job details
      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      if (!jobDoc.exists) throw Exception('Job not found');

      final jobData = jobDoc.data()!;

      // Get freelancer info for notification and proposal doc
      final freelancerDoc = await _db.collection('users').doc(uid).get();
      final freelancerData = freelancerDoc.data() ?? {};
      final freelancerName = freelancerData['name'] ?? 'Freelancer';
      final freelancerPhotoUrl = freelancerData['photoUrl'];

      // Write proposal under jobs/{jobId}/proposals/{uid} (schema-compliant)
      // Field names match your schema exactly:
      // description, budget, estimatedDate, freelancerId, freelancerName,
      // freelancerPhotoUrl, portfolio, status, boostConnects, totalConnectsSpent
      final proposalRef = _db
          .collection('jobs')
          .doc(jobId)
          .collection('proposals')
          .doc(uid);

      final existingProposal = await proposalRef.get();
      if (existingProposal.exists) {
        throw Exception('You have already submitted a proposal for this job');
      }

      await proposalRef.set({
        'freelancerId': uid,
        'freelancerName': freelancerName,
        'freelancerPhotoUrl': freelancerPhotoUrl,
        'description': coverLetter, // schema field name
        'budget': bidAmount, // schema field name
        'estimatedDate': deliveryDays.toString(), // schema field name
        'portfolio': '',
        'boostConnects': 0,
        'totalConnectsSpent': 1,
        'status': 'pending', // schema stores as string
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add freelancer to job applicants and increment proposalsCount
      await _db.collection('jobs').doc(jobId).update({
        'applicants': FieldValue.arrayUnion([uid]),
        'proposalsCount': FieldValue.increment(1),
      });

      // Notify client about the new proposal
      try {
        await NotificationService().notifyProposalReceived(
          jobId: jobId,
          jobTitle: jobData['title'] ?? 'Your job',
          freelancerName: freelancerName,
          clientId: jobData['clientId'] as String,
        );
      } catch (_) {
        // Notification failure shouldn't break proposal submission
      }
    } catch (e) {
      throw Exception('Failed to submit proposal: $e');
    }
  }

  /// Get all proposals for current freelancer
  Stream<List<Proposal>> getFreelancerProposals() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    final controller = StreamController<List<Proposal>>();
    final subs = <StreamSubscription>[];

    // latest maps to hold data from various sources
    // Use a composite key to avoid collisions when the same document id appears in
    // different collections/subcollections (e.g. doc id == freelancerId)
    final Map<String, Proposal> byId = {};

    void emit() {
      final list = byId.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(list);
    }

    // Helper to merge a list of proposals into byId and emit
    void mergeAndEmitWithKey(List<Proposal> list, List<String> keys) {
      for (var i = 0; i < list.length; i++) {
        final key = keys.length > i ? keys[i] : list[i].id;
        final p = list[i];
        if (!byId.containsKey(key) ||
            byId[key]!.createdAt.isBefore(p.createdAt)) {
          byId[key] = p;
        }
      }
      emit();
    }

    // helper to build a stable key for a document snapshot
    String _makeKeyFromSnapshot(QueryDocumentSnapshot d) {
      final parentJobId = d.reference.parent.parent?.id;
      final data = d.data() as Map<String, dynamic>?;
      final jobIdFromData = data != null
          ? (data['jobId'] as String? ?? '')
          : '';
      final chosenJobId =
          parentJobId ?? (jobIdFromData.isNotEmpty ? jobIdFromData : null);
      return '${chosenJobId ?? 'top'}__${d.id}';
    }

    // 1) collectionGroup listener (preferred)
    try {
      final cgSub = _db
          .collectionGroup('proposals')
          .where('freelancerId', isEqualTo: uid)
          .snapshots()
          .listen(
            (snap) {
              final list = <Proposal>[];
              final keys = <String>[];
              for (final d in snap.docs) {
                final data = d.data() as Map<String, dynamic>? ?? {};
                final parentJobId = d.reference.parent.parent?.id;
                list.add(
                  Proposal.fromMap(data, d.id, parentJobId: parentJobId),
                );
                keys.add(_makeKeyFromSnapshot(d));
              }
              // replace existing entries from collectionGroup using composite keys
              mergeAndEmitWithKey(list, keys);
            },
            onError: (e) {
              // ignore errors, fallback will cover
            },
          );
      subs.add(cgSub);
    } catch (_) {}

    // 2) top-level proposals collection
    try {
      final topSub = _db
          .collection('proposals')
          .where('freelancerId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            final list = <Proposal>[];
            final keys = <String>[];
            for (final d in snap.docs) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              list.add(Proposal.fromMap(data, d.id));
              // use jobId from data if present for uniqueness
              final jobIdFromData = data['jobId'] as String?;
              final key = '${jobIdFromData ?? 'top'}__${d.id}';
              keys.add(key);
            }
            mergeAndEmitWithKey(list, keys);
          }, onError: (e) {});
      subs.add(topSub);
    } catch (_) {}

    // 3) jobs where applicant contains uid -> listen and subscribe to their proposals subcollections
    final Map<String, StreamSubscription> jobProposalSubs = {};

    void subscribeToJobProposals(DocumentSnapshot jobDoc) {
      final jobId = jobDoc.id;
      if (jobProposalSubs.containsKey(jobId)) return;
      try {
        final s = jobDoc.reference
            .collection('proposals')
            .where('freelancerId', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
              final list = <Proposal>[];
              final keys = <String>[];
              for (final d in snap.docs) {
                final data = d.data() as Map<String, dynamic>? ?? {};
                list.add(Proposal.fromMap(data, d.id, parentJobId: jobId));
                keys.add('${jobId}__${d.id}');
              }
              mergeAndEmitWithKey(list, keys);
            }, onError: (e) {});
        jobProposalSubs[jobId] = s;
        subs.add(s);
      } catch (_) {}
    }

    Future<void> setupJobListeners() async {
      try {
        final jobsSnap = await _db
            .collection('jobs')
            .where('applicants', arrayContains: uid)
            .get();
        for (final jobDoc in jobsSnap.docs) {
          subscribeToJobProposals(jobDoc);
        }
        // Also listen to jobs collection changes so new jobs with applicant can be picked up
        final jobsSub = _db
            .collection('jobs')
            .where('applicants', arrayContains: uid)
            .snapshots()
            .listen((snap) {
              for (final docChange in snap.docChanges) {
                if (docChange.type == DocumentChangeType.added)
                  subscribeToJobProposals(docChange.doc);
                if (docChange.type == DocumentChangeType.removed) {
                  final id = docChange.doc.id;
                  jobProposalSubs.remove(id)?.cancel();
                }
              }
            }, onError: (e) {});
        subs.add(jobsSub);
      } catch (_) {
        // fallback: if applicants query fails, scan all jobs once and subscribe to proposals
        try {
          final allJobs = await _db.collection('jobs').get();
          for (final jobDoc in allJobs.docs) {
            subscribeToJobProposals(jobDoc);
          }
        } catch (_) {}
      }
    }

    setupJobListeners().then((_) async {
      // one-time initial scan: for jobs where applicant contains uid, try to read proposals/{uid} doc directly
      try {
        final jobsSnap = await _db
            .collection('jobs')
            .where('applicants', arrayContains: uid)
            .get();
        for (final jobDoc in jobsSnap.docs) {
          try {
            final pDoc = await jobDoc.reference
                .collection('proposals')
                .doc(uid)
                .get();
            if (pDoc.exists) {
              final p = Proposal.fromMap(
                pDoc.data()!,
                pDoc.id,
                parentJobId: jobDoc.id,
              );
              byId['${jobDoc.id}__${p.id}'] = p;
            }
          } catch (_) {}

          try {
            final pSnap = await jobDoc.reference
                .collection('proposals')
                .where('freelancerId', isEqualTo: uid)
                .get();
            for (final pd in pSnap.docs) {
              final data = pd.data() as Map<String, dynamic>? ?? {};
              final p = Proposal.fromMap(data, pd.id, parentJobId: jobDoc.id);
              byId['${jobDoc.id}__${p.id}'] = p;
            }
          } catch (_) {}
        }

        // also try top-level proposals where either doc id == uid or field freelancerId == uid
        try {
          final doc = await _db.collection('proposals').doc(uid).get();
          if (doc.exists) {
            final data = doc.data() ?? <String, dynamic>{};
            final p = Proposal.fromMap(data, doc.id);
            final jobIdFromData = data['jobId'] as String?;
            byId['${jobIdFromData ?? 'top'}__${p.id}'] = p;
          }
        } catch (_) {}

        try {
          final topSnap = await _db
              .collection('proposals')
              .where('freelancerId', isEqualTo: uid)
              .get();
          for (final d in topSnap.docs) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final p = Proposal.fromMap(data, d.id);
            final jobIdFromData = data['jobId'] as String?;
            byId['${jobIdFromData ?? 'top'}__${p.id}'] = p;
          }
        } catch (_) {}

        // collectionGroup one-time fetch as well
        try {
          final cg = await _db
              .collectionGroup('proposals')
              .where('freelancerId', isEqualTo: uid)
              .get();
          for (final d in cg.docs) {
            final parentJobId = d.reference.parent.parent?.id;
            final data = d.data() as Map<String, dynamic>? ?? {};
            final p = Proposal.fromMap(data, d.id, parentJobId: parentJobId);
            final key = '${parentJobId ?? 'top'}__${d.id}';
            byId[key] = p;
          }
        } catch (_) {}

        emit();
      } catch (_) {}
    });

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
      for (final s in jobProposalSubs.values) {
        await s.cancel();
      }
      if (!controller.isClosed) await controller.close();
    };

    // initial empty emit
    emit();
    return controller.stream;
  }

  /// Get all proposals for a specific job (for client)
  Stream<List<Proposal>> getJobProposals(String jobId) {
    // Listen to proposals under the job's subcollection if present
    final sub = _db
        .collection('jobs')
        .doc(jobId)
        .collection('proposals')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Proposal.fromMap(d.data(), d.id)).toList(),
        );

    // Also listen to top-level proposals collection for same job
    final top = _db
        .collection('proposals')
        .where('jobId', isEqualTo: jobId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Proposal.fromMap(d.data(), d.id)).toList(),
        );

    // Merge by emitting whenever either stream updates; use a StreamController to combine latest
    final controller = StreamController<List<Proposal>>();
    List<Proposal> latestSub = [];
    List<Proposal> latestTop = [];

    sub.listen((list) {
      latestSub = list;
      final merged = {
        ...{for (var p in latestSub) p.id: p},
        ...{for (var p in latestTop) p.id: p},
      }.values.toList();
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged);
    }, onError: (e) => controller.addError(e));

    top.listen((list) {
      latestTop = list;
      final merged = {
        ...{for (var p in latestSub) p.id: p},
        ...{for (var p in latestTop) p.id: p},
      }.values.toList();
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged);
    }, onError: (e) => controller.addError(e));

    controller.onListen = () {};
    controller.onCancel = () {
      controller.close();
    };

    return controller.stream;
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

      // Create contract (deferred write via batch)
      final contractRef = _db.collection('contracts').doc();
      batch.set(contractRef, {
        'contractId': contractRef.id,
        'jobId': jobId,
        'proposalId': proposalId,
        'clientId': uid,
        'freelancerId': freelancerId,
        'status': 0, // active
        'amount': proposalData['bidAmount'] ?? proposalData['budget'],
        'bidAmount': proposalData['bidAmount'],
        'deliveryDays': proposalData['deliveryDays'],
        'startedAt': FieldValue.serverTimestamp(),
        'estimatedCompletion': Timestamp.fromDate(estimatedCompletion),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update job status (include contractId)
      batch.update(_db.collection('jobs').doc(jobId), {
        'status': 1, // ongoing
        'freelancerId': freelancerId,
        'selectedProposalId': proposalId,
        'contractId': contractRef.id,
        'startedAt': FieldValue.serverTimestamp(),
        'estimatedCompletion': Timestamp.fromDate(estimatedCompletion),
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

      // After commit: notify freelancer and mark client's new-proposal notifications for this job as read
      try {
        // notify freelancer
        final clientDoc = await _db.collection('users').doc(uid).get();
        final clientName = clientDoc.data()?['name'] ?? 'Client';
        final jobDoc = await _db.collection('jobs').doc(jobId).get();
        final jobTitle = jobDoc.data()?['title'] ?? 'Job';

        // find the contract created (by matching selectedProposalId)
        final createdContractSnap = await _db
            .collection('contracts')
            .where('proposalId', isEqualTo: proposalId)
            .limit(1)
            .get();
        String? contractId;
        if (createdContractSnap.docs.isNotEmpty)
          contractId = createdContractSnap.docs.first.id;

        await NotificationService().notifyProposalApproved(
          jobId: jobId,
          jobTitle: jobTitle,
          freelancerId: freelancerId,
          clientName: clientName,
          contractId: contractId,
        );

        // mark client's 'newProposal' notifications for this job as read
        final notifSnap = await _db
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .where('relatedJobId', isEqualTo: jobId)
            .get();
        for (final n in notifSnap.docs) {
          final map = n.data();
          if ((map['type'] ?? -1) == NotificationType.newProposal.index) {
            await n.reference.update({'read': true});
            // adjust user's unread count safely
            try {
              final userDoc = await _db.collection('users').doc(uid).get();
              final unread =
                  (userDoc.data()?['unreadNotifications'] ?? 0) as int;
              if (unread > 0) {
                await _db.collection('users').doc(uid).update({
                  'unreadNotifications': FieldValue.increment(-1),
                });
              }
            } catch (_) {}
          }
        }
      } catch (_) {
        // don't fail on notification cleanup errors
      }
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
  Future<Map<String, dynamic>> getProposalWithJob(
    String proposalId, {
    String? parentJobId,
  }) async {
    try {
      // If caller knows the parent jobId, try fetching from jobs/{jobId}/proposals/{proposalId} first
      if (parentJobId != null && parentJobId.isNotEmpty) {
        try {
          final subDoc = await _db
              .collection('jobs')
              .doc(parentJobId)
              .collection('proposals')
              .doc(proposalId)
              .get();
          if (subDoc.exists) {
            final proposalData = subDoc.data() ?? <String, dynamic>{};
            final jobDoc = await _db.collection('jobs').doc(parentJobId).get();
            return {
              'proposal': Proposal.fromMap(
                proposalData,
                subDoc.id,
                parentJobId: parentJobId,
              ),
              'job': jobDoc.data(),
            };
          }
        } catch (_) {
          // ignore and continue to other fallbacks
        }
      }

      // Try root/top-level proposals first
      var proposalDoc = await _db.collection('proposals').doc(proposalId).get();
      if (proposalDoc.exists) {
        final proposalData = proposalDoc.data() ?? <String, dynamic>{};

        // Determine jobId: prefer stored value but fall back to locating the parent
        final jobIdRaw = proposalData['jobId'];
        String jobId = jobIdRaw is String
            ? jobIdRaw
            : (jobIdRaw != null ? jobIdRaw.toString() : '');
        Map<String, dynamic>? jobData;

        if (jobId.isNotEmpty) {
          final jobDoc = await _db.collection('jobs').doc(jobId).get();
          jobData = jobDoc.data();
        } else {
          // If the top-level proposal does not contain jobId, try to locate it via collectionGroup
          try {
            final cgSnap = await _db
                .collectionGroup('proposals')
                .where(FieldPath.documentId, isEqualTo: proposalId)
                .get();
            if (cgSnap.docs.isNotEmpty) {
              for (final d in cgSnap.docs) {
                final parentJobId = d.reference.parent.parent?.id;
                if (parentJobId != null && parentJobId.isNotEmpty) {
                  final jobDoc = await _db
                      .collection('jobs')
                      .doc(parentJobId)
                      .get();
                  jobData = jobDoc.data();
                  jobId = parentJobId;
                  break;
                }
              }
            }
          } catch (_) {
            // ignore and leave jobData null
          }
        }

        return {
          'proposal': Proposal.fromMap(
            proposalData,
            proposalDoc.id,
            parentJobId: jobId,
          ),
          'job': jobData,
        };
      }

      // Fallback: collectionGroup query to locate the proposal document under jobs/{jobId}/proposals
      final cgSnap = await _db
          .collectionGroup('proposals')
          .where(FieldPath.documentId, isEqualTo: proposalId)
          .get();
      if (cgSnap.docs.isEmpty) throw Exception('Proposal not found');

      // Prefer a document whose parent job matches parentJobId if provided
      QueryDocumentSnapshot? chosen;
      if (parentJobId != null && parentJobId.isNotEmpty) {
        for (final d in cgSnap.docs) {
          final pId = d.reference.parent.parent?.id;
          if (pId == parentJobId) {
            chosen = d;
            break;
          }
        }
      }
      chosen ??= cgSnap.docs.first;

      final doc = chosen;
      final proposalData = doc.data() as Map<String, dynamic>? ?? {};

      // determine jobId: either stored in data or from parent path
      String jobId = (proposalData['jobId'] as String?) ?? '';
      if (jobId.isEmpty) {
        final parent = doc.reference.parent.parent; // jobs/{jobId}
        if (parent != null) jobId = parent.id;
      }

      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      return {
        'proposal': Proposal.fromMap(proposalData, doc.id, parentJobId: jobId),
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

  /// Debug helper: fetch raw proposal document maps for current user from multiple locations
  Future<List<Map<String, dynamic>>> fetchRawProposalsForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final results = <Map<String, dynamic>>[];
    try {
      // collectionGroup by field
      try {
        final cg = await _db
            .collectionGroup('proposals')
            .where('freelancerId', isEqualTo: uid)
            .get();
        for (final d in cg.docs)
          results.add({
            'id': d.id,
            'data': d.data(),
            'parentJobId': d.reference.parent.parent?.id,
          });
      } catch (_) {}

      // collectionGroup by doc id
      try {
        final cg2 = await _db
            .collectionGroup('proposals')
            .where(FieldPath.documentId, isEqualTo: uid)
            .get();
        for (final d in cg2.docs)
          results.add({
            'id': d.id,
            'data': d.data(),
            'parentJobId': d.reference.parent.parent?.id,
          });
      } catch (_) {}

      // jobs where applicant contains uid
      try {
        final jobs = await _db
            .collection('jobs')
            .where('applicants', arrayContains: uid)
            .get();
        for (final j in jobs.docs) {
          try {
            final p = await j.reference.collection('proposals').doc(uid).get();
            if (p.exists)
              results.add({'id': p.id, 'data': p.data(), 'parentJobId': j.id});
          } catch (_) {}

          try {
            final p2 = await j.reference
                .collection('proposals')
                .where('freelancerId', isEqualTo: uid)
                .get();
            for (final d in p2.docs)
              results.add({'id': d.id, 'data': d.data(), 'parentJobId': j.id});
          } catch (_) {}
        }
      } catch (_) {}

      // top-level collection
      try {
        final topDoc = await _db.collection('proposals').doc(uid).get();
        if (topDoc.exists)
          results.add({
            'id': topDoc.id,
            'data': topDoc.data(),
            'parentJobId': null,
          });
      } catch (_) {}
      try {
        final topQuery = await _db
            .collection('proposals')
            .where('freelancerId', isEqualTo: uid)
            .get();
        for (final d in topQuery.docs)
          results.add({'id': d.id, 'data': d.data(), 'parentJobId': null});
      } catch (_) {}
    } catch (_) {}

    // dedupe by id
    final map = <String, Map<String, dynamic>>{};
    for (final r in results) {
      final id = r['id'] as String? ?? '';
      final data = r['data'] as Map<String, dynamic>? ?? {};
      if (id.isEmpty) continue;
      map[id] = data;
    }
    return map.entries.map((e) => {'id': e.key, 'data': e.value}).toList();
  }
}
