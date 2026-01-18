import 'package:cloud_functions/cloud_functions.dart';

enum InviteErrorCode {
  expired,
  invalidCode,
  invalidInput,
  notFound,
  notPrivate,
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
}
