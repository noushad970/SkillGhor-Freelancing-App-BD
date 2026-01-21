// lib/screens/chat_room_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatRoomScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? jobId;

  const ChatRoomScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.jobId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String get _roomId {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ids = [uid, widget.otherUserId]..sort();
    return ids.join('_');
  }

  CollectionReference get _rooms =>
      FirebaseFirestore.instance.collection('chat_rooms');

  Future<void> _ensureChatHeader() async {
    final me = FirebaseAuth.instance.currentUser!;
    final roomRef = _rooms.doc(_roomId);
    final snap = await roomRef.get();
    if (!snap.exists) {
      await roomRef.set({
        'roomId': _roomId,
        'participants': [me.uid, widget.otherUserId],
        'participantNames': {
          me.uid: me.displayName ?? 'User',
          widget.otherUserId: widget.otherUserName,
        },
        'jobId': widget.jobId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastSenderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    // per-user index
    final meIdx = FirebaseFirestore.instance
        .collection('user_chats')
        .doc(me.uid)
        .collection('rooms')
        .doc(_roomId);
    final otherIdx = FirebaseFirestore.instance
        .collection('user_chats')
        .doc(widget.otherUserId)
        .collection('rooms')
        .doc(_roomId);
    await meIdx.set({
      'roomId': _roomId,
      'peerId': widget.otherUserId,
      'peerName': widget.otherUserName,
      'jobId': widget.jobId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await otherIdx.set({
      'roomId': _roomId,
      'peerId': me.uid,
      'peerName': me.displayName ?? 'User',
      'jobId': widget.jobId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final roomRef = _rooms.doc(_roomId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final msgRef = roomRef.collection('messages').doc();
      tx.set(msgRef, {
        'senderId': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(roomRef, {
        'lastMessage': text,
        'lastSenderId': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'jobId': widget.jobId,
      }, SetOptions(merge: true));
      // update indexes
      final me = FirebaseAuth.instance.currentUser!;
      tx.set(
        FirebaseFirestore.instance
            .collection('user_chats')
            .doc(me.uid)
            .collection('rooms')
            .doc(_roomId),
        {'lastMessage': text, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      tx.set(
        FirebaseFirestore.instance
            .collection('user_chats')
            .doc(widget.otherUserId)
            .collection('rooms')
            .doc(_roomId),
        {'lastMessage': text, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    });

    _messageCtrl.clear();
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureChatHeader();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _rooms
                  .doc(_roomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  controller: _scrollCtrl,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe =
                        msg['senderId'] ==
                        FirebaseAuth.instance.currentUser!.uid;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green.shade600
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
