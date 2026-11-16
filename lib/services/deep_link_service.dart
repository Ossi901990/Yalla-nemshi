import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_event.dart';
import '../screens/event_details_screen.dart';
import 'invite_service.dart';

/// Service to handle deep links for walk invitations
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  /// Parse and handle an invite URL
  /// Format: https://yalla-nemshi-app.firebaseapp.com/invite?walkId=xxx&code=yyy
  Future<void> handleInviteLink(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);

      // Check if it's an invite link
      if (!uri.path.contains('/invite')) {
        debugPrint('❌ Not an invite link: ${uri.path}');
        return;
      }

      final walkId = uri.queryParameters['walkId'];
      final code = uri.queryParameters['code'];

      if (walkId == null || walkId.isEmpty) {
        _showError(context, 'Invalid invite link - missing walk ID');
        return;
      }

      debugPrint('📬 Processing invite link: walkId=$walkId, code=$code');

      // Private walks can only be read after the invite is redeemed, which
      // the backend verifies against the host-only invite doc.
      if (code != null && code.isNotEmpty) {
        try {
          await InviteService().redeemInvite(walkId: walkId, shareCode: code);
        } on InviteException catch (e) {
          // An open walk can't be "redeemed"; just continue and load it.
          if (e.code != InviteErrorCode.notPrivate) {
            if (context.mounted) _showError(context, e.message);
            return;
          }
        }
      }

      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await FirebaseFirestore.instance
            .collection('walks')
            .doc(walkId)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          if (context.mounted) {
            _showError(context, 'This is a private walk. Code required.');
          }
          return;
        }
        rethrow;
      }

      if (!doc.exists) {
        if (context.mounted) {
          _showError(context, 'This walk no longer exists.');
        }
        return;
      }

      final walk = WalkEvent.fromMap({
        ...?doc.data(),
        'firestoreId': doc.id,
        'id': doc.data()?['id'] ?? doc.id,
      });

      // Check if walk has ended
      if (walk.dateTime.isBefore(DateTime.now())) {
        if (context.mounted) {
          _showError(context, 'This walk has already ended.');
        }
        return;
      }

      // Navigate to walk details
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailsScreen(
              event: walk,
              onToggleJoin: (updatedWalk) {},
              onToggleInterested: (updatedWalk) {},
              onCancelHosted: (updatedWalk) {},
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('❌ Error handling invite link: $e');
      debugPrint('Stack: $st');
      if (context.mounted) {
        _showError(context, 'Unable to open invite link.');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD97706),
      ),
    );
  }

  /// Extract walk ID and code from URL for testing
  Map<String, String?> parseInviteUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return {
        'walkId': uri.queryParameters['walkId'],
        'code': uri.queryParameters['code'],
      };
    } catch (e) {
      return {};
    }
  }
}
