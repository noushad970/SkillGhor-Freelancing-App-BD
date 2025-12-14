// lib/screens/find_jobs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindJobsScreen extends StatelessWidget {
  const FindJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Find Jobs - SkillGhor')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('status', isEqualTo: 'open')
            .orderBy('postedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No jobs available'));
          }

          final jobs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final jobDoc = jobs[index];
              final job = jobDoc.data() as Map<String, dynamic>;
              final jobId = jobDoc.id;
              final applicants = List<String>.from(job['applicants'] ?? []);
              final isApplied = applicants.contains(user.uid);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job['description'],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: (job['requiredSkills'] as List)
                            .map((s) => Chip(label: Text(s)))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Text('${job['budgetType']}: ৳${job['budget']}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: isApplied
                            ? null
                            : () async {
                                await FirebaseFirestore.instance.runTransaction(
                                  (transaction) async {
                                    final userSnap = await transaction.get(
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid),
                                    );
                                    final connects =
                                        userSnap.data()?['connects'] ?? 0;
                                    if (connects < 1) {
                                      throw 'Not enough connects';
                                    }

                                    transaction.update(
                                      FirebaseFirestore.instance
                                          .collection('jobs')
                                          .doc(jobId),
                                      {
                                        'applicants': FieldValue.arrayUnion([
                                          user.uid,
                                        ]),
                                      },
                                    );
                                    transaction.update(
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid),
                                      {'connects': FieldValue.increment(-1)},
                                    );
                                  },
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Applied!')),
                                );
                              },
                        child: Text(isApplied ? 'Applied' : 'Apply'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
