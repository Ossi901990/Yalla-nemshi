// lib/screens/friends_screen.dart
import 'package:flutter/material.dart';

import '../models/friend.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // Fake local friends list
  final List<Friend> _friends = const [
    Friend(
      id: 'f1',
      name: 'Lina',
      bio: 'Loves sunset walks and slow pace.',
      walksTogether: 3,
    ),
    Friend(
      id: 'f2',
      name: 'Omar',
      bio: 'Morning runner turned walker.',
      walksTogether: 1,
    ),
    Friend(
      id: 'f3',
      name: 'Sara',
      bio: 'Explores new parks every weekend.',
      walksTogether: 0,
    ),
    Friend(
      id: 'f4',
      name: 'Adam',
      bio: 'Prefers fast-paced city walks.',
      walksTogether: 2,
    ),
  ];

  void _toggleFavorite(Friend friend) {
    setState(() {
      final index = _friends.indexWhere((f) => f.id == friend.id);
      if (index == -1) return;
      final current = _friends[index];
      _friends[index] = current.copyWith(isFavorite: !current.isFavorite);
    });
  }

  void _showInviteSnack(Friend friend) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite to walk feature coming soon for ${friend.name}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final favorites = _friends
        .where((f) => f.isFavorite)
        .toList(growable: false);
    final others = _friends.where((f) => !f.isFavorite).toList(growable: false);

    final ordered = [...favorites, ...others];

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ordered.isEmpty
          ? const Center(
              child: Text(
                'No friends yet.\nIn the future, you’ll be able to add and invite real people.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: ordered.length,
              itemBuilder: (context, index) {
                final f = ordered[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(f.name.substring(0, 1))),
                    title: Text(f.name),
                    subtitle: Text(
                      '${f.bio}\nWalked together ${f.walksTogether} time${f.walksTogether == 1 ? '' : 's'}.',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: f.isFavorite
                              ? 'Unfavorite'
                              : 'Mark as favorite',
                          icon: Icon(
                            f.isFavorite
                                ? Icons.star
                                : Icons.star_border_outlined,
                            color: f.isFavorite ? Colors.amber : null,
                          ),
                          onPressed: () => _toggleFavorite(f),
                        ),
                        IconButton(
                          tooltip: 'Invite to walk',
                          icon: const Icon(Icons.mail_outline),
                          onPressed: () => _showInviteSnack(f),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          'This is a local demo of the friends system.\n'
          'Later, it will connect to real accounts.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
