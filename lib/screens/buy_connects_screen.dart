// lib/screens/buy_connects_screen.dart
import 'package:flutter/material.dart';

class BuyConnectsScreen extends StatelessWidget {
  const BuyConnectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Connects - SkillGhor'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choose a Connects package',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment feature coming soon!')),
                );
              },
              child: const Text('Buy 20 Connects for ৳100'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment feature coming soon!')),
                );
              },
              child: const Text('Buy 50 Connects for ৳200'),
            ),
          ],
        ),
      ),
    );
  }
}
