import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int maxFriends = 500;

  // Send a friend request
  Future<void> sendFriendRequest(String senderUid, String recipientUid) async {
    // Prevent self-friending
    if (senderUid == recipientUid) {
      throw Exception('You cannot add yourself as a friend.');
    }

    // Check if already friends
    final existingFriendship = await _firestore
        .collection('friends')
        .doc(senderUid)
        .collection('friendsList')
        .doc(recipientUid)
        .get();

    if (existingFriendship.exists) {
      throw Exception('You are already friends with this user.');
    }

    // Check if a pending request already exists (either direction)
    final sentRequest = await _firestore
        .collection('friend_requests')
        .doc(senderUid)
        .collection('sent')
        .where('toUserId', isEqualTo: recipientUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (sentRequest.docs.isNotEmpty) {
      throw Exception('You already sent a friend request to this user.');
    }

    final receivedRequest = await _firestore
        .collection('friend_requests')
        .doc(senderUid)
        .collection('received')
        .where('fromUserId', isEqualTo: recipientUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (receivedRequest.docs.isNotEmpty) {
      throw Exception(
        'This user already sent you a friend request. Check your friend requests.',
      );
    }

    final requestId = _firestore.collection('friend_requests').doc().id;
    final requestData = {
      'requestId': requestId,
      'fromUserId': senderUid,
      'toUserId': recipientUid,
      'status': 'pending',
      'sentAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('friend_requests')
        .doc(recipientUid)
        .collection('received')
        .doc(requestId)
        .set(requestData);
    await _firestore
        .collection('friend_requests')
        .doc(senderUid)
        .collection('sent')
        .doc(requestId)
        .set(requestData);
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(
    String userId,
    String friendId,
    String requestId,
  ) async {
    final friendData = {
      'friendId': friendId,
      'since': FieldValue.serverTimestamp(),
    };
    // Add each user to the other's friends list
    await _firestore
        .collection('friends')
        .doc(userId)
        .collection('friendsList')
        .doc(friendId)
        .set(friendData);
    await _firestore
        .collection('friends')
        .doc(friendId)
        .collection('friendsList')
        .doc(userId)
        .set({'friendId': userId, 'since': FieldValue.serverTimestamp()});
    // Delete the friend request
    await _firestore
        .collection('friend_requests')
        .doc(userId)
        .collection('received')
        .doc(requestId)
        .delete();
    await _firestore
        .collection('friend_requests')
        .doc(friendId)
        .collection('sent')
        .doc(requestId)
        .delete();
  }

  // Decline a friend request
  Future<void> declineFriendRequest(
    String userId,
    String friendId,
    String requestId,
  ) async {
    await _firestore
        .collection('friend_requests')
        .doc(userId)
        .collection('received')
        .doc(requestId)
        .delete();
    await _firestore
        .collection('friend_requests')
        .doc(friendId)
        .collection('sent')
        .doc(requestId)
        .delete();
  }

  // List friends for a user
  Future<List<String>> getFriends(String userId) async {
    final snapshot = await _firestore
        .collection('friends')
        .doc(userId)
        .collection('friendsList')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> removeFriend(String userId, String friendId) async {
    final batch = _firestore.batch();
    final userRef = _firestore
        .collection('friends')
        .doc(userId)
        .collection('friendsList')
        .doc(friendId);
    final friendRef = _firestore
        .collection('friends')
        .doc(friendId)
        .collection('friendsList')
        .doc(userId);
    batch.delete(userRef);
    batch.delete(friendRef);
    await batch.commit();
  }

  Future<void> blockUser(
    String blockerUid,
    String targetUid, {
    String? reason,
  }) async {
    final blockRef = _firestore
        .collection('blocks')
        .doc(blockerUid)
        .collection('blocked')
        .doc(targetUid);

    await blockRef.set({
      'targetUserId': targetUid,
      'blockedAt': FieldValue.serverTimestamp(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });

    await removeFriend(blockerUid, targetUid);
    await _deleteFriendRequestsBetween(blockerUid, targetUid);
  }

  Future<void> reportUser({
    required String reporterUid,
    required String targetUid,
    required String reason,
    String? details,
  }) async {
    final reportRef = _firestore.collection('user_reports').doc();
    await reportRef.set({
      'reportId': reportRef.id,
      'reporterUid': reporterUid,
      'targetUid': targetUid,
      'reason': reason.trim(),
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteFriendRequestsBetween(String userA, String userB) async {
    final receivedByA = await _firestore
        .collection('friend_requests')
        .doc(userA)
        .collection('received')
        .where('fromUserId', isEqualTo: userB)
        .get();
    final receivedByB = await _firestore
        .collection('friend_requests')
        .doc(userB)
        .collection('received')
        .where('fromUserId', isEqualTo: userA)
        .get();
    final sentByA = await _firestore
        .collection('friend_requests')
        .doc(userA)
        .collection('sent')
        .where('toUserId', isEqualTo: userB)
        .get();
    final sentByB = await _firestore
        .collection('friend_requests')
        .doc(userB)
        .collection('sent')
        .where('toUserId', isEqualTo: userA)
        .get();

    await Future.wait([
      ...receivedByA.docs.map((doc) => doc.reference.delete()),
      ...receivedByB.docs.map((doc) => doc.reference.delete()),
      ...sentByA.docs.map((doc) => doc.reference.delete()),
      ...sentByB.docs.map((doc) => doc.reference.delete()),
    ]);
  }
}
