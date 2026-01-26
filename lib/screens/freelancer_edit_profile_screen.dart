// lib/screens/freelancer_edit_profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class FreelancerEditProfileScreen extends StatefulWidget {
  const FreelancerEditProfileScreen({super.key});

  @override
  State<FreelancerEditProfileScreen> createState() =>
      _FreelancerEditProfileScreenState();
}

class _FreelancerEditProfileScreenState
    extends State<FreelancerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String fullName;
  late String username;
  String? country;
  String bio = '';
  List<String> skills = [];
  List<String> languages = [];
  List<Map<String, String>> education =
      []; // e.g. [{'degree': 'BSc', 'school': 'University', 'year': '2020'}]
  String portfolioGithub = '';
  String portfolioWebsite = '';

  final TextEditingController _skillCtrl = TextEditingController();
  final TextEditingController _langCtrl = TextEditingController();
  final TextEditingController _degreeCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _yearCtrl = TextEditingController();

  final List<String> _countries = [
    'Bangladesh',
    'India',
    'USA',
    'UK',
    'Canada',
    'Australia',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser!;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = snap.data() ?? {};

    setState(() {
      fullName = data['name'] ?? '';
      username = data['username'] ?? '';
      country = data['country'];
      bio = data['bio'] ?? '';
      skills = List<String>.from(data['skills'] ?? []);
      languages = List<String>.from(data['languages'] ?? []);
      education = List<Map<String, String>>.from(
        (data['education'] ?? []).map((e) => Map<String, String>.from(e)),
      );
      portfolioGithub = data['portfolioGithub'] ?? '';
      portfolioWebsite = data['portfolioWebsite'] ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (skills.length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least 5 skills')));
      return;
    }
    if (bio.trim().length < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bio must be 100+ characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final uid = auth.currentUser!.uid;

      // Calculate dynamic profile completion
      int completedFields = 0;
      final totalFields = 10; // Adjust as needed
      if (fullName.isNotEmpty) completedFields++;
      if (username.isNotEmpty) completedFields++;
      if (country != null) completedFields++;
      if (skills.length >= 5) completedFields += 2; // Extra weight for skills
      if (bio.length >= 100) completedFields += 2;
      if (languages.isNotEmpty) completedFields++;
      if (education.isNotEmpty) completedFields++;
      if (portfolioGithub.isNotEmpty || portfolioWebsite.isNotEmpty) {
        completedFields++;
      }

      final completionPercent = (completedFields / totalFields * 100).round();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': fullName,
        'country': country,
        'bio': bio,
        'skills': skills,
        'languages': languages,
        'education': education,
        'portfolioGithub': portfolioGithub,
        'portfolioWebsite': portfolioWebsite,
        'profileCompletion': completionPercent,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final photoUrl = auth.currentUser?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Freelancer Profile - SkillGhor'),
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
              ),
              const SizedBox(height: 20),

              // Full Name
              TextFormField(
                initialValue: fullName,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                onChanged: (v) => fullName = v.trim(),
              ),
              const SizedBox(height: 16),

              // Username (read-only after signup)
              TextFormField(
                initialValue: username,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText:
                      'Username is set during signup and cannot be changed',
                ),
              ),
              const SizedBox(height: 16),

              // Country
              DropdownButtonFormField<String>(
                initialValue: country,
                decoration: const InputDecoration(labelText: 'Country *'),
                items: _countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => country = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Skills
              const Text(
                'Skills (Min 5) *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: skills
                    .map(
                      (s) => Chip(
                        label: Text(s),
                        onDeleted: () => setState(() => skills.remove(s)),
                      ),
                    )
                    .toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillCtrl,
                      decoration: const InputDecoration(hintText: 'Add skill'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_skillCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          skills.add(_skillCtrl.text.trim());
                          _skillCtrl.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              if (skills.length < 5)
                const Text(
                  'Add at least 5 skills',
                  style: TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                initialValue: bio,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Bio * (100+ chars)',
                ),
                validator: (v) =>
                    v!.trim().length < 100 ? 'Min 100 chars' : null,
                onChanged: (v) => bio = v.trim(),
              ),
              Text(
                '${bio.length} chars',
                style: TextStyle(
                  color: bio.length >= 100 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),

              // Languages
              const Text(
                'Languages',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: languages
                    .map(
                      (l) => Chip(
                        label: Text(l),
                        onDeleted: () => setState(() => languages.remove(l)),
                      ),
                    )
                    .toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _langCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Add language',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_langCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          languages.add(_langCtrl.text.trim());
                          _langCtrl.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Education
              const Text(
                'Education',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...education.map(
                (e) => ListTile(
                  title: Text(e['degree'] ?? ''),
                  subtitle: Text('${e['school']} - ${e['year']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => education.remove(e)),
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Education'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add Education'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _degreeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Degree',
                            ),
                          ),
                          TextField(
                            controller: _schoolCtrl,
                            decoration: const InputDecoration(
                              labelText: 'School/University',
                            ),
                          ),
                          TextField(
                            controller: _yearCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Year (e.g. 2020)',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (_degreeCtrl.text.trim().isNotEmpty) {
                              setState(() {
                                education.add({
                                  'degree': _degreeCtrl.text.trim(),
                                  'school': _schoolCtrl.text.trim(),
                                  'year': _yearCtrl.text.trim(),
                                });
                                _degreeCtrl.clear();
                                _schoolCtrl.clear();
                                _yearCtrl.clear();
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Portfolio
              TextFormField(
                initialValue: portfolioGithub,
                decoration: const InputDecoration(
                  labelText: 'GitHub Profile (optional)',
                ),
                onChanged: (v) => portfolioGithub = v.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: portfolioWebsite,
                decoration: const InputDecoration(
                  labelText: 'Website / Portfolio (optional)',
                ),
                onChanged: (v) => portfolioWebsite = v.trim(),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
