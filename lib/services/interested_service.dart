// lib/services/interested_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'crash_service.dart';

/// Walks the signed-in user marked as "interested" (the ☆ on walk details).
///
/// Stored per user at `users/{uid}/interested/{walkId}` so it survives app
/// restarts and syncs across devices. Only the owner can read or write it
/// (firestore.rules).
class InterestedService {
  InterestedService._();
  static final InterestedService instance = InterestedService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('interested');
  }

  /// Live set of walk ids the user is interested in.
  Stream<Set<String>> watchIds() {
    final col = _col();
    if (col == null) return Stream.value(const <String>{});
    return col.snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<void> set(String walkId, bool interested) async {
    final col = _col();
    if (col == null || walkId.isEmpty) return;
    try {
      if (interested) {
        await col.doc(walkId).set({
          'walkId': walkId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await col.doc(walkId).delete();
      }
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'InterestedService.set');
      rethrow;
    }
  }
}
