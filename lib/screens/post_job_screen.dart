// lib/screens/post_job_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String title = '';
  String description = '';
  final List<String> requiredSkills = [];
  String budgetType = 'Fixed';
  String budget = '';
  DateTime? deadline;
  final TextEditingController _skillCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(auth.currentUser!.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a New Job'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Job Title *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                onChanged: (v) => title = v.trim(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Job Description *',
                ),
                validator: (v) =>
                    v!.trim().length < 100 ? 'Minimum 100 characters' : null,
                onChanged: (v) => description = v.trim(),
              ),
              const SizedBox(height: 16),

              // Required Skills
              const Text(
                'Required Skills (min 3) *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: requiredSkills
                    .map(
                      (s) => Chip(
                        label: Text(s),
                        onDeleted: () =>
                            setState(() => requiredSkills.remove(s)),
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
                        hintText: 'Flutter, UI/UX, etc.',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_skillCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          requiredSkills.add(_skillCtrl.text.trim());
                          _skillCtrl.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              if (requiredSkills.length < 3)
                const Text(
                  '⚠️ Add at least 3 skills',
                  style: TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),

              // Budget Type
              DropdownButtonFormField<String>(
                initialValue: budgetType,
                decoration: const InputDecoration(labelText: 'Budget Type *'),
                items: ['Fixed', 'Hourly']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => budgetType = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: budgetType == 'Fixed'
                      ? 'Fixed Budget (BDT) *'
                      : 'Hourly Rate (BDT) *',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                onChanged: (v) => budget = v.trim(),
              ),
              const SizedBox(height: 16),

              // Deadline
              ListTile(
                title: Text(
                  deadline == null
                      ? 'Project Deadline *'
                      : 'Deadline: ${deadline!.toLocal().toString().split(' ')[0]}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => deadline = picked);
                },
              ),
              if (deadline == null)
                const Text(
                  '⚠️ Select deadline',
                  style: TextStyle(color: Colors.red),
                ),

              const SizedBox(height: 32),

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
                          if (!_formKey.currentState!.validate() ||
                              requiredSkills.length < 3 ||
                              deadline == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Complete all fields'),
                              ),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            final clientSnap = await userDoc.get();
                            final clientData = clientSnap.data()!;

                            await FirebaseFirestore.instance
                                .collection('jobs')
                                .add({
                                  'title': title,
                                  'description': description,
                                  'requiredSkills': requiredSkills,
                                  'budgetType': budgetType,
                                  'budget': int.parse(budget),
                                  'deadline': Timestamp.fromDate(deadline!),
                                  'clientId': auth.currentUser!.uid,
                                  'clientName': clientData['name'],
                                  'clientPhotoUrl': clientData['photoUrl'],
                                  'isClientVerified':
                                      clientData['isVerified'] == true,
                                  'postedAt': FieldValue.serverTimestamp(),
                                  'status': 'open',
                                  'applicants': [],
                                  'proposalsCount':
                                      0, // initialize proposals counter
                                });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Job posted successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Post Job',
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
