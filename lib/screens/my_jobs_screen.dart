// lib/screens/my_jobs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'post_job_screen.dart';
import 'applicant_list_screen.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  String _filterStatus = 'all'; // all, open, closed, ongoing

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Jobs'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['all', 'open', 'closed', 'ongoing']
                  .map(
                    (status) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(status.toUpperCase()),
                        selected: _filterStatus == status,
                        onSelected: (v) =>
                            setState(() => _filterStatus = status),
                        selectedColor: Colors.green.shade600,
                        labelStyle: TextStyle(
                          color: _filterStatus == status
                              ? Colors.white
                              : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // Jobs list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _filterStatus == 'all'
                  ? FirebaseFirestore.instance
                        .collection('jobs')
                        .where('clientId', isEqualTo: uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('jobs')
                        .where('clientId', isEqualTo: uid)
                        .where('status', isEqualTo: _filterStatus)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final jobs = snapshot.data?.docs ?? const [];
                if (jobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No jobs found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final j = jobs[idx];
                    final jData = j.data() as Map<String, dynamic>;
                    final title = jData['title'] ?? 'Untitled';
                    final budget = jData['budget'] ?? 0;
                    final status = jData['status'] ?? 'open';
                    final proposalsCount =
                        (jData['proposalsCount'] ?? 0) as int;
                    final applicants = List<String>.from(
                      jData['applicants'] ?? [],
                    );

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '৳$budget • $proposalsCount proposals • ${applicants.length} applicants',
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: status == 'open'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              labelStyle: TextStyle(
                                color: status == 'open'
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('View Applicants'),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ApplicantListScreen(),
                                ),
                              ),
                            ),
                            if (status == 'open')
                              PopupMenuItem(
                                child: const Text('Close Job'),
                                onTap: () async {
                                  await j.reference.update({
                                    'status': 'closed',
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Job closed')),
                                  );
                                },
                              ),
                            if (status == 'closed')
                              PopupMenuItem(
                                child: const Text('Reopen Job'),
                                onTap: () async {
                                  await j.reference.update({'status': 'open'});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Job reopened'),
                                    ),
                                  );
                                },
                              ),
                            PopupMenuItem(
                              child: const Text('Delete'),
                              onTap: () async {
                                await j.reference.delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Job deleted')),
                                );
                              },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostJobScreen()),
        ),
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.add),
      ),
    );
  }
}
