// lib/screens/client_edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ClientEditProfileScreen extends StatefulWidget {
  const ClientEditProfileScreen({super.key});
  @override
  State<ClientEditProfileScreen> createState() =>
      _ClientEditProfileScreenState();
}

class _ClientEditProfileScreenState extends State<ClientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String fullName, username, bio = '';
  String? country;
  String companyName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = Provider.of<AuthService>(
      context,
      listen: false,
    ).currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};

    setState(() {
      fullName = data['name'] ?? '';
      username = data['username'] ?? '';
      country = data['country'];
      bio = data['bio'] ?? '';
      companyName = data['companyName'] ?? '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || bio.length < 100) return;

    setState(() => _isLoading = true);
    try {
      final uid = Provider.of<AuthService>(
        context,
        listen: false,
      ).currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': fullName,
        'username': username,
        'country': country,
        'bio': bio,
        'companyName': companyName.isEmpty
            ? companyName
            : companyName, // one-time
        'profileCompletion': _calculateCompletion(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
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

  int _calculateCompletion() {
    int score = 0;
    if (fullName.isNotEmpty) score += 25;
    if (username.isNotEmpty) score += 15;
    if (country != null) score += 15;
    if (companyName.isNotEmpty) score += 25;
    if (bio.length >= 100) score += 20;
    return score > 100 ? 100 : score;
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = Provider.of<AuthService>(context).currentUser?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Client Profile'),
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
              const SizedBox(height: 24),

              TextFormField(
                initialValue: fullName,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                onChanged: (v) => fullName = v.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: username,
                decoration: const InputDecoration(labelText: 'Username *'),
                onChanged: (v) => username = v.trim().toLowerCase(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: country,
                decoration: const InputDecoration(labelText: 'Country *'),
                items: ['Bangladesh', 'India', 'USA', 'UK', 'Other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => country = v),
              ),
              const SizedBox(height: 24),

              // COMPANY NAME — ONE TIME ONLY
              TextFormField(
                initialValue: companyName,
                decoration: InputDecoration(
                  labelText: 'Company / Organization Name *',
                  hintText: companyName.isEmpty
                      ? 'e.g. ABC Corporation Ltd.'
                      : 'Already set (cannot change)',
                  enabled: companyName.isEmpty,
                ),
                onChanged: companyName.isEmpty
                    ? (v) => companyName = v.trim()
                    : null,
              ),
              if (companyName.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Company name is permanent',
                    style: TextStyle(color: Colors.green),
                  ),
                ),

              const SizedBox(height: 24),

              TextFormField(
                initialValue: bio,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'About Your Company * (100+ chars)',
                ),
                validator: (v) => v!.trim().length < 100
                    ? 'Minimum 100 characters required'
                    : null,
                onChanged: (v) => bio = v,
              ),
              Text(
                '${bio.length} chars',
                style: TextStyle(
                  color: bio.length >= 100 ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Changes',
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
