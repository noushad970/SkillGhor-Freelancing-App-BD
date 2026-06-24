// lib/screens/review_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class ReviewScreen extends StatefulWidget {
  final String contractId;

  const ReviewScreen({super.key, required this.contractId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _submitting = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final contractRef = FirebaseFirestore.instance
        .collection('contracts')
        .doc(widget.contractId);

    try {
      final contractSnap = await contractRef.get();
      if (!contractSnap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Contract not found')));
        }
        return;
      }

      final contract = contractSnap.data() ?? {};
      final clientId = contract['clientId'] as String? ?? '';
      final freelancerId = contract['freelancerId'] as String? ?? '';
      final jobId = contract['jobId'] as String? ?? '';
      final jobTitle = contract['jobTitle'] ?? contract['title'] ?? '';

      final revieweeId = uid == clientId ? freelancerId : clientId;
      // Ensure the current user is a participant in the contract
      if (uid != clientId && uid != freelancerId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are not a participant of this contract'),
            ),
          );
        }
        return;
      }

      // Prevent duplicate review submissions
      final alreadyReviewed = (contract['reviewed'] == true);
      if (alreadyReviewed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This contract has already been reviewed'),
            ),
          );
        }
        return;
      }

      if (revieweeId.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid review target')),
          );
        return;
      }

      final comment = _commentController.text.trim();

      // Create review doc and update user rating atomically
      final reviewsRef = FirebaseFirestore.instance.collection('reviews');
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(revieweeId);

      try {
        // 1) create review document
        final reviewData = {
          'contractId': widget.contractId,
          'jobId': jobId,
          'jobTitle': jobTitle,
          'reviewerId': uid,
          'revieweeId': revieweeId,
          'rating': _rating.toDouble(),
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await reviewsRef.add(reviewData);

        // 2) update or create user aggregate rating
        final userSnap = await userRef.get();
        if (!userSnap.exists) {
          await userRef.set({
            'totalReviews': 1,
            'rating': _rating.toDouble(),
          }, SetOptions(merge: true));
        } else {
          final uData = userSnap.data() ?? <String, dynamic>{};
          final oldCount = (uData['totalReviews'] is int)
              ? uData['totalReviews'] as int
              : int.tryParse(uData['totalReviews']?.toString() ?? '0') ?? 0;
          final oldRating = (uData['rating'] is num)
              ? (uData['rating'] as num).toDouble()
              : (uData['rating'] != null
                    ? double.tryParse(uData['rating'].toString()) ?? 0.0
                    : 0.0);
          final newCount = oldCount + 1;
          final newAverage = ((oldRating * oldCount) + _rating) / (newCount);

          await userRef.update({
            'totalReviews': newCount,
            'rating': double.parse(newAverage.toStringAsFixed(2)),
          });
        }

        // 3) mark contract as reviewed
        await contractRef.update({
          'reviewed': true,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
      } catch (err, st) {
        // log and surface a clearer message
        // ignore: avoid_print
        print('Review flow failed: $err');
        // ignore: avoid_print
        print(st);
        throw Exception('Failed to submit review: $err');
      }

      // send notification to reviewee
      try {
        await NotificationService().sendNotification(
          userId: revieweeId,
          type: NotificationType.reviewReceived,
          title: 'New Review Received',
          message: 'You received a new review for "${jobTitle ?? ''}"',
          actionUrl: '/contracts/${widget.contractId}',
          relatedJobId: jobId,
        );
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review submitted')));
      Navigator.of(context).pop();
    } catch (e, st) {
      // log full error + stack for debugging
      // ignore: avoid_print
      print('Review submit failed: $e');
      // ignore: avoid_print
      print(st);
      if (mounted) {
        final msg = e is FirebaseException
            ? (e.message ?? e.toString())
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $msg')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final idx = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = idx),
                  icon: Icon(
                    idx <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Text('Review', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Describe your experience (optional)',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitReview,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
