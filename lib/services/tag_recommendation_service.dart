import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/walk_event.dart';
import 'crash_service.dart';

/// Recommends walks based on user's interaction history (tags they've joined/liked).
class TagRecommendationService {
  TagRecommendationService._();

  static final TagRecommendationService instance =
      TagRecommendationService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Get tag-based recommendations for the current user.
  /// Analyzes walks user has joined, extracts common tags,
  /// and recommends similar walks they haven't joined yet.
  Future<List<WalkEvent>> getRecommendations({
    int limit = 5,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return const [];

      // 1. Get user's joined walks from /users/{uid}/walks subcollection
      final userWalksSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .where('status', isEqualTo: 'completed')
          .limit(10)
          .get();

      if (userWalksSnapshot.docs.isEmpty) return const [];

      // 2. Extract tags from completed walks
      final tagFrequency = <String, int>{};
      for (final doc in userWalksSnapshot.docs) {
        final walkId = doc['walkId'] as String?;
        if (walkId == null) continue;

        // Fetch the walk document to get its tags
        final walkDoc = await _firestore
            .collection('walks')
            .doc(walkId)
            .get();

        if (walkDoc.exists) {
          final tags = (walkDoc['tags'] as List?)?.cast<String>() ?? [];
          for (final tag in tags) {
            tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
          }
        }
      }

      if (tagFrequency.isEmpty) return const [];

      // 3. Get top tags (user's interests)
      final topTags = tagFrequency.entries
          .sorted((a, b) => b.value.compareTo(a.value))
          .take(3)
          .map((e) => e.key)
          .toList();

      // 4. Find walks with similar tags that user hasn't joined yet
      final recommendations = await _firestore
          .collection('walks')
          .where('cancelled', isEqualTo: false)
          .where('tags', arrayContainsAny: topTags)
          .limit(limit * 2) // Fetch extra to filter joined ones
          .get();

      final joinedWalkIds = userWalksSnapshot.docs
          .map((doc) => doc['walkId'] as String?)
          .whereType<String>()
          .toSet();

      final walks = recommendations.docs
          .where((doc) => !joinedWalkIds.contains(doc.id))
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['firestoreId'] = doc.id;
            return WalkEvent.fromMap(data);
          })
          .take(limit)
          .toList();

      return walks;
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'TagRecommendationService.getRecommendations',
      );
      return const [];
    }
  }
}

extension on Iterable<MapEntry<String, int>> {
  List<MapEntry<String, int>> sorted(
    int Function(MapEntry<String, int>, MapEntry<String, int>) compare,
  ) {
    final list = toList();
    list.sort(compare);
    return list;
  }
}
