// lib/models/profile_badge.dart
import 'package:flutter/material.dart';

class ProfileBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool achieved;

  const ProfileBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.achieved,
  });
}

List<ProfileBadge> computeBadges({
  required int walksJoined,
  required int eventsHosted,
  required double totalKm,
}) {
  return [
    ProfileBadge(
      id: 'first_steps',
      title: 'First Steps',
      description: 'Joined your first walk.',
      icon: Icons.directions_walk,
      achieved: walksJoined >= 1,
    ),
    ProfileBadge(
      id: 'regular_walker',
      title: 'Regular Walker',
      description: 'Joined 5 walks.',
      icon: Icons.repeat,
      achieved: walksJoined >= 5,
    ),
    ProfileBadge(
      id: 'trail_addict',
      title: 'Trail Addict',
      description: 'Joined 15 walks.',
      icon: Icons.terrain,
      achieved: walksJoined >= 15,
    ),
    ProfileBadge(
      id: 'first_host',
      title: 'First Host',
      description: 'Hosted your first walk.',
      icon: Icons.emoji_events,
      achieved: eventsHosted >= 1,
    ),
    ProfileBadge(
      id: 'community_leader',
      title: 'Community Leader',
      description: 'Hosted 5 walks.',
      icon: Icons.group,
      achieved: eventsHosted >= 5,
    ),
    ProfileBadge(
      id: 'marathon_mindset',
      title: 'Marathon Mindset',
      description: 'Walked 42 km in total.',
      icon: Icons.flag,
      achieved: totalKm >= 42.0,
    ),
    ProfileBadge(
      id: 'century_club',
      title: 'Century Club',
      description: 'Walked 100+ km in total.',
      icon: Icons.star,
      achieved: totalKm >= 100.0,
    ),
    ProfileBadge(
      id: 'steady_steps',
      title: 'Steady Steps',
      description: 'Walked 20+ km in total.',
      icon: Icons.directions_walk,
      achieved: totalKm >= 20.0,
    ),
  ];
}
