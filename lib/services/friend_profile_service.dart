import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/friend_profile.dart';

class FriendProfileService {
  FriendProfileService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'friend_profiles';

  static DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _firestore.collection(_collection).doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> _summaryRef(String uid) {
    return _profileRef(uid).collection('walk_summaries');
  }

  static Stream<FriendProfile?> watchProfile(String uid) {
    return _profileRef(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return FriendProfile.fromDoc(snapshot);
    });
  }

  static Future<FriendProfile?> fetchProfile(String uid) async {
    final snapshot = await _profileRef(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return FriendProfile.fromDoc(snapshot);
  }

  static Stream<List<FriendWalkSummary>> watchSummaries(
    String uid, {
    required String category,
    int limit = 10,
  }) {
    Query<Map<String, dynamic>> query = _summaryRef(uid)
        .where('category', isEqualTo: category)
        .orderBy('startTime', descending: category != 'upcoming')
        .limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map(FriendWalkSummary.fromDoc).toList();
    });
  }
}
