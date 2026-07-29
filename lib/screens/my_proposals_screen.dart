// lib/screens/my_proposals_screen.dart
import 'package:flutter/material.dart';
import '../services/proposal_service.dart';
import '../services/job_service.dart';

class MyProposalsScreen extends StatefulWidget {
  const MyProposalsScreen({super.key});

  @override
  State<MyProposalsScreen> createState() => _MyProposalsScreenState();
}

class _MyProposalsScreenState extends State<MyProposalsScreen> {
  late ProposalService _proposalService;
  String _filterStatus = 'all'; // all, pending, approved, rejected, withdrawn

  @override
  void initState() {
    super.initState();
    _proposalService = ProposalService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Proposals'),
        elevation: 0,
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
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Pending', 'pending'),
                _buildFilterChip('Approved', 'approved'),
                _buildFilterChip('Rejected', 'rejected'),
                _buildFilterChip('Withdrawn', 'withdrawn'),
              ],
            ),
          ),
          // Proposals list
          Expanded(
            child: StreamBuilder<List<Proposal>>(
              stream: _proposalService.getFreelancerProposals(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No proposals yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start applying to jobs to see them here',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                // Filter proposals based on selected status
                final allProposals = snapshot.data!;
                String normalizeProposalStatus(ProposalStatus s) =>
                    s.toString().split('.').last.toLowerCase();

                final filteredProposals = _filterStatus == 'all'
                    ? allProposals
                    : allProposals
                          .where(
                            (p) =>
                                normalizeProposalStatus(p.status) ==
                                _filterStatus,
                          )
                          .toList();

                if (filteredProposals.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${_filterStatus == 'all' ? '' : _filterStatus} proposals',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredProposals.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final proposal = filteredProposals[index];
                    return _buildProposalCard(context, proposal);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalCard(BuildContext context, Proposal proposal) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _proposalService.getProposalWithJob(
        proposal.id,
        parentJobId: proposal.jobId.isNotEmpty ? proposal.jobId : null,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final jobData = snapshot.data!['job'] as Map<String, dynamic>?;
        final jobTitle =
            (jobData != null ? jobData['title'] as String? : null) ??
            'Untitled Job';

        // Parse job status robustly (int index or string)
        JobStatus jobStatus = JobStatus.open;
        if (jobData != null) {
          final raw = jobData['status'];
          if (raw is int) {
            int idx = raw;
            if (idx < 0) idx = 0;
            if (idx >= JobStatus.values.length) {
              idx = JobStatus.values.length - 1;
            }
            jobStatus = JobStatus.values[idx];
          } else if (raw is String) {
            final key = raw.toLowerCase();
            jobStatus = JobStatus.values.firstWhere(
              (e) => e.toString().split('.').last.toLowerCase() == key,
              orElse: () => JobStatus.open,
            );
          }
        }

        // If job was deleted or not found, show a readable card
        final isJobMissing = jobData == null || jobData.isEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isJobMissing ? 'Job not available' : jobTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isJobMissing
                                ? 'Job no longer exists or was removed'
                                : 'Job Status: ${jobStatus.toString().split('.').last.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _getJobStatusColor(jobStatus),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getProposalStatusColor(proposal.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        proposal.status
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bid Amount and Delivery Days
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bid Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '৳${proposal.bidAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${proposal.deliveryDays} days',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Applied',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(proposal.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Cover Letter Preview
                if (proposal.coverLetter.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cover Letter',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          proposal.coverLetter,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // Rejection Reason (if rejected)
                if (proposal.status == ProposalStatus.rejected &&
                    proposal.rejectionReason != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rejection Reason',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          proposal.rejectionReason!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    if (proposal.status == ProposalStatus.pending)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _withdrawProposal(context, proposal.id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Withdraw'),
                        ),
                      ),
                    if (proposal.status == ProposalStatus.pending)
                      const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _viewProposalDetails(context, proposal),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(color: Colors.white),
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
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterStatus = value);
        },
        backgroundColor: Colors.grey.shade100,
        selectedColor: Colors.green.shade400,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Color _getProposalStatusColor(ProposalStatus status) {
    switch (status) {
      case ProposalStatus.pending:
        return Colors.orange;
      case ProposalStatus.approved:
        return Colors.green;
      case ProposalStatus.rejected:
        return Colors.red;
      case ProposalStatus.withdrawn:
        return Colors.grey;
      case ProposalStatus.completed:
        return Colors.blue;
    }
  }

  Color _getJobStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.open:
        return Colors.orange;
      case JobStatus.ongoing:
        return Colors.blue;
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.cancelled:
        return Colors.red;
      case JobStatus.onHold:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }

  void _withdrawProposal(BuildContext context, String proposalId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Proposal?'),
        content: const Text('Are you sure you want to withdraw this proposal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _proposalService.withdrawProposal(proposalId);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Proposal withdrawn successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _viewProposalDetails(BuildContext context, Proposal proposal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        // Prefer resolving from the known parentJobId when available to avoid ambiguous collectionGroup lookups
        future: _proposalService.getProposalWithJob(
          proposal.id,
          parentJobId: proposal.jobId.isNotEmpty ? proposal.jobId : null,
        ),
        builder: (context, snapshot) {
          // show loading state while waiting
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // show a friendly error if lookup failed
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error, size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load proposal details',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          }

          // if no data found, show a message
          if (!snapshot.hasData || snapshot.data == null) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 12),
                    const Text('Proposal details not available'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          }

          // jobData may be null if job was deleted; treat as nullable
          final jobData = snapshot.data!['job'] as Map<String, dynamic>?;

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      jobData == null
                          ? 'Untitled Job'
                          : (jobData['title'] ?? 'Untitled Job'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Proposal Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailRow('Status', proposal.status.name.toUpperCase()),
                    _detailRow(
                      'Bid Amount',
                      '৳${proposal.bidAmount.toStringAsFixed(0)}',
                    ),
                    _detailRow(
                      'Delivery Days',
                      '${proposal.deliveryDays} days',
                    ),
                    _detailRow('Applied', _formatDate(proposal.createdAt)),
                    const SizedBox(height: 16),
                    const Text(
                      'Cover Letter',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(proposal.coverLetter),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
