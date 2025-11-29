import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'freelancer_profile_screen.dart';
import 'client_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firebaseUser = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your role')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Are you hiring or offering services?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to client onboarding
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientProfileScreen(uid: firebaseUser.uid),
                  ),
                );
              },
              child: const Text('I want to hire (Client)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FreelancerProfileScreen(uid: firebaseUser.uid),
                  ),
                );
              },
              child: const Text('I am a freelancer'),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await auth.signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
