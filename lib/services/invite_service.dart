import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum InviteErrorCode {
  expired,
  invalidCode,
  invalidInput,
  notFound,
  notPrivate,
  notAuthorized,
  unauthenticated,
  unknown,
}

class InviteException implements Exception {
  InviteException(this.code, this.message);

  final InviteErrorCode code;
  final String message;

  @override
  String toString() => 'InviteException($code): $message';
}

/// Private-walk invites, implemented with Firestore security rules only (no
/// Cloud Functions, so it works on the free Spark plan).
///
/// Data model:
/// - invite_codes/{CODE}          {walkId, hostUid, expiresAt}  (get-only; knowing
///                                 the code is what grants access)
/// - walks/{id}/private/invite    {shareCode, shareCodeExpiresAt}  (host-only)
/// - walks/{id}/allowed/{uid}     written by the user redeeming; rules verify
///                                 the code matches the walk and isn't expired
class InviteService {
  InviteService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>> codeRef(
    FirebaseFirestore firestore,
    String code,
  ) =>
      firestore.collection('invite_codes').doc(code.trim().toUpperCase());

  /// Redeems a private walk invite and returns the walk id.
  ///
  /// [walkId] is optional: when omitted the walk is looked up by [shareCode]
  /// alone (used by "enter invite code" search).
  Future<String> redeemInvite({
    String? walkId,
    required String shareCode,
  }) async {
    final trimmedWalkId = (walkId ?? '').trim();
    final trimmedCode = shareCode.trim().toUpperCase();

    if (trimmedCode.isEmpty ||
        (walkId != null && trimmedWalkId.isEmpty) ||
        !RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(trimmedCode)) {
      throw InviteException(
        InviteErrorCode.invalidInput,
        'Enter a valid invite code.',
      );
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw InviteException(
        InviteErrorCode.unauthenticated,
        'Please sign in before redeeming an invite.',
      );
    }

    try {
      final codeSnap = await codeRef(_firestore, trimmedCode).get();
      final data = codeSnap.data();
      final codeWalkId = data?['walkId']?.toString() ?? '';

      if (!codeSnap.exists || codeWalkId.isEmpty) {
        throw InviteException(
          trimmedWalkId.isEmpty
              ? InviteErrorCode.notFound
              : InviteErrorCode.invalidCode,
          trimmedWalkId.isEmpty
              ? 'No walk found for that code.'
              : "That invite code doesn't match this walk.",
        );
      }

      if (trimmedWalkId.isNotEmpty && codeWalkId != trimmedWalkId) {
        throw InviteException(
          InviteErrorCode.invalidCode,
          "That invite code doesn't match this walk.",
        );
      }

      final expiresAt = data?['expiresAt'];
      if (expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        throw InviteException(
          InviteErrorCode.expired,
          'This invite expired. Ask the host to share a fresh link.',
        );
      }

      await _firestore
          .collection('walks')
          .doc(codeWalkId)
          .collection('allowed')
          .doc(uid)
          .set({
        'uid': uid,
        'walkId': codeWalkId,
        'code': trimmedCode,
        'redeemedAt': FieldValue.serverTimestamp(),
      });

      return codeWalkId;
    } on InviteException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw InviteException(
          InviteErrorCode.invalidCode,
          'This invite code is not valid any more.',
        );
      }
      throw InviteException(
        InviteErrorCode.unknown,
        'Unable to redeem invite right now. Please retry shortly.',
      );
    } catch (_) {
      throw InviteException(
        InviteErrorCode.unknown,
        'Something went wrong. Please try again.',
      );
    }
  }

  /// Host removes a user's redeemed invite (they lose access to the walk).
  Future<void> revokeInvite({
    required String walkId,
    required String userId,
  }) async {
    final trimmedWalkId = walkId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedWalkId.isEmpty || trimmedUserId.isEmpty) {
      throw InviteException(
        InviteErrorCode.invalidInput,
        'Missing walk or user information.',
      );
    }

    try {
      await _firestore
          .collection('walks')
          .doc(trimmedWalkId)
          .collection('allowed')
          .doc(trimmedUserId)
          .delete();
    } on FirebaseException catch (e) {
      throw InviteException(
        e.code == 'permission-denied'
            ? InviteErrorCode.notAuthorized
            : InviteErrorCode.unknown,
        e.code == 'permission-denied'
            ? 'You are not allowed to revoke invites for this walk.'
            : 'Unable to revoke invite right now. Please retry shortly.',
      );
    }
  }
}
