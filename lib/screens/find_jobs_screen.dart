// lib/screens/find_jobs_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FindJobsScreen extends StatefulWidget {
  const FindJobsScreen({super.key});

  @override
  State<FindJobsScreen> createState() => _FindJobsScreenState();
}

class _FindJobsScreenState extends State<FindJobsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  static const Color primaryColor = Color(0xff14A800);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          "Find Jobs",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
      ),

      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                hintText: "Search jobs, skills...",
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: primaryColor),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _query = "";
                          });
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('status', isEqualTo: 'open')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_outline, size: 70, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          "No jobs available",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
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
                            [];

                        return title.contains(_query) ||
                            desc.contains(_query) ||
                            skills.any((element) => element.contains(_query));
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "No jobs match your search",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final jobDoc = filtered[index];

                    final job = jobDoc.data() as Map<String, dynamic>;

                    final jobId = jobDoc.id;

                    final applicants = List<String>.from(
                      job['applicants'] ?? [],
                    );

                    final isApplied = applicants.contains(user.uid);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(.12),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),

                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: primaryColor.withOpacity(
                                    .12,
                                  ),
                                  child: const Icon(
                                    Icons.business,
                                    color: primaryColor,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Verified Client",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(.1),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    "${job['budgetType']}\n৳${job['budget']}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            Text(
                              job['description'],
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 18),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (job['requiredSkills'] as List)
                                  .map(
                                    (skill) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        skill,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                            const SizedBox(height: 22),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isApplied
                                      ? Colors.grey
                                      : primaryColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isApplied
                                    ? null
                                    : () async {
                                        await FirebaseFirestore.instance
                                            .runTransaction((
                                              transaction,
                                            ) async {
                                              final userSnap = await transaction
                                                  .get(
                                                    FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(user.uid),
                                                  );

                                              final connects =
                                                  userSnap
                                                      .data()?['connects'] ??
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
                                            backgroundColor: primaryColor,
                                            content: Text(
                                              "Application submitted successfully",
                                            ),
                                          ),
                                        );
                                      },
                                child: Text(
                                  isApplied ? "Applied" : "Apply Now",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
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
