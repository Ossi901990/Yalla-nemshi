import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_event.dart';
import '../screens/event_details_screen.dart';

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

      // Fetch the walk
      final doc = await FirebaseFirestore.instance
          .collection('walks')
          .doc(walkId)
          .get();

      if (!doc.exists) {
        if (context.mounted) {
          _showError(context, 'This walk no longer exists.');
        }
        return;
      }

      final walk = WalkEvent.fromMap(doc.data() ?? {});

      // If it's a private walk, validate the code
      if (walk.visibility == 'private') {
        if (code == null || code.isEmpty) {
          if (context.mounted) {
            _showError(context, 'This is a private walk. Code required.');
          }
          return;
        }

        if (walk.shareCode != code) {
          if (context.mounted) {
            _showError(context, 'Invalid invite code for this walk.');
          }
          return;
        }
      }

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
