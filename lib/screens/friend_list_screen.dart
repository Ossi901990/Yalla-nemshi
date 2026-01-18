import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';

class FriendListScreen extends StatefulWidget {
  static const routeName = '/friends';
  const FriendListScreen({Key? key}) : super(key: key);

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  final FriendsService _friendsService = FriendsService();
  List<String> _friends = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not signed in.';
          _loading = false;
        });
        return;
      }
      final friends = await _friendsService.getFriends(user.uid);
      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Friends')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _friends.isEmpty
                  ? const Center(child: Text('No friends yet.'))
                  : ListView.builder(
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        final friendId = _friends[index];
                        return ListTile(
                          title: Text(friendId),
                        );
                      },
                    ),
    );
  }
}
