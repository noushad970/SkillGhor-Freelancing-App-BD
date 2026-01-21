// lib/screens/messages_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_room_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_chats')
                  .doc(uid)
                  .collection('rooms')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final rooms = snapshot.data?.docs ?? const [];
                if (rooms.isEmpty) {
                  return const Center(child: Text('No conversations yet'));
                }
                return ListView.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final r = rooms[index].data() as Map<String, dynamic>;
                    final peerId = r['peerId'] as String? ?? '';
                    final peerName = r['peerName'] as String? ?? 'User';
                    final lastMessage = r['lastMessage'] as String? ?? '';
                    final jobId = r['jobId'] as String?;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        peerName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: jobId != null
                          ? const Icon(Icons.work_outline)
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              otherUserId: peerId,
                              otherUserName: peerName,
                              jobId: jobId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
