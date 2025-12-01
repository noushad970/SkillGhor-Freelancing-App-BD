// screens/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'freelancer_dashboard.dart';
import 'client_dashboard.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FreelanceHub'),
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('User data not found'));
          }

          final data = snapshot.data!.data()!;
          final String name = data['name'] ?? user.displayName ?? 'User';
          final String role = data['role'] ?? 'unknown';
          final String photoUrl = data['photoUrl'] ?? user.photoURL;
          final bool verified = data['verified'] == true;

          return Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade600,
                      Colors.deepPurple.shade800,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                role == 'freelancer'
                                    ? Icons.code
                                    : Icons.business,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                role == 'freelancer' ? 'Freelancer' : 'Client',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.verified,
                                  color: Colors.cyan,
                                  size: 20,
                                ),
                                const Text(
                                  ' Verified',
                                  style: TextStyle(color: Colors.cyan),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Role-Based Dashboard
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: role == 'freelancer'
                      ? const FreelancerDashboard(key: ValueKey('freelancer'))
                      : role == 'client'
                      ? const ClientDashboard(key: ValueKey('client'))
                      : _buildRoleNotSelected(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleNotSelected(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.help_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No role selected yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // You can navigate to role selection again if needed
              Navigator.pushReplacementNamed(context, '/role-selection');
            },
            child: const Text('Choose Your Role'),
          ),
        ],
      ),
    );
  }
}
