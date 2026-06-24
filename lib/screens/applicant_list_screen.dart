// lib/screens/applicant_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'advanced_chat_screen.dart';

// Timestamp for contract creation timestamp

class ApplicantListScreen extends StatelessWidget {
  const ApplicantListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!; // client uid
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applicants'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('clientId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, jobsSnap) {
          if (jobsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (jobsSnap.hasError) {
            return Center(child: Text('Error: ${jobsSnap.error}'));
          }
          if (!jobsSnap.hasData || jobsSnap.data!.docs.isEmpty) {
            return const Center(child: Text('No jobs found'));
          }
          final jobs = jobsSnap.data!.docs;
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final jobDoc = jobs[index];
              final jobId = jobDoc.id;
              final title = jobDoc['title'] ?? 'Untitled Job';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ExpansionTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('jobs')
                          .doc(jobId)
                          .collection('proposals')
                          .orderBy('submittedAt', descending: true)
                          .snapshots(),
                      builder: (context, propSnap) {
                        if (propSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (propSnap.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Error: ${propSnap.error}'),
                          );
                        }
                        if (!propSnap.hasData || propSnap.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No proposals submitted yet'),
                          );
                        }
                        final props = propSnap.data!.docs;
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: props.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = props[i];
                            final data = p.data() as Map<String, dynamic>;
                            final freelancerUid =
                                (data['freelancerId'] ??
                                        data['freelancerUid'] ??
                                        '')
                                    as String;
                            final budget =
                                (data['budget'] as num?)?.toDouble() ?? 0.0;
                            final boost = (data['boostConnects'] as int?) ?? 0;
                            final portfolio =
                                (data['portfolio'] as String?) ?? '';
                            final estimated = data['estimatedDate'];

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(freelancerUid)
                                  .get(),
                              builder: (context, userSnap) {
                                final uData =
                                    userSnap.data?.data()
                                        as Map<String, dynamic>? ??
                                    {};
                                final fname =
                                    (uData['name'] as String?) ?? 'Freelancer';
                                final photoUrl = uData['photoUrl'] as String?;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(
                                    fname,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      Text(data['description'] ?? ''),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Budget: ৳${budget.toStringAsFixed(0)} • Boost: +$boost',
                                      ),
                                      if (portfolio.isNotEmpty)
                                        Text('Portfolio: $portfolio'),
                                      if (estimated != null)
                                        Text(
                                          'Estimated: ${estimated is Timestamp ? estimated.toDate().toLocal().toString().split(' ')[0] : estimated}',
                                        ),
                                    ],
                                  ),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            // Update proposal status to approved
                                            await p.reference.update({
                                              'status': 'approved',
                                            });

                                            // Create contract document
                                            await FirebaseFirestore.instance
                                                .collection('contracts')
                                                .add({
                                                  'clientId': user.uid,
                                                  'freelancerId': freelancerUid,
                                                  'jobId': jobId,
                                                  'jobTitle': title,
                                                  'status': 'active',
                                                  'createdAt': Timestamp.now(),
                                                  'updatedAt': Timestamp.now(),
                                                });

                                            // Update job to mark as having active contract
                                            await FirebaseFirestore.instance
                                                .collection('jobs')
                                                .doc(jobId)
                                                .update({'status': 'ongoing'});

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Freelancer approved! Contract created.',
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Approve failed: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Approve'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AdvancedChatScreen(
                                                    otherUserId: freelancerUid,
                                                    otherUserName: fname,
                                                    jobId: jobId,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: const Text('Message'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
