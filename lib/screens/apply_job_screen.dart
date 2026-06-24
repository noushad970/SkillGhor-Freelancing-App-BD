// lib/screens/apply_job_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ApplyJobScreen extends StatefulWidget {
  final String jobId;
  const ApplyJobScreen({super.key, required this.jobId});

  @override
  State<ApplyJobScreen> createState() => _ApplyJobScreenState();
}

class _ApplyJobScreenState extends State<ApplyJobScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  int _boostConnects = 0;

  // Controllers
  final _descriptionCtrl = TextEditingController();
  final _estimatedDateCtrl = TextEditingController();
  final _portfolioCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  // Animation controller for fade-in
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _jobData;

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();

    // Fade-in animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _descriptionCtrl.dispose();
    _estimatedDateCtrl.dispose();
    _portfolioCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchJobDetails() async {
    final jobDoc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .get();
    if (jobDoc.exists) {
      setState(() => _jobData = jobDoc.data());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job not found'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Prevent applying to your own job
      if (_jobData != null && _jobData!['clientId'] == user.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot apply to your own job'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final jobRef = FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId);
      final proposalRef = jobRef.collection('proposals').doc(user.uid);

      // Check duplicate
      final proposalSnap = await proposalRef.get();
      if (proposalSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already applied'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Check connects
      final userSnap = await userRef.get();
      final currentConnects =
          (userSnap.data()?['totalConnects'] as num?)?.toInt() ?? 0;
      final totalToDeduct = 1 + _boostConnects;

      if (currentConnects < totalToDeduct) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough connects'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Parse estimated date into Timestamp if possible
      final estimatedInput = _estimatedDateCtrl.text.trim();
      DateTime? parsedDate;
      if (estimatedInput.isNotEmpty) {
        parsedDate = DateTime.tryParse(estimatedInput);
      }
      final estimatedValue = parsedDate != null
          ? Timestamp.fromDate(parsedDate)
          : estimatedInput;

      // Transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshUser = await transaction.get(userRef);
        final freshConnects =
            (freshUser.data()?['totalConnects'] as num?)?.toInt() ?? 0;
        if (freshConnects < totalToDeduct) {
          throw Exception('Insufficient connects');
        }

        transaction.update(userRef, {
          'totalConnects': FieldValue.increment(-totalToDeduct),
          'totalProposals': FieldValue.increment(1),
        });

        transaction.set(proposalRef, {
          'freelancerId': user.uid,
          'freelancerName': userSnap.data()?['name'] ?? 'Unknown',
          'freelancerPhotoUrl': userSnap.data()?['photoUrl'],
          'description': _descriptionCtrl.text.trim(),
          'estimatedDate': estimatedValue,
          'portfolio': _portfolioCtrl.text.trim(),
          'budget': double.tryParse(_budgetCtrl.text.trim()) ?? 0.0,
          'boostConnects': _boostConnects,
          'totalConnectsSpent': totalToDeduct,
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'submitted',
        });

        transaction.update(jobRef, {
          'applicants': FieldValue.arrayUnion([user.uid]),
          'proposalsCount': FieldValue.increment(1),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal submitted!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // Background with subtle gradient + future image placeholder
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
          image: const DecorationImage(
            image: AssetImage(
              'assets/images/background_apply.jpg',
            ), // ← Add your image here later
            fit: BoxFit.cover,
            opacity: 0.08, // Very subtle
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Apply to Job',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance
                  ],
                ),
              ),

              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Job Card
                          Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _jobData!['title'],
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'By: ${_jobData!['clientName']}',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        _jobData!['isClientVerified']
                                            ? Icons.verified
                                            : Icons.verified_user_outlined,
                                        color: _jobData!['isClientVerified']
                                            ? Colors.blue
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Budget: ${_jobData!['budgetType']} • ৳${_jobData!['budget']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Deadline: ${_formatDate(_jobData!['deadline'])}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Form Fields with nice styling
                          _buildTextField(
                            controller: _descriptionCtrl,
                            label: 'Proposal Description *',
                            hint:
                                'Why should I hire you? Your approach, experience...',
                            minLines: 5,
                            validator: (v) => v!.trim().length < 100
                                ? 'Min 100 characters'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _estimatedDateCtrl,
                            label: 'Estimated Delivery Date *',
                            hint: 'YYYY-MM-DD (e.g. 2026-02-15)',
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _portfolioCtrl,
                            label: 'Portfolio / GitHub Link (optional)',
                            hint: 'https://github.com/yourusername',
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _budgetCtrl,
                            label: 'Your Proposed Budget (৳) *',
                            hint: 'e.g. 25000',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v!.trim().isEmpty) return 'Required';
                              if (double.tryParse(v) == null) {
                                return 'Valid number only';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Boost Section
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Boost Your Proposal',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButton<int>(
                                    value: _boostConnects,
                                    isExpanded: true,
                                    items: List.generate(11, (i) => i)
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text('+$c extra connects'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _boostConnects = v ?? 0),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Total connects to spend: ${1 + _boostConnects}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Submit Button with scale animation on press
                          ScaleTransition(
                            scale: Tween<double>(begin: 1.0, end: 0.95).animate(
                              CurvedAnimation(
                                parent: _animController,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitProposal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 8,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Proposal',
                                        style: TextStyle(fontSize: 18),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int minLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : null,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    return (timestamp as Timestamp).toDate().toLocal().toString().split(' ')[0];
  }
}
