// lib/screens/walk_chat_screen.dart
//
// Walk group chat. Firestore logic lives here; the layout is the shared
// ChatView (lib/widgets/chat/chat_view.dart).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_features.dart';
import '../models/walk_event.dart';
import '../services/notification_sender.dart';
import '../theme/app_palette.dart';
import '../widgets/chat/chat_view.dart';

class WalkChatScreen extends StatefulWidget {
  const WalkChatScreen({
    super.key,
    required this.walkId,
    required this.walkTitle,
    this.memberNames = const {},
  });

  final String walkId;
  final String walkTitle;

  /// uid → name for the host and walkers, used for messages sent before
  /// messages carried the sender's name.
  final Map<String, String> memberNames;

  /// Names known from the walk itself (host + joined walkers).
  static Map<String, String> namesOf(WalkEvent walk) => {
    for (var i = 0; i < walk.joinedUserUids.length; i++)
      if (i < walk.joinedUserNames.length &&
          walk.joinedUserNames[i].trim().isNotEmpty)
        walk.joinedUserUids[i]: walk.joinedUserNames[i].trim(),
    if ((walk.hostName ?? '').trim().isNotEmpty)
      walk.hostUid: walk.hostName!.trim(),
  };

  @override
  State<WalkChatScreen> createState() => _WalkChatScreenState();
}

class _WalkChatScreenState extends State<WalkChatScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      FirebaseFirestore.instance.collection('walk_chats').doc(widget.walkId);

  Future<void> _send(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final msgRef = _chatRef.collection('messages').doc();
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, {
          'senderId': user.uid,
          // Shown above the message in the group chat.
          'senderName': (user.displayName ?? '').trim(),
          'text': text,
          'sentAt': FieldValue.serverTimestamp(),
          'deleted': false,
        });
        tx.set(_chatRef, {
          'walkId': widget.walkId,
          'lastMessage': text,
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      unawaited(
        NotificationSender.walkChatMessage(walkId: widget.walkId, text: text),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Message failed: $e')));
      }
    }
  }

  /// Needs Storage (paid plan); hidden while AppFeatures.photoUploads is off.
  Future<void> _pickAndSendImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _uploading) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'walk_chats/${widget.walkId}/images/'
        '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg',
      );
      await storageRef.putData(
        await picked.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final imageUrl = await storageRef.getDownloadURL();
      final msgRef = _chatRef.collection('messages').doc();
      final walkDocRef = FirebaseFirestore.instance
          .collection('walks')
          .doc(widget.walkId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, {
          'senderId': user.uid,
          'senderName': (user.displayName ?? '').trim(),
          'imageUrl': imageUrl,
          'sentAt': FieldValue.serverTimestamp(),
          'deleted': false,
        });
        tx.set(_chatRef, {
          'walkId': widget.walkId,
          'lastMessage': '[Image]',
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // Chat photos also appear in the walk's photo gallery.
        tx.set(walkDocRef, {
          'photoUrls': FieldValue.arrayUnion([imageUrl]),
        }, SetOptions(merge: true));
      });
      unawaited(
        NotificationSender.walkChatMessage(
          walkId: widget.walkId,
          text: '📷 Photo',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _confirmDelete(ChatMessage m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'It will show as "Message deleted" for everyone. '
          'Moderators can still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _chatRef.collection('messages').doc(m.id).update({
                  'deleted': true,
                });
              } catch (e) {
                if (mounted) {
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatRef
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final messages = [
          for (final doc in snapshot.data?.docs ?? const [])
            _toMessage(doc.id, doc.data()),
        ];
        return ChatView(
          title: widget.walkTitle,
          subtitle: 'Group chat',
          leading: const _WalkBadge(),
          messages: messages,
          currentUid: uid,
          showSenderNames: true,
          loading: !snapshot.hasData && !snapshot.hasError,
          error: snapshot.hasError ? '${snapshot.error}' : null,
          emptyTitle: 'Say hi to the group',
          emptyText:
              'Everyone on this walk can read this chat. '
              'Handy for "running 5 minutes late" or "meet at the gate".',
          onBack: () => Navigator.of(context).pop(),
          onSend: _send,
          onAttach: AppFeatures.photoUploads ? _pickAndSendImage : null,
          attaching: _uploading,
          onLongPressMine: _confirmDelete,
          onOpenImage: (url) => showChatImage(context, url),
        );
      },
    );
  }

  ChatMessage _toMessage(String id, Map<String, dynamic> data) {
    final senderId = (data['senderId'] ?? '') as String;
    final stored = (data['senderName'] as String?)?.trim() ?? '';
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderName: stored.isNotEmpty ? stored : widget.memberNames[senderId],
      text: (data['text'] ?? '') as String,
      imageUrl: data['imageUrl'] as String?,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      deleted: data['deleted'] == true,
    );
  }
}

class _WalkBadge extends StatelessWidget {
  const _WalkBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: const BoxDecoration(
      color: AppPalette.lime,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.directions_walk_rounded,
      color: AppPalette.ink,
      size: 24,
    ),
  );
}

/// Full-screen view of a chat photo; tap to close.
void showChatImage(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: InteractiveViewer(
        child: GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
