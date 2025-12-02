// lib/screens/onboarding_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  final String role;
  const OnboardingScreen({super.key, required this.role});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String fullName;
  late String username;
  DateTime? dob;
  String? country;

  final List<String> _skills = [];
  String _bio = '';
  String _companyName = '';

  final List<String> _countries = [
    'Bangladesh',
    'India',
    'USA',
    'UK',
    'Canada',
    'Australia',
    'Germany',
    'Other',
  ];

  final TextEditingController _skillCtrl = TextEditingController();

  // Username uniqueness check
  Future<bool> _isUsernameTaken(String name) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: name.toLowerCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
      return const Scaffold(body: Center(child: Text('Redirecting...')));
    }

    fullName = user.displayName ?? '';
    final photoUrl = user.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your SkillGhor Profile'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? const Icon(Icons.person, size: 60)
                    : null,
              ),
              const SizedBox(height: 20),

              // Full Name
              TextFormField(
                initialValue: fullName,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                onSaved: (v) => fullName = v!.trim(),
              ),
              const SizedBox(height: 16),

              // Username
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Username *',
                  hintText: 'e.g. john_dev',
                ),
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Required';
                  if (v.length < 4) return 'Minimum 4 characters';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                    return 'Only letters, numbers, and _ allowed';
                  }
                  return null;
                },
                onSaved: (v) => username = v!.trim().toLowerCase(),
              ),
              const SizedBox(height: 16),

              // Date of Birth
              ListTile(
                title: Text(
                  dob == null
                      ? 'Date of Birth *'
                      : dob!.toLocal().toString().split(' ')[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1995),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => dob = picked);
                },
              ),
              const SizedBox(height: 16),

              // Country
              DropdownButtonFormField<String>(
                value: country,
                decoration: const InputDecoration(labelText: 'Country *'),
                items: _countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => country = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // ==================== FREELANCER ONLY ====================
              if (widget.role == 'freelancer') ...[
                const Text(
                  'Freelancer Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Skills (Minimum 5)
                const Text(
                  'Add Skills (Minimum 5) *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _skills
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          onDeleted: () => setState(() => _skills.remove(s)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _skillCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Flutter, Firebase, UI/UX',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final skill = _skillCtrl.text.trim();
                        if (skill.isNotEmpty && !_skills.contains(skill)) {
                          setState(() {
                            _skills.add(skill);
                            _skillCtrl.clear();
                          });
                        }
                      },
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (_skills.length < 5)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ You must add at least 5 skills',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),

                // Bio (100+ characters)
                TextFormField(
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Professional Bio *',
                    hintText:
                        'Tell clients about your experience, expertise, and why they should hire you...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Bio is required';
                    if (v.trim().length < 100) {
                      return 'Bio must be at least 100 characters (currently ${v.trim().length})';
                    }
                    return null;
                  },
                  onSaved: (v) => _bio = v!.trim(),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_bio.length} / 100+ characters',
                  style: TextStyle(
                    color: _bio.length >= 100 ? Colors.green : Colors.red,
                  ),
                ),
              ] else ...[
                // ==================== CLIENT ONLY ====================
                const Text(
                  'Client Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Company Name (Optional)',
                  ),
                  onSaved: (v) => _companyName = v?.trim() ?? '',
                ),
              ],

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          // Extra validation for freelancer
                          if (widget.role == 'freelancer') {
                            if (_skills.length < 5) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please add at least 5 skills'),
                                ),
                              );
                              return;
                            }
                            if (_bio.trim().length < 100) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Bio must be at least 100 characters',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          if (!_formKey.currentState!.validate() ||
                              dob == null ||
                              country == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill all required fields',
                                ),
                              ),
                            );
                            return;
                          }

                          _formKey.currentState!.save();
                          setState(() => _isLoading = true);

                          try {
                            final taken = await _isUsernameTaken(username);
                            if (taken) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Username already taken! Try another.',
                                  ),
                                ),
                              );
                              setState(() => _isLoading = false);
                              return;
                            }

                            await auth.setRole(
                              role: widget.role,
                              extraFields: {
                                'name': fullName,
                                'username': username,
                                'dateOfBirth': dob!.toIso8601String(),
                                'country': country,
                                'photoUrl': photoUrl,
                                if (widget.role == 'freelancer') ...{
                                  'skills': _skills,
                                  'bio': _bio,
                                } else ...{
                                  'companyName': _companyName,
                                },
                                'onboarded': true,
                              },
                            );

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Welcome to SkillGhor!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Complete Profile & Continue',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
