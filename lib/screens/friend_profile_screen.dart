import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/friend_profile.dart';
import '../services/dm_thread_service.dart';
import '../services/friend_profile_service.dart';
import '../services/friends_service.dart';
import 'dm_chat_screen.dart';

class FriendProfileScreenArgs {
  final String userId;
  final String? displayName;
  final String? photoUrl;

  const FriendProfileScreenArgs({
    required this.userId,
    this.displayName,
    this.photoUrl,
  });
}

class FriendProfileScreen extends StatefulWidget {
  static const routeName = '/friend-profile';

  const FriendProfileScreen({super.key});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final FriendsService _friendsService = FriendsService();
  bool _removingFriend = false;
  bool _startingChat = false;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as FriendProfileScreenArgs?;
    final uid = args?.userId;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Friend profile unavailable.')),
      );
    }

    final fallbackName = args?.displayName ?? 'Friend profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(fallbackName),
      ),
      body: StreamBuilder<FriendProfile?>(
        stream: FriendProfileService.watchProfile(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          if (profile == null) {
            return _buildEmptyState(fallbackName);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context, profile, args),
              const SizedBox(height: 16),
              _buildStatsGrid(context, profile),
              const SizedBox(height: 24),
              _WalkSummarySection(
                userId: profile.uid,
                title: 'Upcoming walks',
                category: 'upcoming',
                emptyLabel: '${profile.displayName} has no upcoming walks to share.',
              ),
              const SizedBox(height: 24),
              _WalkSummarySection(
                userId: profile.uid,
                title: 'Past walks',
                category: 'past',
                emptyLabel: 'No recent walks yet.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String name) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_neutral_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              '$name hasn\'t shared their walks yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FriendProfile profile, FriendProfileScreenArgs? args) {
    final theme = Theme.of(context);
    final photoUrl = profile.photoUrl ?? args?.photoUrl;
    final lastActiveText = profile.lastActiveAt != null
        ? 'Active ${DateFormat('MMM d, h:mm a').format(profile.lastActiveAt!)}'
        : 'Activity not available';
    final initials = profile.displayName.trim().isNotEmpty
      ? profile.displayName.trim()[0].toUpperCase()
      : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primary.withAlpha(40),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      initials,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              profile.bio ?? 'Friend since forever',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              lastActiveText,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed:
                      _startingChat ? null : () => _startDirectMessage(profile, args),
                  icon: _startingChat
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Message'),
                ),
                OutlinedButton.icon(
                  onPressed: _removingFriend
                      ? null
                      : () => _confirmRemoveFriend(
                            context,
                            profile.uid,
                            profile.displayName,
                          ),
                  icon: _removingFriend
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_remove_outlined),
                  label: const Text('Remove friend'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDirectMessage(
    FriendProfile profile,
    FriendProfileScreenArgs? args,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages.')),
      );
      return;
    }

    setState(() => _startingChat = true);
    try {
      final threadId = await DmThreadService.ensureThread(
        currentUid: currentUser.uid,
        friendUid: profile.uid,
        currentDisplayName: currentUser.displayName,
        friendDisplayName: profile.displayName,
        friendPhotoUrl: profile.photoUrl ?? args?.photoUrl,
      );
      if (!mounted) return;
      navigator.pushNamed(
        DmChatScreen.routeName,
        arguments: DmChatScreenArgs(
          threadId: threadId,
          friendUid: profile.uid,
          friendName: profile.displayName,
          friendPhotoUrl: profile.photoUrl ?? args?.photoUrl,
        ),
      );
    } catch (error, stackTrace) {
      final friendlyError = _formatDmError(error);
      debugPrint('Failed to open DM with ${profile.uid}: $friendlyError\n$stackTrace');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to open chat: $friendlyError')),
      );
    } finally {
      if (mounted) {
        setState(() => _startingChat = false);
      }
    }
  }

  String _formatDmError(Object error) {
    if (error is FirebaseException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return '${error.code}: $message';
      }
      return error.code;
    }
    return error.toString();
  }

  Widget _buildStatsGrid(BuildContext context, FriendProfile profile) {
    final stats = [
      _FriendStat(
        label: 'Walks hosted',
        value: profile.totalWalksHosted.toString(),
        icon: Icons.flag_rounded,
      ),
      _FriendStat(
        label: 'Walks joined',
        value: profile.totalWalksJoined.toString(),
        icon: Icons.directions_walk_rounded,
      ),
      _FriendStat(
        label: 'Distance walked',
        value: '${profile.totalDistanceKm.toStringAsFixed(1)} km',
        icon: Icons.route_outlined,
      ),
      _FriendStat(
        label: 'Minutes on foot',
        value: profile.totalMinutes.toString(),
        icon: Icons.timelapse,
      ),
      if (profile.hostRating != null)
        _FriendStat(
          label: 'Host rating',
          value: profile.hostRating!.toStringAsFixed(1),
          icon: Icons.star_rate_rounded,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth > 720
            ? 3
            : maxWidth > 420
                ? 2
                : 1;
        final cardWidth = columns == 1
            ? maxWidth
            : (maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: cardWidth,
                  child: stat,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _confirmRemoveFriend(
    BuildContext context,
    String friendUid,
    String friendName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove friend'),
          content: Text('Are you sure you want to remove $friendName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

  if (!context.mounted) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (currentUid == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    setState(() => _removingFriend = true);
    try {
      await _friendsService.removeFriend(currentUid, friendUid);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Removed $friendName from your friends.')),
      );
      navigator.maybePop();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not remove friend: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _removingFriend = false);
      }
    }
  }
}

class _FriendStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _FriendStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _WalkSummarySection extends StatelessWidget {
  final String userId;
  final String title;
  final String category;
  final String emptyLabel;

  const _WalkSummarySection({
    required this.userId,
    required this.title,
    required this.category,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final limit = category == 'past' ? 8 : 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<FriendWalkSummary>>(
          stream: FriendProfileService.watchSummaries(userId, category: category, limit: limit),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final walks = snapshot.data ?? const <FriendWalkSummary>[];
            if (walks.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(emptyLabel),
                ),
              );
            }
            return Column(
              children: walks
                  .map(
                    (walk) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _WalkSummaryCard(walk: walk),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _WalkSummaryCard extends StatelessWidget {
  final FriendWalkSummary walk;

  const _WalkSummaryCard({required this.walk});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('EEE, MMM d • h:mm a');
    final start = walk.startTime != null ? formatter.format(walk.startTime!) : 'TBD';
    final distance = walk.distanceKm != null ? '${walk.distanceKm!.toStringAsFixed(1)} km' : null;
    final duration = walk.estimatedDurationMinutes != null
        ? '${walk.estimatedDurationMinutes!.round()} min'
        : null;

    final subtitleParts = <String>[start];
    if (walk.meetingPlaceName != null && walk.meetingPlaceName!.isNotEmpty) {
      subtitleParts.add(walk.meetingPlaceName!);
    }
    if (distance != null) subtitleParts.add(distance);
    if (duration != null) subtitleParts.add(duration);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withAlpha(40),
          child: Icon(
            walk.isUpcoming ? Icons.event_available : Icons.history_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(walk.title),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: Chip(
          label: Text(walk.role == 'host' ? 'Host' : 'Friend'),
        ),
      ),
    );
  }
}
