import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final auth = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelance App - Home'),
        actions: [
          IconButton(
            onPressed: () async => await auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? {};
          final role = data['role'] ?? 'unknown';
          final verified = data['verified'] ?? false;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${data['name'] ?? user.email}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text('Role: $role'),
                Text('Verified: ${verified ? "Yes" : "No"}'),
                const SizedBox(height: 16),
                if (role == 'freelancer') ...[
                  const Text('Freelancer dashboard (placeholder)'),
                ] else if (role == 'client') ...[
                  const Text('Client dashboard (placeholder)'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
