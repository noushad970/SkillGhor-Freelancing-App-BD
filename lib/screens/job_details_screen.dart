// lib/screens/job_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/job_service.dart';

class JobDetailsScreen extends StatefulWidget {
  final String jobId;
  final bool isClient;

  const JobDetailsScreen({
    required this.jobId,
    required this.isClient,
    super.key,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  late JobService _jobService;

  @override
  void initState() {
    super.initState();
    _jobService = JobService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Job not found'));
          }

          final job = snapshot.data!.data() as Map<String, dynamic>;
          final status = JobStatus.values[job['status'] ?? 0];
          final isOngoing = status == JobStatus.ongoing;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toString().split('.')[1].toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Job Title
                Text(
                  job['title'] ?? 'Untitled Job',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Budget & Details
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '৳${job['budget']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (job['estimatedCompletion'] != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Due Date',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (job['estimatedCompletion'] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .split(' ')[0],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  job['description'] ?? '',
                  style: TextStyle(color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 24),

                // Required Skills
                const Text(
                  'Required Skills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (job['requiredSkills'] as List? ?? [])
                      .map(
                        (skill) => Chip(
                          label: Text(skill),
                          backgroundColor: Colors.green.withOpacity(0.2),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),

                // Milestones (if ongoing)
                if (isOngoing &&
                    (job['milestones'] as List? ?? []).isNotEmpty) ...[
                  const Text(
                    'Milestones',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...((job['milestones'] as List? ?? []).map(
                    (m) => MilestoneCard(
                      milestone: m,
                      jobId: widget.jobId,
                      onRelease: () => _handleReleaseMilestone(m['id']),
                    ),
                  )),
                  const SizedBox(height: 24),
                ],

                // Progress Tracker (if ongoing)
                if (isOngoing) ...[
                  const Text(
                    'Progress',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<double>(
                    future: _jobService.getContractProgress(widget.jobId),
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0;
                      return Column(
                        children: [
                          LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(
                              Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${progress.toStringAsFixed(0)}% Complete',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                if (!widget.isClient && isOngoing) ...[
                  // Freelancer Actions
                  ElevatedButton.icon(
                    onPressed: () {
                      _showCompletionDialog();
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _showPauseDialog();
                    },
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause Job'),
                  ),
                ] else if (widget.isClient && isOngoing) ...[
                  // Client Actions
                  ElevatedButton.icon(
                    onPressed: () {
                      _showApprovalDialog();
                    },
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Approve & Release Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _showMessageDialog();
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Message Freelancer'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete Job?'),
        content: const Text(
          'Are you sure you want to mark this job as complete?',
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _jobService.completeJob(
                jobId: widget.jobId,
                contractId: widget.jobId,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Job marked complete!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog() {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve & Release Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add feedback for the freelancer:'),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              decoration: InputDecoration(
                hintText: 'Feedback (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _jobService.completeJob(
                jobId: widget.jobId,
                contractId: widget.jobId,
                feedback: feedbackController.text,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment released!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Release Payment'),
          ),
        ],
      ),
    );
  }

  void _showPauseDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pause Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reason for pause:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter reason',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _jobService.pauseJob(
                jobId: widget.jobId,
                contractId: widget.jobId,
                reason: reasonController.text,
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Job paused')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: const Text('Pause'),
          ),
        ],
      ),
    );
  }

  void _showMessageDialog() {
    // Navigate to chat
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening chat...')));
  }

  void _handleReleaseMilestone(String milestoneId) {
    _jobService.releaseMilestonePayment(
      contractId: widget.jobId,
      milestoneId: milestoneId,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Milestone payment released')));
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.open:
        return Colors.blue;
      case JobStatus.ongoing:
        return Colors.orange;
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.cancelled:
        return Colors.red;
      case JobStatus.onHold:
        return Colors.grey;
    }
  }
}

class MilestoneCard extends StatelessWidget {
  final Map<String, dynamic> milestone;
  final String jobId;
  final VoidCallback onRelease;

  const MilestoneCard({
    required this.milestone,
    required this.jobId,
    required this.onRelease,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final status = milestone['status'] ?? 'pending';
    final dueDate = (milestone['dueDate'] as Timestamp?)?.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  milestone['description'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'released'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: status == 'released'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '৳${milestone['amount']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Due: ${dueDate.toString().split(' ')[0]}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRelease,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Release Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
