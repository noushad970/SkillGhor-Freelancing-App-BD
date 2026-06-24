// lib/screens/my_jobs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'post_job_screen.dart';
import 'applicant_list_screen.dart';
import '../services/payment_service.dart';

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
              // Always query only by clientId + orderBy createdAt to avoid requiring a composite index
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('clientId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // Get all jobs and filter client-side when a status filter is active
                final allJobs = snapshot.data?.docs ?? const [];
                final jobs = _filterStatus == 'all'
                    ? allJobs
                    : allJobs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final s = data['status'] ?? 'open';
                        return s.toString().toLowerCase() ==
                            _filterStatus.toLowerCase();
                      }).toList();

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
                                status.toString().toUpperCase(),
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
                            // Approve & Release Payment (visible for ongoing / awaiting_release / awaiting_review)
                            if (status == 'ongoing' ||
                                status == 'awaiting_release' ||
                                status == 'awaiting_review')
                              PopupMenuItem(
                                child: const Text('Approve & Release Payment'),
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text(
                                        'Approve & Release Payment',
                                      ),
                                      content: Text(
                                        'Are you sure you want to release payment for "$title"? This will transfer funds to the freelancer and complete the job.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm != true) return;

                                  // show progress
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  try {
                                    // find related contract for this job and client
                                    final contractQuery =
                                        await FirebaseFirestore.instance
                                            .collection('contracts')
                                            .where('jobId', isEqualTo: j.id)
                                            .where('clientId', isEqualTo: uid)
                                            .limit(1)
                                            .get();

                                    if (contractQuery.docs.isEmpty) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Contract not found for this job',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final contractDoc =
                                        contractQuery.docs.first;
                                    final cData = contractDoc.data();
                                    final freelancerId =
                                        cData['freelancerId'] as String? ?? '';
                                    final invoiceId = (cData['invoiceId'] ?? '')
                                        .toString();

                                    // determine amount: contract.amount or contract.budget or job.budget
                                    final amountRaw =
                                        cData['amount'] ??
                                        cData['budget'] ??
                                        jData['budget'] ??
                                        0;
                                    final amount = (amountRaw is num)
                                        ? amountRaw.toDouble()
                                        : double.tryParse(
                                                amountRaw.toString(),
                                              ) ??
                                              0.0;

                                    final paymentService = PaymentService();

                                    if (invoiceId.isNotEmpty) {
                                      // finalize pending invoice
                                      await paymentService
                                          .finalizePendingPayment(invoiceId);
                                    } else {
                                      // immediate transfer
                                      await paymentService.processJobPayment(
                                        jobId: j.id,
                                        freelancerId: freelancerId,
                                        amount: amount,
                                      );
                                    }

                                    // mark contract & job completed
                                    await contractDoc.reference.update({
                                      'status': 'completed',
                                      'completedByClient': true,
                                      'completionReviewedAt':
                                          FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });

                                    await j.reference.update({
                                      'status': 'completed',
                                    });

                                    Navigator.of(
                                      context,
                                    ).pop(); // dismiss progress
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Payment released and job completed',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    Navigator.of(
                                      context,
                                    ).pop(); // dismiss progress
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Release failed: $e'),
                                      ),
                                    );
                                  }
                                },
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
