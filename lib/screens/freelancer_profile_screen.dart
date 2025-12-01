import 'package:flutter/material.dart';

class FreelancerProfileScreen extends StatelessWidget {
  const FreelancerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Freelancer Dashboard')),
      body: const Center(
        child: Text(
          'Welcome Freelancer! 👨‍💻\nFind Jobs & Build Profile',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
