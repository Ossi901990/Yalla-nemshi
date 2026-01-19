// Badge domain models and catalog definitions
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Immutable badge definition (catalog entry)
class BadgeDefinition {
  final String id;
  final String title;
  final String description;
  final BadgeMetric metric;
  final double target;
  final IconData icon;

  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.icon,
  });
}

/// Supported metrics for badge evaluation
enum BadgeMetric {
  totalWalksCompleted,
  totalDistanceKm,
  totalWalksHosted,
}

/// A user’s badge state persisted in Firestore
class UserBadge {
  final String id;
  final String title;
  final String description;
  final double progress; // 0.0 - 1.0
  final double target; // threshold value used
  final bool achieved;
  final DateTime? earnedAt;

  const UserBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.achieved,
    this.earnedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'progress': progress,
      'target': target,
      'achieved': achieved,
      'earnedAt': earnedAt,
      'updatedAt': DateTime.now(),
    };
  }

  static UserBadge fromFirestore(String id, Map<String, dynamic> data) {
    return UserBadge(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      progress: (data['progress'] as num?)?.toDouble() ?? 0,
      target: (data['target'] as num?)?.toDouble() ?? 1,
      achieved: data['achieved'] as bool? ?? false,
      earnedAt: (data['earnedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Central badge catalog. Keep thresholds stable to avoid re-awarding.
const List<BadgeDefinition> kBadgeCatalog = [
  BadgeDefinition(
    id: 'first_walk',
    title: 'First Steps',
    description: 'Complete your first walk.',
    metric: BadgeMetric.totalWalksCompleted,
    target: 1,
    icon: Icons.directions_walk,
  ),
  BadgeDefinition(
    id: 'five_walks',
    title: 'Getting Going',
    description: 'Complete 5 walks.',
    metric: BadgeMetric.totalWalksCompleted,
    target: 5,
    icon: Icons.trending_up,
  ),
  BadgeDefinition(
    id: 'ten_walks',
    title: 'Consistent Walker',
    description: 'Complete 10 walks.',
    metric: BadgeMetric.totalWalksCompleted,
    target: 10,
    icon: Icons.directions_walk,
  ),
  BadgeDefinition(
    id: 'twentyfive_walks',
    title: 'Trail Regular',
    description: 'Complete 25 walks.',
    metric: BadgeMetric.totalWalksCompleted,
    target: 25,
    icon: Icons.terrain,
  ),
  BadgeDefinition(
    id: 'fifty_walks',
    title: 'Walk Centurion',
    description: 'Complete 50 walks.',
    metric: BadgeMetric.totalWalksCompleted,
    target: 50,
    icon: Icons.flag,
  ),
  BadgeDefinition(
    id: 'hundred_walks',
    title: 'Habit Master',
    description: 'Complete 100 walks.',
    metric: BadgeMetric.totalWalksCompleted,
    target: 100,
    icon: Icons.emoji_events,
  ),
  BadgeDefinition(
    id: 'km_20',
    title: '20 km',
    description: 'Walk 20 km in total.',
    metric: BadgeMetric.totalDistanceKm,
    target: 20,
    icon: Icons.route,
  ),
  BadgeDefinition(
    id: 'km_42',
    title: 'Marathon Mindset',
    description: 'Walk 42 km in total.',
    metric: BadgeMetric.totalDistanceKm,
    target: 42,
    icon: Icons.directions_run,
  ),
  BadgeDefinition(
    id: 'km_100',
    title: 'Century Club',
    description: 'Walk 100 km in total.',
    metric: BadgeMetric.totalDistanceKm,
    target: 100,
    icon: Icons.star,
  ),
  BadgeDefinition(
    id: 'km_250',
    title: 'Quarter to 1k',
    description: 'Walk 250 km in total.',
    metric: BadgeMetric.totalDistanceKm,
    target: 250,
    icon: Icons.local_florist,
  ),
  BadgeDefinition(
    id: 'km_500',
    title: 'Half to 1k',
    description: 'Walk 500 km in total.',
    metric: BadgeMetric.totalDistanceKm,
    target: 500,
    icon: Icons.workspace_premium,
  ),
  BadgeDefinition(
    id: 'first_host',
    title: 'First Host',
    description: 'Host your first walk.',
    metric: BadgeMetric.totalWalksHosted,
    target: 1,
    icon: Icons.record_voice_over,
  ),
  BadgeDefinition(
    id: 'five_hosts',
    title: 'Community Leader',
    description: 'Host 5 walks.',
    metric: BadgeMetric.totalWalksHosted,
    target: 5,
    icon: Icons.groups_2,
  ),
  BadgeDefinition(
    id: 'ten_hosts',
    title: 'Super Host',
    description: 'Host 10 walks.',
    metric: BadgeMetric.totalWalksHosted,
    target: 10,
    icon: Icons.military_tech,
  ),
];