// screens/freelancer_dashboard.dart
import 'package:flutter/material.dart';

class FreelancerDashboard extends StatelessWidget {
  const FreelancerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Jobs',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 100, color: Colors.green.shade400),
                  const SizedBox(height: 20),
                  const Text(
                    'Browse thousands of jobs',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Navigate to Job Listings
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Find Jobs'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
