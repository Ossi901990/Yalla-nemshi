// lib/screens/walk_chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalkChatScreen extends StatelessWidget {
  final String walkId;
  final String walkTitle;

  const WalkChatScreen({
    super.key,
    required this.walkId,
    required this.walkTitle,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(walkTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('walk_chats')
                  .doc(walkId)
                  .collection('messages')
                  .orderBy('sentAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final senderId = (data['senderId'] ?? '') as String;
                    final text = (data['text'] ?? '') as String;
                    final isMe = uid != null && senderId == uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input bar will come in the next step
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.4),
                ),
              ),
              child: const Text('Next step: message input + send button'),
            ),
          ),
        ],
      ),
    );
  }
}
