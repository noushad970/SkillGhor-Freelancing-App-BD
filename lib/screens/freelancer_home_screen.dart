// screens/freelancer_dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_ghor/screens/edit_profile_screen.dart';
import 'package:skill_ghor/screens/freelancer_edit_profile_screen.dart';

var connect = 0;

class FreelancerHomeScreen extends StatelessWidget {
  const FreelancerHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      // TOP HEADER (like Upwork)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'SkillGhor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),

      // MAIN BODY
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome + Profile Completion
            _buildWelcomeCard(context),
            const SizedBox(height: 20),

            // Quick Stats
            const SizedBox(height: 20),

            // Section Buttons
            _buildSectionCard(
              "Matched Jobs",
              Icons.auto_awesome,
              Colors.purple,
            ),
            _buildSectionCard("Recent Jobs", Icons.work_outline, Colors.blue),
            _buildSectionCard(
              "Saved Jobs",
              Icons.bookmark_border,
              Colors.orange,
            ),
            _buildSectionCard("My Proposals", Icons.send, Colors.teal),
            _buildSectionCard(
              "Active Contracts",
              Icons.handshake_outlined,
              Colors.green,
            ),
            _buildSectionCard(
              "Earnings & Reports",
              Icons.bar_chart,
              Colors.indigo,
            ),

            const SizedBox(height: 20),

            // Best Matches Section (Mini Job List Preview)
            _buildBestMatchesSection(),
          ],
        ),
      ),

      // BOTTOM NAVIGATION (like Upwork)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Find Work'),
          BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Proposals'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'User';
        final completion = data['profileCompletion'] ?? 0;
        final connects = data['connects'] ?? 20;
        final isVerified = data['isVerified'] == true;
        connect = connects;

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isVerified
                                    ? Icons.verified
                                    : Icons.verified_user_outlined,
                                color: isVerified ? Colors.blue : Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                          Text(
                            "Available Connects: $connects",
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: completion / 100,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation(
                                    completion >= 90
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "$completion% Complete",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FreelancerEditProfileScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit Profile"),
                    ),
                    if (!isVerified)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ID Verification coming soon!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text("Verify ID"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to respective screen
        },
      ),
    );
  }

  Widget _buildBestMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Best Matches",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          3,
          (index) => _buildJobCard(
            title: [
              "Flutter Developer Needed",
              "UI/UX Designer for Mobile App",
              "Backend Developer (Node.js)",
            ][index],
            budget: [
              "৳25,000 - ৳40,000",
              "Fixed: ৳15,000",
              "Hourly: ৳800/hr",
            ][index],
            posted: "2 hours ago",
            match: 95 - index * 5,
          ),
        ),
        TextButton(onPressed: () {}, child: const Text("View All Jobs →")),
      ],
    );
  }

  Widget _buildJobCard({
    required String title,
    required String budget,
    required String posted,
    required int match,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Chip(
                  backgroundColor: Colors.green.shade100,
                  label: Text(
                    "$match% Match",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              budget,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Posted $posted • 12 proposals",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
