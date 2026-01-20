import 'package:flutter/material.dart';
import '../models/leaderboard.dart';
import '../services/leaderboard_service.dart';

const kPrimary = Color(0xFF2E7D32);
const kTextPrimary = Color(0xFF1F2937);
const kTextSecondary = Color(0xFF6B7280);
const kSurfaceSecondary = Color(0xFFF3F4F6);

class BadgeLeaderboardScreen extends StatefulWidget {
  static const routeName = '/badge_leaderboard';

  const BadgeLeaderboardScreen({super.key});

  @override
  State<BadgeLeaderboardScreen> createState() => _BadgeLeaderboardScreenState();
}

class _BadgeLeaderboardScreenState extends State<BadgeLeaderboardScreen> {
  late LeaderboardService _leaderboardService;

  @override
  void initState() {
    super.initState();
    _leaderboardService = LeaderboardService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Leaderboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: kTextPrimary,
      ),
      body: StreamBuilder<List<BadgeLeaderboardEntry>>(
        stream: _leaderboardService.streamGlobalBadgeLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading leaderboard',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No badges earned yet',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildLeaderboardCard(context, entry);
            },
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardCard(
    BuildContext context,
    BadgeLeaderboardEntry entry,
  ) {
    final isMedal = entry.rank <= 3;
    final medalEmoji = ['🥇', '🥈', '🥉'][entry.rank - 1];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: entry.rank <= 3
            ? BorderSide(
                color: _getMedalColor(entry.rank),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMedal
                    ? _getMedalColor(entry.rank).withValues(alpha: 0.2)
                    : kSurfaceSecondary,
              ),
              child: Center(
                child: Text(
                  isMedal ? medalEmoji : '#${entry.rank}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last earned ${_formatDate(entry.lastBadgeEarnedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: kTextSecondary,
                        ),
                  ),
                ],
              ),
            ),
            // Badge count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.totalBadgesEarned}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getMedalColor(entry.rank),
                      ),
                ),
                Text(
                  'badges',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return kPrimary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }
}
