// lib/services/notification_sender.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'crash_service.dart';

/// Writes in-app notifications into other users' `users/{uid}/notifications`.
///
/// On the free Spark plan there are no Cloud Functions, so the client that
/// causes an event notifies the affected users itself. Security rules
/// (`isValidPeerNotification` in firestore.rules) only accept a notification
/// when the sender really is connected to the recipient through that walk or
/// DM, and the recipient hasn't blocked them.
///
/// These are in-app only (notifications screen + badge). Phone push needs
/// Cloud Functions (Blaze plan); see docs/HANDOFF.md.
///
/// Sending never throws: a failed notification must not undo the action.
class NotificationSender {
  NotificationSender._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _expiry = Duration(days: 30);
  static const _maxTitle = 120;
  static const _maxMessage = 300;

  static String? get _me => FirebaseAuth.instance.currentUser?.uid;

  static String get _myName {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return (name == null || name.isEmpty) ? 'Someone' : name;
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  static Future<void> _send({
    required Iterable<String> recipients,
    required String type,
    required String title,
    required String message,
    String? walkId,
    String? threadId,
    Map<String, dynamic>? data,
  }) async {
    final me = _me;
    if (me == null) return;
    final targets = recipients.where((uid) => uid.isNotEmpty && uid != me).toSet();
    if (targets.isEmpty) return;

    final payload = <String, dynamic>{
      'type': type,
      'title': _clip(title, _maxTitle),
      'message': _clip(message, _maxMessage),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'userId': me,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(_expiry)),
      if (walkId != null) 'walkId': walkId,
      if (threadId != null) 'threadId': threadId,
      if (data != null) 'data': data,
    };

    // One write per recipient (not a batch) so a recipient who blocked the
    // sender only rejects their own copy.
    await Future.wait(
      targets.map((uid) async {
        try {
          await _db
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .add(payload);
        } catch (e, st) {
          debugPrint('⚠️ Notification $type to $uid not sent: $e');
          CrashService.recordError(e, st, reason: 'NotificationSender.$type');
        }
      }),
    );
  }

  /// Joiner → host.
  static Future<void> walkJoined({
    required String walkId,
    required String hostUid,
    required String walkTitle,
  }) => _send(
    recipients: [hostUid],
    type: 'walkJoined',
    title: 'New walker joined! 🎉',
    message: '$_myName joined your walk "$walkTitle"',
    walkId: walkId,
  );

  /// Leaver → host.
  static Future<void> walkLeft({
    required String walkId,
    required String hostUid,
    required String walkTitle,
  }) => _send(
    recipients: [hostUid],
    type: 'walkLeft',
    title: 'Walker left 👋',
    message: '$_myName left your walk "$walkTitle"',
    walkId: walkId,
  );

  /// Host → everyone who joined.
  static Future<void> walkCancelled({
    required String walkId,
    required String walkTitle,
    required Iterable<String> participantUids,
  }) => _send(
    recipients: participantUids,
    type: 'walkCancelled',
    title: 'Walk cancelled ❌',
    message: 'The walk "$walkTitle" has been cancelled',
    walkId: walkId,
  );

  /// Host → everyone who joined.
  static Future<void> walkStarting({
    required String walkId,
    required String walkTitle,
    required Iterable<String> participantUids,
  }) => _send(
    recipients: participantUids,
    type: 'walkStarting',
    title: 'Walk starting ⏰',
    message: '"$walkTitle" - Please confirm you’re joining',
    walkId: walkId,
  );

  /// Sender → the other walk members (host + joined).
  static Future<void> walkChatMessage({
    required String walkId,
    required String text,
  }) async {
    try {
      final snap = await _db.collection('walks').doc(walkId).get();
      final walk = snap.data();
      if (walk == null) return;
      final members = <String>{
        if (walk['hostUid'] is String) walk['hostUid'] as String,
        ...((walk['joinedUserUids'] as List?) ?? const []).whereType<String>(),
      };
      final title = (walk['title'] as String?)?.trim();
      await _send(
        recipients: members,
        type: 'walkChatMessage',
        title: '$_myName • ${title == null || title.isEmpty ? 'Walk' : title}',
        message: text,
        walkId: walkId,
      );
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'NotificationSender.chat');
    }
  }

  /// Sender → the other DM participant.
  static Future<void> dmMessage({
    required String threadId,
    required String preview,
  }) async {
    try {
      final snap = await _db.collection('dm_threads').doc(threadId).get();
      final participants =
          ((snap.data()?['participants'] as List?) ?? const [])
              .whereType<String>();
      final photo = FirebaseAuth.instance.currentUser?.photoURL;
      await _send(
        recipients: participants,
        type: 'dmMessage',
        title: _myName,
        message: preview,
        threadId: threadId,
        data: {if (photo != null && photo.isNotEmpty) 'senderPhotoUrl': photo},
      );
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'NotificationSender.dm');
    }
  }
}
