// lib/screens/advanced_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class AdvancedChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? jobId;

  const AdvancedChatScreen({
    required this.otherUserId,
    required this.otherUserName,
    this.jobId,
    super.key,
  });

  @override
  State<AdvancedChatScreen> createState() => _AdvancedChatScreenState();
}

class _AdvancedChatScreenState extends State<AdvancedChatScreen> {
  late TextEditingController _messageController;
  late NotificationService _notificationService;
  late FirebaseFirestore _db;
  late FirebaseAuth _auth;
  late String _roomId;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _notificationService = NotificationService();
    _db = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _initializeChat();
  }

  void _initializeChat() {
    final uid = _auth.currentUser!.uid;
    final userIds = [uid, widget.otherUserId];
    userIds.sort();
    _roomId = userIds.join('_');

    // Clear unread count for current user for this room when they open it
    try {
      _db
          .collection('user_chats')
          .doc(uid)
          .collection('rooms')
          .doc(_roomId)
          .set({'unreadCount': 0}, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final uid = _auth.currentUser!.uid;
    final message = _messageController.text;
    _messageController.clear();

    try {
      final chatRef = _db.collection('chat_rooms').doc(_roomId);
      await chatRef.set({
        'roomId': _roomId,
        'participants': [uid, widget.otherUserId],
        'participantNames': {uid: '', widget.otherUserId: widget.otherUserName},
        'jobId': widget.jobId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': message,
        'lastSenderId': uid,
      }, SetOptions(merge: true));

      // Add message
      await chatRef.collection('messages').add({
        'senderId': uid,
        'text': message,
        'fileUrl': null,
        'fileType': null,
        'createdAt': FieldValue.serverTimestamp(),
        'edited': false,
      });

      // Update user chats index for sender
      await _db
          .collection('user_chats')
          .doc(uid)
          .collection('rooms')
          .doc(_roomId)
          .set({
            'roomId': _roomId,
            'peerId': widget.otherUserId,
            'peerName': widget.otherUserName,
            'jobId': widget.jobId,
            'lastMessage': message,
            'updatedAt': FieldValue.serverTimestamp(),
            'unreadCount': 0,
          }, SetOptions(merge: true));

      // Update user chats index for recipient and increment their unread count
      try {
        final senderName = _auth.currentUser!.displayName ?? '';
        await _db
            .collection('user_chats')
            .doc(widget.otherUserId)
            .collection('rooms')
            .doc(_roomId)
            .set({
              'roomId': _roomId,
              'peerId': uid,
              'peerName': senderName,
              'jobId': widget.jobId,
              'lastMessage': message,
              'updatedAt': FieldValue.serverTimestamp(),
              // increment unread for recipient
              'unreadCount': FieldValue.increment(1),
            }, SetOptions(merge: true));
      } catch (_) {
        // ignore failures to update recipient index
      }

      // Notify recipient
      await _notificationService.notifyMessageReceived(
        userId: widget.otherUserId,
        senderName: _auth.currentUser!.displayName ?? 'Someone',
        message: message,
        jobId: widget.jobId,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    }
  }

  void _showFileOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Send Image'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image upload coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_present),
            title: const Text('Send File'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File upload coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.request_quote),
            title: const Text('Send Milestone Invoice'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoice creation coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            if (widget.jobId != null)
              FutureBuilder<DocumentSnapshot>(
                future: _db.collection('jobs').doc(widget.jobId).get(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final job = snapshot.data!.data() as Map<String, dynamic>;
                    return Text(
                      'Job: ${job['title'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                    );
                  }
                  return const SizedBox();
                },
              ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('chat_rooms')
                  .doc(_roomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == _auth.currentUser!.uid;

                    return ChatBubble(
                      message: msg['text'] ?? '',
                      isMe: isMe,
                      timestamp: msg['createdAt'] as Timestamp?,
                      fileUrl: msg['fileUrl'],
                      fileType: msg['fileType'],
                    );
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.grey.shade300, blurRadius: 4),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _showFileOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.green.shade600,
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

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final Timestamp? timestamp;
  final String? fileUrl;
  final String? fileType;

  const ChatBubble({
    required this.message,
    required this.isMe,
    this.timestamp,
    this.fileUrl,
    this.fileType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.green.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      timestamp!.toDate().toString().split('.')[0],
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                  if (fileUrl != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.2)
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFileIcon(fileType),
                            size: 16,
                            color: isMe ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Download',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      default:
        return Icons.attachment;
    }
  }
}
