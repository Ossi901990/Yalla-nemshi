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
   _MessageComposer(walkId: walkId),

        ],
      ),
    );
  }
}
class _MessageComposer extends StatefulWidget {
  final String walkId;
  const _MessageComposer({required this.walkId});

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final text = _controller.text.trim();

    if (uid == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    final chatRef =
        FirebaseFirestore.instance.collection('walk_chats').doc(widget.walkId);
    final msgRef = chatRef.collection('messages').doc();

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, {
          'senderId': uid,
          'text': text,
          'sentAt': FieldValue.serverTimestamp(),
        });

        tx.set(chatRef, {
          'walkId': widget.walkId,
          'lastMessage': text,
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
