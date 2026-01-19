import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class DmThreadService {
  DmThreadService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _collection = 'dm_threads';

  static String buildThreadId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  static DocumentReference<Map<String, dynamic>> _threadRef(String threadId) {
    return _firestore.collection(_collection).doc(threadId);
  }

  static Future<String> ensureThread({
    required String currentUid,
    required String friendUid,
    String? currentDisplayName,
    String? friendDisplayName,
    String? friendPhotoUrl,
  }) async {
    final threadId = buildThreadId(currentUid, friendUid);
    final ref = _threadRef(threadId);
    final participantProfiles = <String, Map<String, dynamic>>{};
    final participantIds = [currentUid, friendUid]..sort();

    Map<String, dynamic> participantPayload(String? name, {String? photoUrl}) {
      final payload = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) {
        payload['displayName'] = name.trim();
      }
      if (photoUrl != null && photoUrl.isNotEmpty) {
        payload['photoUrl'] = photoUrl;
      }
      return payload;
    }

    participantProfiles[currentUid] = participantPayload(currentDisplayName);
    participantProfiles[friendUid] = participantPayload(
      friendDisplayName,
      photoUrl: friendPhotoUrl,
    );

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final payload = <String, dynamic>{
        'threadId': threadId,
        'participants': participantIds,
        'participantProfiles': participantProfiles,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
      tx.set(ref, payload, SetOptions(merge: true));
    });

    return threadId;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
    String threadId,
  ) {
    return _threadRef(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<void> sendMessage({
    required String threadId,
    required String senderUid,
    String? text,
    String? mediaUrl,
    String? mediaPath,
    String? mediaType,
    int? mediaSizeBytes,
    String type = 'text',
  }) async {
    final trimmed = (text ?? '').trim();
    if (trimmed.isEmpty && mediaUrl == null) return;

    final threadRef = _threadRef(threadId);
    final messageRef = threadRef.collection('messages').doc();

    await _firestore.runTransaction((tx) async {
      final normalizedType = (type.isNotEmpty ? type : (mediaUrl != null ? 'image' : 'text')).toLowerCase();
      final payload = <String, dynamic>{
        'senderId': senderUid,
        'type': normalizedType,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (trimmed.isNotEmpty) {
        payload['text'] = trimmed;
      }
      if (mediaUrl != null) {
        payload['mediaUrl'] = mediaUrl;
        if (mediaPath != null) payload['mediaPath'] = mediaPath;
        if (mediaType != null) payload['mediaType'] = mediaType;
        if (mediaSizeBytes != null) payload['mediaSizeBytes'] = mediaSizeBytes;
      }

      tx.set(messageRef, payload);

        final preview = trimmed.isNotEmpty
          ? trimmed
          : (normalizedType == 'image' ? '📷 Photo' : 'Attachment');

      tx.set(
        threadRef,
        {
          'lastMessage': preview,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': senderUid,
        },
        SetOptions(merge: true),
      );
    });
  }

  static Future<void> sendImageMessage({
    required String threadId,
    required String senderUid,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    final safeExtension = _extensionFor(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    final storagePath =
        'dm_media/$threadId/${senderUid}_$timestamp$random.$safeExtension';

    final metadata = SettableMetadata(
      contentType: file.mimeType ?? 'image/jpeg',
    );

    final ref = _storage.ref(storagePath);
    await ref.putData(bytes, metadata);
    final downloadUrl = await ref.getDownloadURL();

    await sendMessage(
      threadId: threadId,
      senderUid: senderUid,
      mediaUrl: downloadUrl,
      mediaPath: storagePath,
      mediaType: 'image',
      mediaSizeBytes: bytes.length,
      type: 'image',
    );
  }

  static String _extensionFor(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return 'jpg';
    }
    final ext = path.substring(dotIndex + 1).toLowerCase();
    final sanitized = ext.replaceAll(RegExp('[^a-z0-9]'), '');
    return sanitized.isEmpty ? 'jpg' : sanitized;
  }
}
