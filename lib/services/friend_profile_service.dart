import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/friend_profile.dart';
import 'host_rating_service.dart';

/// Builds a friend's profile and walk list directly from `users/{uid}`, their
/// stats and their open walks.
///
/// This used to read `friend_profiles/{uid}` snapshots written by a Cloud
/// Function, which doesn't run on the free Spark plan. Private walks are never
/// included (the security rules wouldn't return them anyway).
class FriendProfileService {
  FriendProfileService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _maxWalksPerQuery = 40;

  static Stream<FriendProfile?> watchProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((userSnap) => _buildProfile(uid, userSnap));
  }

  static Future<FriendProfile?> fetchProfile(String uid) async {
    final userSnap = await _firestore.collection('users').doc(uid).get();
    return _buildProfile(uid, userSnap);
  }

  static Future<FriendProfile?> _buildProfile(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> userSnap,
  ) async {
    final user = userSnap.data();
    if (!userSnap.exists || user == null) return null;

    Map<String, dynamic> stats = const {};
    try {
      final statsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('stats')
          .doc('walkStats')
          .get();
      stats = statsSnap.data() ?? const {};
    } catch (_) {
      // Stats are optional for the profile card.
    }

    double? hostRating;
    try {
      final rating = await HostRatingService.instance.getHostRating(uid);
      if ((rating['reviewCount'] as int? ?? 0) > 0) {
        hostRating = (rating['rating'] as num?)?.toDouble();
      }
    } catch (_) {}

    num readNum(String key) => (stats[key] as num?) ?? 0;

    final durationSeconds = readNum('totalDuration');
    final displayName = (user['displayName'] as String?)?.trim();
    final photo = (user['photoURL'] ?? user['photoUrl']) as String?;
    final lastWalk = stats['lastWalkDate'];

    return FriendProfile(
      uid: uid,
      displayName: (displayName == null || displayName.isEmpty)
          ? 'Walker'
          : displayName,
      photoUrl: (photo == null || photo.trim().isEmpty) ? null : photo,
      bio: (user['bio'] as String?)?.trim().isNotEmpty == true
          ? (user['bio'] as String).trim()
          : null,
      hostRating: hostRating,
      totalWalksHosted: readNum('totalWalksHosted').toInt(),
      totalWalksJoined: readNum('totalWalksJoined').toInt(),
      totalDistanceKm: readNum('totalDistanceKm').toDouble(),
      totalMinutes: (durationSeconds / 60).round(),
      lastActiveAt: lastWalk is Timestamp ? lastWalk.toDate() : null,
      updatedAt: null,
    );
  }

  /// All open walks the user hosts or joined, newest first.
  static Future<List<FriendWalkSummary>> fetchWalkSummaries(String uid) async {
    final walks = _firestore.collection('walks');
    final results = await Future.wait([
      walks
          .where('visibility', isEqualTo: 'open')
          .where('hostUid', isEqualTo: uid)
          .limit(_maxWalksPerQuery)
          .get(),
      walks
          .where('visibility', isEqualTo: 'open')
          .where('joinedUserUids', arrayContains: uid)
          .limit(_maxWalksPerQuery)
          .get(),
    ]);

    final byId = <String, FriendWalkSummary>{};
    for (final doc in results[0].docs) {
      if (doc.data()['hideFromFriends'] == true) continue;
      byId[doc.id] = FriendWalkSummary.fromWalk(doc.id, doc.data(), 'host');
    }
    for (final doc in results[1].docs) {
      if (doc.data()['hideFromFriends'] == true) continue;
      byId.putIfAbsent(
        doc.id,
        () => FriendWalkSummary.fromWalk(doc.id, doc.data(), 'participant'),
      );
    }

    final list = byId.values.toList()
      ..sort((a, b) {
        final at = a.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return list;
  }

  /// Walk summaries for one category ('upcoming', 'past', 'cancelled').
  /// Upcoming walks are soonest first; the rest are newest first.
  static Stream<List<FriendWalkSummary>> watchSummaries(
    String uid, {
    required String category,
    int limit = 10,
  }) {
    return Stream.fromFuture(fetchWalkSummaries(uid)).map((all) {
      final filtered = all.where((s) => s.category == category).toList();
      if (category == 'upcoming') {
        filtered.sort((a, b) {
          final at = a.startTime ?? DateTime(9999);
          final bt = b.startTime ?? DateTime(9999);
          return at.compareTo(bt);
        });
      }
      return filtered.take(limit).toList();
    });
  }
}
