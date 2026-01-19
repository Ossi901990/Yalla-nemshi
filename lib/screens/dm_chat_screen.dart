import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/dm_thread_service.dart';

class DmChatScreenArgs {
  const DmChatScreenArgs({
    required this.threadId,
    required this.friendUid,
    required this.friendName,
    this.friendPhotoUrl,
  });

  final String threadId;
  final String friendUid;
  final String friendName;
  final String? friendPhotoUrl;
}

class DmChatScreen extends StatelessWidget {
  const DmChatScreen({super.key, required this.args});

  static const routeName = '/dm-chat';

  final DmChatScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  args.friendPhotoUrl != null && args.friendPhotoUrl!.isNotEmpty
                      ? NetworkImage(args.friendPhotoUrl!)
                      : null,
              child: (args.friendPhotoUrl == null || args.friendPhotoUrl!.isEmpty)
                  ? Text(args.friendName.isNotEmpty
                      ? args.friendName.substring(0, 1).toUpperCase()
                      : '?')
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                args.friendName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DmThreadService.watchMessages(args.threadId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Chat error: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Say hi to start the chat.'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderId = (data['senderId'] ?? '') as String;
                    final text = (data['text'] ?? '') as String;
                    final mediaUrl = (data['mediaUrl'] ?? '') as String;
                    final mediaType = (data['mediaType'] ?? '') as String;
                    final isMe = currentUid != null && senderId == currentUid;
                    final hasImage =
                        mediaUrl.isNotEmpty && mediaType.toLowerCase() == 'image';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                          color: isMe
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha((0.12 * 255).round())
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha((0.6 * 255).round()),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasImage)
                              _DmImageBubble(
                                imageUrl: mediaUrl,
                              ),
                            if (hasImage && text.isNotEmpty)
                              const SizedBox(height: 8),
                            if (text.isNotEmpty)
                              Text(
                                text,
                                softWrap: true,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _DmMessageComposer(threadId: args.threadId),
        ],
      ),
    );
  }
}

class _DmMessageComposer extends StatefulWidget {
  const _DmMessageComposer({required this.threadId});

  final String threadId;

  @override
  State<_DmMessageComposer> createState() => _DmMessageComposerState();
}

class _DmMessageComposerState extends State<_DmMessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _sending = false;
  bool _uploadingAttachment = false;

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final text = _controller.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (uid == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await DmThreadService.sendMessage(
        threadId: widget.threadId,
        senderUid: uid,
        text: text,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to send DM text: $error\n$stackTrace');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Message failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _uploadingAttachment) return;

    final source = await _selectImageSource();
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingAttachment = true);
    try {
      await DmThreadService.sendImageMessage(
        threadId: widget.threadId,
        senderUid: uid,
        file: file,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<ImageSource?> _selectImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pick from gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Use camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _uploadingAttachment ? null : _pickAndSendImage,
                icon: _uploadingAttachment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_outlined),
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

class _DmImageBubble extends StatelessWidget {
  const _DmImageBubble({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return GestureDetector(
      onTap: () => _showImageViewer(context, imageUrl),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha((0.4 * 255).round()),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.errorContainer,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            },
          ),
        ),
      ),
    );
  }
}

void _showImageViewer(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      );
    },
  );
}
