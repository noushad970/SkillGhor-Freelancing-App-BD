// lib/screens/messages_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'advanced_chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Row(
            children: const [
              Icon(Icons.chat_bubble_outline, color: Colors.green),
              SizedBox(width: 8),
              Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        body: const Center(
          child: Text("Not signed in", style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Row(
          children: const [
            Icon(Icons.chat_bubble_outline, color: Colors.green),
            SizedBox(width: 8),
            Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: StreamBuilder<QuerySnapshot>(
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
            return Center(child: Text(snapshot.error.toString()));
          }

          final rooms = snapshot.data?.docs ?? [];

          if (rooms.isEmpty) {
            // Fallback: try to find chat rooms directly under chat_rooms where this user is a participant
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .where('participants', arrayContains: uid)
                  .get(),
              builder: (context, snapRooms) {
                if (snapRooms.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapRooms.hasError) {
                  return Center(child: Text(snapRooms.error.toString()));
                }

                final direct = snapRooms.data?.docs ?? [];
                if (direct.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mark_chat_unread_outlined,
                          size: 90,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "No conversations yet",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start chatting with freelancers or clients.",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: direct.length,
                  itemBuilder: (context, index) {
                    final d = direct[index].data() as Map<String, dynamic>;
                    final participants = List<String>.from(
                      d['participants'] ?? [],
                    );
                    final peerId = participants.firstWhere(
                      (e) => e != uid,
                      orElse: () => '',
                    );
                    final participantNames =
                        (d['participantNames'] ?? {}) as Map<String, dynamic>;
                    final peerName =
                        (participantNames[peerId] ?? 'User') as String;
                    final lastMessage = (d['lastMessage'] ?? '') as String;
                    final jobId = d['jobId'];

                    int unread = 0; // unread unknown in chat_rooms fallback

                    String time = '';
                    if (d['updatedAt'] != null) {
                      final DateTime date = (d['updatedAt'] as Timestamp)
                          .toDate();
                      time =
                          "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    }

                    return _buildConversationTile(
                      context,
                      peerId,
                      peerName,
                      lastMessage,
                      jobId,
                      unread,
                      time,
                    );
                  },
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final r = rooms[index].data() as Map<String, dynamic>;

              final peerId = (r['peerId'] ?? '') as String;
              final peerName = (r['peerName'] ?? 'User') as String;
              final lastMessage = (r['lastMessage'] ?? '') as String;
              final jobId = r['jobId'];

              final int unread = (r['unreadCount'] ?? 0) as int;

              String time = '';
              if (r['updatedAt'] != null) {
                final DateTime date = (r['updatedAt'] as Timestamp).toDate();
                time =
                    "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
              }

              return _buildConversationTile(
                context,
                peerId,
                peerName,
                lastMessage,
                jobId,
                unread,
                time,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    String peerId,
    String peerName,
    String lastMessage,
    dynamic jobId,
    int unread,
    String time,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdvancedChatScreen(
                  otherUserId: peerId,
                  otherUserName: peerName,
                  jobId: jobId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green.shade100,
                  child: _PeerAvatar(peerId: peerId, fallbackName: peerName),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _PeerNameText(
                              peerId: peerId,
                              fallback: peerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (jobId != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.work_outline,
                                size: 15,
                                color: Colors.green.shade600,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty
                                  ? "Start conversation"
                                  : lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// helper widgets
class _PeerNameText extends StatelessWidget {
  final String peerId;
  final String? fallback;
  final TextStyle? style;

  const _PeerNameText({
    super.key,
    required this.peerId,
    this.fallback,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (fallback != null && fallback!.isNotEmpty && fallback! != 'User') {
      return Text(fallback!, style: style);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(peerId).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Text(fallback ?? 'User', style: style);
        }
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>?;
          final name = (data?['name'] ?? fallback ?? 'User').toString();
          return Text(name, style: style);
        }
        return Text(fallback ?? 'User', style: style);
      },
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final String peerId;
  final String? fallbackName;
  const _PeerAvatar({super.key, required this.peerId, this.fallbackName});

  @override
  Widget build(BuildContext context) {
    if (fallbackName != null &&
        fallbackName!.isNotEmpty &&
        fallbackName! != 'User') {
      final ch = fallbackName![0].toUpperCase();
      return Text(
        ch,
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(peerId).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Text(
            'U',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          );
        }
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>?;
          final name = (data?['name'] ?? '') as String;
          final ch = name.isNotEmpty ? name[0].toUpperCase() : 'U';
          return Text(
            ch,
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          );
        }
        return Text(
          'U',
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        );
      },
    );
  }
}
