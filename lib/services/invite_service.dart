import 'package:cloud_functions/cloud_functions.dart';

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

class InviteService {
  InviteService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> redeemInvite({
    required String walkId,
    required String shareCode,
  }) async {
    final trimmedWalkId = walkId.trim();
    final trimmedCode = shareCode.trim().toUpperCase();

    if (trimmedWalkId.isEmpty || trimmedCode.isEmpty) {
      throw InviteException(
        InviteErrorCode.invalidInput,
        'Enter both the walk ID and invite code.',
      );
    }

    try {
      await _functions.httpsCallable('redeemInviteCode').call({
        'walkId': trimmedWalkId,
        'shareCode': trimmedCode,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _mapException(error);
    } catch (_) {
      throw InviteException(
        InviteErrorCode.unknown,
        'Something went wrong. Please try again.',
      );
    }
  }

  InviteException _mapException(FirebaseFunctionsException error) {
    final message = error.message ?? '';

    switch (error.code) {
      case 'unauthenticated':
        return InviteException(
          InviteErrorCode.unauthenticated,
          'Please sign in before redeeming an invite.',
        );
      case 'invalid-argument':
        return InviteException(
          InviteErrorCode.invalidInput,
          'Double-check the walk ID and invite code.',
        );
      case 'permission-denied':
        return InviteException(
          InviteErrorCode.invalidCode,
          "That invite code doesn't match this walk.",
        );
      case 'not-found':
        return InviteException(
          InviteErrorCode.notFound,
          'Walk not found. Ask the host to confirm the walk ID.',
        );
      case 'failed-precondition':
        if (message.toLowerCase().contains('expired')) {
          return InviteException(
            InviteErrorCode.expired,
            'This invite expired. Ask the host to share a fresh link.',
          );
        }
        return InviteException(
          InviteErrorCode.notPrivate,
          'This walk is not private or cannot be redeemed.',
        );
      default:
        return InviteException(
          InviteErrorCode.unknown,
          'Unable to redeem invite right now. Please retry shortly.',
        );
    }
  }

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
      await _functions.httpsCallable('revokeWalkInvite').call({
        'walkId': trimmedWalkId,
        'userId': trimmedUserId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _mapRevocationException(error);
    } catch (_) {
      throw InviteException(
        InviteErrorCode.unknown,
        'Unable to revoke invite right now. Please retry shortly.',
      );
    }
  }

  InviteException _mapRevocationException(
    FirebaseFunctionsException error,
  ) {
    switch (error.code) {
      case 'unauthenticated':
        return InviteException(
          InviteErrorCode.unauthenticated,
          'Please sign in as the host to manage invites.',
        );
      case 'permission-denied':
        return InviteException(
          InviteErrorCode.notAuthorized,
          'You are not allowed to revoke invites for this walk.',
        );
      case 'not-found':
        return InviteException(
          InviteErrorCode.notFound,
          'Invite not found or already removed.',
        );
      default:
        return InviteException(
          InviteErrorCode.unknown,
          'Unable to revoke invite right now. Please retry shortly.',
        );
    }
  }
}
