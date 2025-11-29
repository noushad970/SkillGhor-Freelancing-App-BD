import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ClientProfileScreen extends StatefulWidget {
  final String uid;
  const ClientProfileScreen({super.key, required this.uid});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _aboutController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _companyController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Client profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company / Personal Name',
                ),
              ),
              TextFormField(
                controller: _aboutController,
                decoration: const InputDecoration(
                  labelText: 'About (what type of projects you post)',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _loading = true);
                        try {
                          await auth.setRoleAndOnboard(
                            uid: widget.uid,
                            role: 'client',
                            extraFields: {
                              'company_name': _companyController.text.trim(),
                              'about': _aboutController.text.trim(),
                            },
                          );
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
