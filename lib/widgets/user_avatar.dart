// lib/widgets/user_avatar.dart
import 'package:flutter/material.dart';

/// Circle avatar that shows the user's photo when it loads, and their initials
/// otherwise (no photo, or the image failed to load, e.g. a rate-limited
/// Google profile picture).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 20,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withAlpha(50),
      foregroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      // Swallow load errors; the initials underneath stay visible.
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        initialsFor(name),
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}
