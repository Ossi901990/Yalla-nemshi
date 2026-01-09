import 'package:flutter/material.dart';
import '../models/profile_badge.dart';

class BadgesInfoScreen extends StatelessWidget {
  final List<ProfileBadge> badges;
  const BadgesInfoScreen({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final b = badges[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: b.achieved
                  ? theme.colorScheme.primary
                  : Colors.grey.shade300,
              child: Icon(
                b.icon,
                color: b.achieved ? Colors.white : Colors.grey.shade700,
              ),
            ),
            title: Text(b.title),
            subtitle: Text(b.description),
            trailing: b.achieved
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
          );
        },
      ),
    );
  }
}
