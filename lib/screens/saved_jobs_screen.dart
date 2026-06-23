import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'apply_job_screen.dart';

class SavedJobsScreen extends StatelessWidget {
  const SavedJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view saved jobs.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Jobs')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnap.hasError) {
            return Center(child: Text('Error: ${userSnap.error}'));
          }

          final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final savedJobs = List<String>.from(data['savedJobs'] ?? []);

          if (savedJobs.isEmpty) {
            return const Center(child: Text('No saved jobs yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: savedJobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final jobId = savedJobs[index];
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .snapshots(),
                builder: (context, jobSnap) {
                  if (jobSnap.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: ListTile(title: Text('Loading job...')),
                    );
                  }

                  if (jobSnap.hasError) {
                    return Card(
                      child: ListTile(
                        title: Text('Error loading job: ${jobSnap.error}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeSaved(jobId),
                        ),
                      ),
                    );
                  }

                  if (!jobSnap.hasData || !jobSnap.data!.exists) {
                    return Card(
                      child: ListTile(
                        title: const Text('Job no longer available'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeSaved(jobId),
                        ),
                      ),
                    );
                  }

                  final job = jobSnap.data!.data() as Map<String, dynamic>;
                  final isOpen = job['status'] == 'open';
                  final applicants = List<String>.from(
                    job['applicants'] ?? const [],
                  );
                  final isApplied = applicants.contains(uid);

                  return Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  job['title'] ?? 'Untitled job',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.bookmark_remove),
                                tooltip: 'Remove from saved',
                                onPressed: () => _removeSaved(jobId),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            job['description'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${job['budgetType']} • ৳${job['budget']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'Posted ${_timeAgo(job['postedAt'])}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.bookmark_remove),
                                  label: const Text('Remove'),
                                  onPressed: () => _removeSaved(jobId),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isOpen && !isApplied
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ApplyJobScreen(jobId: jobId),
                                            ),
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: !isOpen
                                        ? Colors.grey
                                        : isApplied
                                        ? Colors.grey
                                        : Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    !isOpen
                                        ? 'Closed'
                                        : isApplied
                                        ? 'Applied'
                                        : 'Apply',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _removeSaved(String jobId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'savedJobs': FieldValue.arrayRemove([jobId]),
    });
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    final date = (timestamp as Timestamp).toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
