import 'dart:math';

class InviteUtils {
  InviteUtils._();

  static const Duration privateInviteTtl = Duration(days: 7);
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const String inviteLinkBaseUrl =
      'https://yalla-nemshi-app.firebaseapp.com/invite';

  static String generateShareCode({int length = 6}) {
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => _chars[rand.nextInt(_chars.length)],
    ).join();
  }

  static DateTime nextExpiry([DateTime? from]) {
    final anchor = (from ?? DateTime.now()).toUtc();
    return anchor.add(privateInviteTtl);
  }

  static String buildInviteLink({
    required String walkId,
    String? shareCode,
  }) {
    final uri = Uri.parse(inviteLinkBaseUrl).replace(
      queryParameters: {
        'walkId': walkId,
        if (shareCode != null && shareCode.isNotEmpty) 'code': shareCode,
      },
    );
    return uri.toString();
  }
}
