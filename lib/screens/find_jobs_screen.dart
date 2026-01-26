// lib/screens/find_jobs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FindJobsScreen extends StatefulWidget {
  const FindJobsScreen({super.key});

  @override
  State<FindJobsScreen> createState() => _FindJobsScreenState();
}

class _FindJobsScreenState extends State<FindJobsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Find Jobs - SkillGhor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by title, description, or skill',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                final filtered = _query.isEmpty
                    ? jobs
                    : jobs.where((doc) {
                        final job = doc.data() as Map<String, dynamic>;
                        final title = (job['title'] ?? '')
                            .toString()
                            .toLowerCase();
                        final desc = (job['description'] ?? '')
                            .toString()
                            .toLowerCase();
                        final skills =
                            (job['requiredSkills'] as List<dynamic>?)
                                ?.map((e) => e.toString().toLowerCase())
                                .toList() ??
                            <String>[];
                        return title.contains(_query) ||
                            desc.contains(_query) ||
                            skills.any((s) => s.contains(_query));
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No jobs match your search.'),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final jobDoc = filtered[index];
                    final job = jobDoc.data() as Map<String, dynamic>;
                    final jobId = jobDoc.id;
                    final applicants = List<String>.from(
                      job['applicants'] ?? [],
                    );
                    final isApplied = applicants.contains(user.uid);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                                      await FirebaseFirestore.instance
                                          .runTransaction((transaction) async {
                                            final userSnap = await transaction
                                                .get(
                                                  FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(user.uid),
                                                );
                                            final connects =
                                                userSnap.data()?['connects'] ??
                                                0;
                                            if (connects < 1) {
                                              throw 'Not enough connects';
                                            }

                                            transaction.update(
                                              FirebaseFirestore.instance
                                                  .collection('jobs')
                                                  .doc(jobId),
                                              {
                                                'applicants':
                                                    FieldValue.arrayUnion([
                                                      user.uid,
                                                    ]),
                                              },
                                            );
                                            transaction.update(
                                              FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid),
                                              {
                                                'connects':
                                                    FieldValue.increment(-1),
                                              },
                                            );
                                          });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Applied!'),
                                        ),
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
          ),
        ],
      ),
    );
  }
}
