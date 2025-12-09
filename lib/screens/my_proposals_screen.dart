// lib/screens/my_proposals_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyProposalsScreen extends StatelessWidget {
  const MyProposalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('My Proposals')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('applicants', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No proposals yet'));
          }

          final proposals = snapshot.data!.docs;

          return ListView.builder(
            itemCount: proposals.length,
            itemBuilder: (context, index) {
              final job = proposals[index].data() as Map<String, dynamic>;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(job['title']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
