import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';

class FriendSearchScreen extends StatefulWidget {
  static const routeName = '/friend-search';
  const FriendSearchScreen({Key? key}) : super(key: key);

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  final FriendsService _friendsService = FriendsService();

  Future<void> _searchUsers(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();
      setState(() {
        _results = snapshot.docs.map((doc) => doc.data()).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _friendsService.sendFriendRequest(user.uid, targetUid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Friends')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchUsers(_searchController.text.trim()),
                ),
              ),
              onSubmitted: (value) => _searchUsers(value.trim()),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_loading && _results.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(user['displayName'] ?? ''),
                      subtitle: Text(user['email'] ?? ''),
                      trailing: ElevatedButton(
                        child: const Text('Add Friend'),
                        onPressed: () => _sendFriendRequest(user['uid']),
                      ),
                    );
                  },
                ),
              ),
            if (!_loading && _results.isEmpty && _searchController.text.isNotEmpty)
              const Text('No users found.'),
          ],
        ),
      ),
    );
  }
}
