// lib/screens/walk_chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class WalkChatScreen extends StatelessWidget {
  final String walkId;
  final String walkTitle;

  const WalkChatScreen({
    super.key,
    required this.walkId,
    required this.walkTitle,
  });

  void _showDeleteDialog(BuildContext context, String walkId, String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message? It will show as "[Message deleted]" but moderators can still see it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('walk_chats')
                    .doc(walkId)
                    .collection('messages')
                    .doc(messageId)
                    .update({'deleted': true});
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(walkTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  return Center(child: Text('Chat error: ${snapshot.error}'));
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final messageId = docs[index].id;

                    final senderId = (data['senderId'] ?? '') as String;
                    final text = (data['text'] ?? '') as String;
                    final imageUrl = (data['imageUrl'] ?? '') as String?;
                    final isMe = uid != null && senderId == uid;
                    final isDeleted = data['deleted'] == true;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMe && !isDeleted
                            ? () => _showDeleteDialog(context, walkId, messageId)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isDeleted
                                ? Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.3 * 255).round())
                                : isMe
                                    ? Theme.of(context).colorScheme.primary.withAlpha((0.12 * 255).round())
                                    : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.6 * 255).round()),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: isDeleted
                              ? Text(
                                  '[Message deleted]',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context).colorScheme.onSurface.withAlpha((0.5 * 255).round()),
                                  ),
                                )
                              : imageUrl != null && imageUrl.isNotEmpty
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Image.network(
                                          imageUrl,
                                          width: 180,
                                          height: 180,
                                          fit: BoxFit.cover,
                                        ),
                                        if (text.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              text,
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ),
                                      ],
                                    )
                                  : Text(
                                      text,
                                      softWrap: true,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
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
  final ImagePicker _picker = ImagePicker();

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final text = _controller.text.trim();

    if (uid == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    final chatRef = FirebaseFirestore.instance
        .collection('walk_chats')
        .doc(widget.walkId);
    final msgRef = chatRef.collection('messages').doc();

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, {
          'senderId': uid,
          'text': text,
          'sentAt': FieldValue.serverTimestamp(),
          'deleted': false,
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

  Future<void> pickAndSendImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _sending) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final file = picked;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('walk_chats/${widget.walkId}/images/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
      await storageRef.putData(await file.readAsBytes());
      final imageUrl = await storageRef.getDownloadURL();

      final chatRef = FirebaseFirestore.instance
          .collection('walk_chats')
          .doc(widget.walkId);
      final msgRef = chatRef.collection('messages').doc();

      // Reference to the walk document in 'walks' collection
      final walkDocRef = FirebaseFirestore.instance.collection('walks').doc(widget.walkId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, {
          'senderId': uid,
          'imageUrl': imageUrl,
          'sentAt': FieldValue.serverTimestamp(),
          'deleted': false,
        });
        tx.set(chatRef, {
          'walkId': widget.walkId,
          'lastMessage': '[Image]',
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // Add imageUrl to the walk's photoUrls array (if not already present)
        tx.set(walkDocRef, {
          'photoUrls': FieldValue.arrayUnion([imageUrl]),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
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
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.photo),
                tooltip: 'Send Image',
                onPressed: _sending ? null : pickAndSendImage,
              ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
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
      ),
    );
  }
}

