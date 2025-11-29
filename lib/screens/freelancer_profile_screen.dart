import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class FreelancerProfileScreen extends StatefulWidget {
  final String uid;
  const FreelancerProfileScreen({super.key, required this.uid});

  @override
  State<FreelancerProfileScreen> createState() =>
      _FreelancerProfileScreenState();
}

class _FreelancerProfileScreenState extends State<FreelancerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skillsController = TextEditingController();
  final _bioController = TextEditingController();
  final _rateController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _skillsController.dispose();
    _bioController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Freelancer profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Skills (comma separated)',
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Add at least one skill' : null,
              ),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Short bio'),
                minLines: 2,
                maxLines: 4,
              ),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(
                  labelText: 'Hourly rate (USD)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _loading = true);

                        final skills = _skillsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        final bio = _bioController.text.trim();
                        final rate =
                            double.tryParse(_rateController.text.trim()) ?? 0.0;
                        try {
                          await auth.setRoleAndOnboard(
                            uid: widget.uid,
                            role: 'freelancer',
                            extraFields: {
                              'skills': skills,
                              'bio': bio,
                              'hourly_rate': rate,
                              // keep verified false for now
                            },
                          );
                          // after saving, navigator pop to root (EntryPoint will route to home)
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _loading = false);
                        }
                      },
                      child: const Text('Save & Continue'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
