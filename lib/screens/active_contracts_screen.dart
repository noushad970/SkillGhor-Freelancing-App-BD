// lib/screens/active_contracts_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveContractsScreen extends StatelessWidget {
  const ActiveContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Active Contracts')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('contracts')
            .where('freelancerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active contracts'));
          }

          final contracts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contract = contracts[index].data() as Map<String, dynamic>;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(contract['jobTitle']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
