import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a friend request
  Future<void> sendFriendRequest(String senderUid, String recipientUid) async {
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
  Future<void> acceptFriendRequest(String userId, String friendId, String requestId) async {
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
  Future<void> declineFriendRequest(String userId, String friendId, String requestId) async {
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
}
