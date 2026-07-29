// lib/screens/browse_jobs_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/proposal_service.dart';

class BrowseJobsScreen extends StatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  State<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends State<BrowseJobsScreen> {
  late ProposalService _proposalService;
  String _sortBy = 'recent'; // recent, budget_low, budget_high
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _proposalService = ProposalService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Jobs'),
        elevation: 0,
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Sort options
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildSortButton('Recent', 'recent'),
                const SizedBox(width: 8),
                _buildSortButton('Budget: Low to High', 'budget_low'),
                const SizedBox(width: 8),
                _buildSortButton('Budget: High to Low', 'budget_high'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Jobs list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('status', isEqualTo: 'open') // Only open jobs
                  .where('clientId', isNotEqualTo: user.uid) // Exclude own jobs
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No jobs available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Get all jobs and filter
                var jobs = snapshot.data!.docs.map((doc) {
                  return {
                    'id': doc.id,
                    'data': doc.data() as Map<String, dynamic>,
                  };
                }).toList();

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  jobs = jobs.where((job) {
                    final data = job['data'] as Map<String, dynamic>?;
                    if (data == null) return false;
                    final title = (data['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    final desc = (data['description'] ?? '')
                        .toString()
                        .toLowerCase();
                    return title.contains(_searchQuery) ||
                        desc.contains(_searchQuery);
                  }).toList();
                }

                // Apply sorting
                jobs.sort((a, b) {
                  final dataA = a['data'] as Map<String, dynamic>?;
                  final dataB = b['data'] as Map<String, dynamic>?;
                  if (dataA == null || dataB == null) return 0;

                  switch (_sortBy) {
                    case 'budget_low':
                      return (dataA['budget'] ?? 0).compareTo(
                        dataB['budget'] ?? 0,
                      );
                    case 'budget_high':
                      return (dataB['budget'] ?? 0).compareTo(
                        dataA['budget'] ?? 0,
                      );
                    default: // recent
                      return (dataB['createdAt'] as Timestamp?)?.compareTo(
                            dataA['createdAt'] as Timestamp? ?? Timestamp.now(),
                          ) ??
                          0;
                  }
                });

                if (jobs.isEmpty) {
                  return Center(
                    child: Text(
                      'No jobs match your search',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: jobs.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    return _buildJobCard(context, jobs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _sortBy = value);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.green.shade400,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    final jobId = job['id'] as String;
    final data = job['data'] as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Untitled Job';
    final description = data['description'] as String? ?? '';
    final budget = data['budget'] as num? ?? 0;
    final skills = List<String>.from(data['skills'] ?? []);
    final applicants = List.from(data['applicants'] ?? []);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Description preview
            Text(
              description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Skills
            if (skills.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: skills.take(4).map((skill) {
                  return Chip(
                    label: Text(skill, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            if (skills.length > 4)
              Text(
                '+${skills.length - 4} more skills',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
              ),
            const SizedBox(height: 12),

            // Budget, Applicants, Posted date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '৳${budget.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
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
                      'Applicants',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${applicants.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (createdAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Posted',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewJobDetails(context, jobId, data),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _applyForJob(context, jobId, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                    ),
                    child: const Text(
                      'Apply Now',
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
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return 'Just now';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }

  void _viewJobDetails(
    BuildContext context,
    String jobId,
    Map<String, dynamic> jobData,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
                  jobData['title'] ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '৳${jobData['budget']}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(jobData['description'] ?? 'No description'),
                const SizedBox(height: 20),
                const Text(
                  'Required Skills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List<String>.from(
                    jobData['skills'] ?? [],
                  ).map((skill) => Chip(label: Text(skill))).toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyForJob(
    BuildContext context,
    String jobId,
    Map<String, dynamic> jobData,
  ) {
    showDialog(
      context: context,
      builder: (context) => _ProposalDialog(
        jobId: jobId,
        jobData: jobData,
        proposalService: _proposalService,
      ),
    );
  }
}

class _ProposalDialog extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;
  final ProposalService proposalService;

  const _ProposalDialog({
    required this.jobId,
    required this.jobData,
    required this.proposalService,
  });

  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  late TextEditingController _coverLetterController;
  late TextEditingController _bidController;
  late TextEditingController _daysController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _coverLetterController = TextEditingController();
    _bidController = TextEditingController();
    _daysController = TextEditingController();
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    _bidController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Proposal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.jobData['title'] ?? 'Job',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bidController,
              decoration: const InputDecoration(
                labelText: 'Your Bid (৳)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _daysController,
              decoration: const InputDecoration(
                labelText: 'Delivery Days',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coverLetterController,
              decoration: const InputDecoration(
                labelText: 'Cover Letter',
                border: OutlineInputBorder(),
                hintText: 'Tell the client why you\'re the right fit...',
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitProposal,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _submitProposal() async {
    if (_bidController.text.isEmpty ||
        _daysController.text.isEmpty ||
        _coverLetterController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.proposalService.submitProposal(
        jobId: widget.jobId,
        coverLetter: _coverLetterController.text,
        bidAmount: double.parse(_bidController.text),
        deliveryDays: int.parse(_daysController.text),
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }
}
