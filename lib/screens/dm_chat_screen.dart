// lib/screens/dm_chat_screen.dart
//
// Direct messages with a friend. Firestore logic lives in DmThreadService;
// the layout is the shared ChatView (lib/widgets/chat/chat_view.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_features.dart';
import '../models/app_exception.dart';
import '../services/dm_thread_service.dart';
import '../widgets/chat/chat_view.dart';
import '../widgets/user_avatar.dart';
import 'walk_chat_screen.dart' show showChatImage;

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

class DmChatScreen extends StatefulWidget {
  const DmChatScreen({super.key, required this.args});

  static const routeName = '/dm-chat';

  final DmChatScreenArgs args;

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _send(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DmThreadService.sendMessage(
        threadId: widget.args.threadId,
        senderUid: uid,
        text: text,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to send DM text: $error\n$stackTrace');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is AppException ? error.message : 'Message failed: $error',
          ),
        ),
      );
    }
  }

  /// Needs Storage (paid plan); hidden while AppFeatures.photoUploads is off.
  Future<void> _pickAndSendImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _uploading) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
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
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      await DmThreadService.sendImageMessage(
        threadId: widget.args.threadId,
        senderUid: uid,
        file: file,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DmThreadService.watchMessages(args.threadId),
      builder: (context, snapshot) {
        final messages = [
          for (final doc in snapshot.data?.docs ?? const [])
            _toMessage(doc.id, doc.data()),
        ];
        return ChatView(
          title: args.friendName,
          subtitle: 'Direct message',
          leading: UserAvatar(
            radius: 22,
            name: args.friendName,
            photoUrl: args.friendPhotoUrl,
          ),
          messages: messages,
          currentUid: uid,
          loading: !snapshot.hasData && !snapshot.hasError,
          error: snapshot.hasError ? '${snapshot.error}' : null,
          emptyTitle: 'Say hi to ${args.friendName.split(' ').first}',
          emptyText:
              'Plan your next walk together. Only the two of you can '
              'see this chat.',
          onBack: () => Navigator.of(context).pop(),
          onSend: _send,
          onAttach: AppFeatures.photoUploads ? _pickAndSendImage : null,
          attaching: _uploading,
          onOpenImage: (url) => showChatImage(context, url),
        );
      },
    );
  }

  static ChatMessage _toMessage(String id, Map<String, dynamic> data) {
    final mediaUrl = (data['mediaUrl'] ?? '') as String;
    final isImage =
        mediaUrl.isNotEmpty &&
        ((data['mediaType'] ?? '') as String).toLowerCase() == 'image';
    return ChatMessage(
      id: id,
      senderId: (data['senderId'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      imageUrl: isImage ? mediaUrl : null,
      sentAt:
          (data['sentAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
