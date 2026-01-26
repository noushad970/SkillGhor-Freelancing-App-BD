// lib/screens/edit_profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String fullName;
  late String username;
  String? country;
  String bio = '';
  String companyName = '';
  List<String> skills = [];
  List<String> languages = [];
  List<Map<String, String>> education = []; // {degree, school, year}
  String portfolioGithub = '';
  String portfolioWebsite = '';

  final TextEditingController _skillCtrl = TextEditingController();
  final TextEditingController _langCtrl = TextEditingController();
  final TextEditingController _degreeCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _yearCtrl = TextEditingController();

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
      fullName = data['name'] ?? user.displayName ?? '';
      username = data['username'] ?? '';
      country = data['country'];
      bio = data['bio'] ?? '';
      companyName = data['companyName'] ?? '';
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
      final totalFields = 10; // adjust as needed

      if (fullName.isNotEmpty) completedFields++;
      if (username.isNotEmpty) completedFields++;
      if (country != null) completedFields++;
      if (skills.length >= 5) completedFields++;
      if (bio.length >= 100) completedFields++;
      if (languages.isNotEmpty) completedFields++;
      if (education.isNotEmpty) completedFields++;
      if (portfolioGithub.isNotEmpty || portfolioWebsite.isNotEmpty) {
        completedFields++;
      }
      if (companyName.isNotEmpty && auth.authState$.last == 'client') {
        completedFields++;
      }

      final completionPercent = (completedFields / totalFields * 100).round();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': fullName,
        'username': username,
        'country': country,
        'bio': bio,
        'companyName': companyName,
        'skills': skills,
        'languages': languages,
        'education': education,
        'portfolioGithub': portfolioGithub,
        'portfolioWebsite': portfolioWebsite,
        'profileCompletion': completionPercent,
        'connects': FieldValue.increment(0), // ensures field exists
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile Updated!'),
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
        title: const Text('Edit Profile - SkillGhor'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && skills.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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

                    TextFormField(
                      initialValue: fullName,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      onChanged: (v) => fullName = v.trim(),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: country,
                      decoration: const InputDecoration(labelText: 'Country *'),
                      items:
                          [
                                'Bangladesh',
                                'India',
                                'USA',
                                'UK',
                                'Canada',
                                'Australia',
                                'Other',
                              ]
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => country = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),

                    // Skills
                    const Text(
                      'Skills (Minimum 5) *',
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
                            decoration: const InputDecoration(
                              hintText: 'Add skill',
                            ),
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
                        '⚠️ Add at least 5 skills',
                        style: TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      initialValue: bio,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Professional Bio * (100+ chars)',
                      ),
                      validator: (v) => v!.trim().length < 100
                          ? 'Minimum 100 characters'
                          : null,
                      onChanged: (v) => bio = v,
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
                              onDeleted: () =>
                                  setState(() => languages.remove(l)),
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
                              hintText: 'e.g. English, Bangla',
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
                      (edu) => ListTile(
                        title: Text("${edu['degree']} from ${edu['school']}"),
                        subtitle: Text(edu['year'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              setState(() => education.remove(edu)),
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
                                    labelText: 'Year (e.g. 2020-2024)',
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
                                  if (_degreeCtrl.text.isNotEmpty &&
                                      _schoolCtrl.text.isNotEmpty) {
                                    setState(() {
                                      education.add({
                                        'degree': _degreeCtrl.text,
                                        'school': _schoolCtrl.text,
                                        'year': _yearCtrl.text,
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
                      onChanged: (v) => portfolioGithub = v,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: portfolioWebsite,
                      decoration: const InputDecoration(
                        labelText: 'Personal Website / Portfolio (optional)',
                      ),
                      onChanged: (v) => portfolioWebsite = v,
                    ),
                    const SizedBox(height: 16),

                    // Company Name (Client only)
                    if (Provider.of<AuthService>(
                          context,
                          // ignore: unrelated_type_equality_checks
                        ).authState$.last ==
                        'client')
                      TextFormField(
                        initialValue: companyName,
                        decoration: const InputDecoration(
                          labelText: 'Company Name',
                        ),
                        onChanged: (v) => companyName = v,
                      ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                        ),
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
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
}
