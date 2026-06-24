// Deprecated legacy chat room screen.
// Replaced by lib/screens/advanced_chat_screen.dart.
// This file is kept as a harmless stub to avoid accidental import breakage during migration.

import 'package:flutter/material.dart';

class ChatRoomScreen extends StatelessWidget {
  const ChatRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deprecated Chat Screen'),
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'This legacy chat screen was replaced by AdvancedChatScreen.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Please update imports/usages to use AdvancedChatScreen in lib/screens/advanced_chat_screen.dart',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
