import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/firestore_user.dart';
import '../services/firestore_user_service.dart';
import '../services/friends_service.dart';
import '../utils/invite_utils.dart';
import 'friend_profile_screen.dart';

class FriendListScreen extends StatefulWidget {
  static const routeName = '/friends';
  const FriendListScreen({super.key});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  final FriendsService _friendsService = FriendsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _walkSummariesPerFriend = 3;

  List<_FriendRequestItem> _incomingRequests = [];
  List<_FriendCardData> _friendCards = [];
  List<_FriendActivityItem> _activityFeed = [];
  bool _loading = true;
  String? _error;
  final Set<String> _processingRequests = {};
  final Set<String> _unfriending = {};
  final Set<String> _blocking = {};
  final Set<String> _reporting = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _walkSummarySubscriptions = {};
  final Map<String, List<_FriendWalkActivity>> _recentWalksByFriend = {};
  List<String> _currentFriendIds = [];
  List<FirestoreUser> _currentFriendProfiles = [];
  Map<String, int> _currentMutualCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _clearWalkSummarySubscriptions();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _clearWalkSummarySubscriptions();
      setState(() {
        _error = 'Not signed in.';
        _loading = false;
      });
      return;
    }

    try {
      final requestsFuture = _fetchPendingRequests(user.uid);
      final friendIds = await _friendsService.getFriends(user.uid);

      if (friendIds.isEmpty) {
        _clearWalkSummarySubscriptions();
        final requests = await requestsFuture;
        if (!mounted) return;
        setState(() {
          _incomingRequests = requests;
          _friendCards = [];
          _activityFeed = [];
          _currentFriendIds = [];
          _currentFriendProfiles = [];
          _currentMutualCounts = {};
          _loading = false;
        });
        return;
      }

      final profilesFuture = FirestoreUserService.getUsersByIds(friendIds);
      final mutualFuture = _fetchMutualFriendCounts(friendIds);
      final profiles = await profilesFuture;
      final mutualCounts = await mutualFuture;
      final friendCards = _composeFriendCards(
        friendIds,
        profiles,
        mutualCounts,
        _recentWalksByFriend,
      );
      final feed = _buildActivityFeed(friendCards);
      final requests = await requestsFuture;

      if (!mounted) return;
      setState(() {
        _incomingRequests = requests;
        _currentFriendIds = List<String>.from(friendIds);
        _currentFriendProfiles = List<FirestoreUser>.from(profiles);
        _currentMutualCounts = Map<String, int>.from(mutualCounts);
        _friendCards = friendCards;
        _activityFeed = feed;
        _loading = false;
      });

      _subscribeToFriendWalkSummaries(friendIds);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isFriendBusy(String userId) {
    return _unfriending.contains(userId) ||
        _blocking.contains(userId) ||
        _reporting.contains(userId);
  }

  List<_FriendCardData> _composeFriendCards(
    List<String> friendIds,
    List<FirestoreUser> profiles,
    Map<String, int> mutualCounts,
    Map<String, List<_FriendWalkActivity>> recentActivity,
  ) {
    if (friendIds.isEmpty) return const [];
    final profileMap = {for (final profile in profiles) profile.uid: profile};

    return friendIds
        .map((friendId) {
          final profile = profileMap[friendId];
          final walks =
              recentActivity[friendId] ?? const <_FriendWalkActivity>[];
          return _FriendCardData(
            userId: friendId,
            displayName: (profile?.displayName.isNotEmpty ?? false)
                ? profile!.displayName
                : friendId,
            email: profile?.email,
            photoUrl: profile?.photoURL,
            bio: profile?.bio,
            statusText: _buildStatusLine(profile, walks),
            mutualFriends: mutualCounts[friendId] ?? 0,
            recentWalks: walks,
          );
        })
        .toList(growable: false);
  }

  String _buildStatusLine(
    FirestoreUser? profile,
    List<_FriendWalkActivity> walks,
  ) {
    if (walks.isNotEmpty) {
      final latest = walks.first;
      final distance = _formatDistance(latest.distanceKm);
      final distanceLabel = distance != null ? ' | $distance' : '';
      return '${_describeActivity(latest)}$distanceLabel | '
          '${_formatRelativeTime(latest.timestamp)}';
    }

    if (profile?.bio != null && profile!.bio!.trim().isNotEmpty) {
      return profile.bio!.trim();
    }

    final joined = profile?.walksJoined ?? 0;
    if (joined > 0) {
      final plural = joined == 1 ? '' : 's';
      return 'Joined $joined walk$plural so far';
    }

    return 'Tap "Invite to walk" to plan something together';
  }

  List<_FriendActivityItem> _buildActivityFeed(List<_FriendCardData> cards) {
    if (cards.isEmpty) return const [];
    final feed = <_FriendActivityItem>[];
    for (final card in cards) {
      for (final activity in card.recentWalks) {
        feed.add(
          _FriendActivityItem(
            friendId: card.userId,
            friendName: card.displayName,
            photoUrl: card.photoUrl,
            activity: activity,
          ),
        );
      }
    }
    feed.sort((a, b) => b.activity.timestamp.compareTo(a.activity.timestamp));
    return feed.take(15).toList(growable: false);
  }

  Future<Map<String, int>> _fetchMutualFriendCounts(
    List<String> friendIds,
  ) async {
    if (friendIds.isEmpty) return {};
    // Permissions prevent reading other users' friendsList documents, so for now we
    // default mutual counts to zero until a friend-safe snapshot is available.
    return {for (final friendId in friendIds) friendId: 0};
  }

  void _subscribeToFriendWalkSummaries(List<String> friendIds) {
    if (friendIds.isEmpty) {
      _clearWalkSummarySubscriptions();
      return;
    }

    final desiredIds = friendIds.toSet();
    final existingIds = _walkSummarySubscriptions.keys.toSet();

    for (final removedId in existingIds.difference(desiredIds)) {
      _walkSummarySubscriptions[removedId]?.cancel();
      _walkSummarySubscriptions.remove(removedId);
      _recentWalksByFriend.remove(removedId);
    }

    for (final friendId in desiredIds) {
      if (_walkSummarySubscriptions.containsKey(friendId)) continue;
      final subscription = _firestore
          .collection('friend_profiles')
          .doc(friendId)
          .collection('walk_summaries')
          .orderBy('startTime', descending: true)
          .limit(_walkSummariesPerFriend)
          .snapshots()
          .listen(
            (snapshot) {
              final walks = snapshot.docs
                  .map((doc) {
                    final data = doc.data();
                    return _FriendWalkActivity(
                      walkId: doc.id,
                      joinedAt:
                          _readTimestamp(data['startTime']) ?? DateTime.now(),
                      completedAt: _readTimestamp(data['endTime']),
                      status: data['status']?.toString(),
                      distanceKm:
                          (data['distanceKm'] as num?)?.toDouble() ??
                          (data['actualDistanceKm'] as num?)?.toDouble(),
                    );
                  })
                  .toList(growable: false);

              if (!mounted) return;
              setState(() {
                _recentWalksByFriend[friendId] = walks;
                _refreshFriendCardsAndFeed();
              });
            },
            onError: (_) {
              if (!mounted) return;
              setState(() {
                _recentWalksByFriend[friendId] = const <_FriendWalkActivity>[];
                _refreshFriendCardsAndFeed();
              });
            },
          );

      _walkSummarySubscriptions[friendId] = subscription;
    }
  }

  void _refreshFriendCardsAndFeed() {
    final friendCards = _composeFriendCards(
      _currentFriendIds,
      _currentFriendProfiles,
      _currentMutualCounts,
      _recentWalksByFriend,
    );
    _friendCards = friendCards;
    _activityFeed = _buildActivityFeed(friendCards);
  }

  void _clearWalkSummarySubscriptions() {
    for (final subscription in _walkSummarySubscriptions.values) {
      subscription.cancel();
    }
    _walkSummarySubscriptions.clear();
    _recentWalksByFriend.clear();
  }

  Future<List<_FriendRequestItem>> _fetchPendingRequests(String userId) async {
    final snapshot = await _firestore
        .collection('friend_requests')
        .doc(userId)
        .collection('received')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) {
      return [];
    }

    final requesterIds = <String>{};
    for (final doc in snapshot.docs) {
      final fromUid = (doc.data()['fromUserId'] ?? '').toString();
      if (fromUid.isNotEmpty) requesterIds.add(fromUid);
    }

    final Map<String, Map<String, dynamic>> profileMap = {};
    if (requesterIds.isNotEmpty) {
      try {
        final futures = requesterIds
            .map((uid) => _firestore.collection('users').doc(uid).get())
            .toList();
        final profiles = await Future.wait(futures);
        for (final snap in profiles) {
          if (snap.exists) {
            profileMap[snap.id] = snap.data() ?? {};
          }
        }
      } catch (error) {
        debugPrint('Failed to fetch friend request profiles: $error');
      }
    }

    final requests = <_FriendRequestItem>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final fromUid = (data['fromUserId'] ?? '').toString();
      if (fromUid.isEmpty) continue;

      DateTime? sentAt;
      final rawSentAt = data['sentAt'];
      if (rawSentAt is Timestamp) {
        sentAt = rawSentAt.toDate();
      } else if (rawSentAt is DateTime) {
        sentAt = rawSentAt;
      } else if (rawSentAt is String) {
        sentAt = DateTime.tryParse(rawSentAt);
      }

      final profile = profileMap[fromUid];
      requests.add(
        _FriendRequestItem(
          requestId: (data['requestId'] ?? doc.id).toString(),
          fromUserId: fromUid,
          displayName: profile?['displayName'] as String?,
          email: profile?['email'] as String?,
          photoUrl: profile?['photoUrl'] as String?,
          sentAt: sentAt,
        ),
      );
    }

    return requests;
  }

  Future<void> _handleRequestAction(
    _FriendRequestItem request, {
    required bool accept,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _processingRequests.add(request.requestId);
    });

    try {
      if (accept) {
        await _friendsService.acceptFriendRequest(
          user.uid,
          request.fromUserId,
          request.requestId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You are now friends with ${request.displayName ?? request.fromUserId}.',
              ),
            ),
          );
        }
      } else {
        await _friendsService.declineFriendRequest(
          user.uid,
          request.fromUserId,
          request.requestId,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Request declined.')));
        }
      }

      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingRequests.remove(request.requestId);
        });
      }
    }
  }

  String _formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }

  String _initialFor(_FriendRequestItem request) {
    final source = (request.displayName?.trim().isNotEmpty ?? false)
        ? request.displayName!.trim()
        : request.fromUserId;
    return source.isNotEmpty ? source.substring(0, 1).toUpperCase() : '?';
  }

  String _initialForName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  String? _formatDistance(double? km) {
    if (km == null || km <= 0) return null;
    final formatted = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
    return '$formatted km';
  }

  String _describeActivity(_FriendWalkActivity activity) {
    final status = activity.status?.toLowerCase() ?? '';
    if (status.contains('ended') || status.contains('completed')) {
      return 'Completed a walk';
    }
    if (status.contains('active')) {
      return 'Started walking';
    }
    if (status.contains('declined')) {
      return 'Declined a walk';
    }
    if (status.contains('scheduled')) {
      return 'Getting ready for a walk';
    }
    return 'Joined a walk';
  }

  Future<void> _confirmUnfriend(_FriendCardData friend) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${friend.displayName}?'),
        content: const Text(
          'You will no longer see each other in friends lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unfriend'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _unfriending.add(friend.userId);
    });

    try {
      await _friendsService.removeFriend(user.uid, friend.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${friend.displayName} from friends.')),
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unfriend: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _unfriending.remove(friend.userId);
        });
      }
    }
  }

  Future<void> _handleBlock(_FriendCardData friend) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reason = await _showBlockDialog(friend);
    if (reason == null) return;

    setState(() {
      _blocking.add(friend.userId);
    });

    try {
      await _friendsService.blockUser(user.uid, friend.userId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend.displayName} has been blocked.')),
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to block user: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _blocking.remove(friend.userId);
        });
      }
    }
  }

  Future<void> _handleReport(_FriendCardData friend) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final payload = await _showReportDialog(friend);
    if (payload == null) return;

    setState(() {
      _reporting.add(friend.userId);
    });

    try {
      await _friendsService.reportUser(
        reporterUid: user.uid,
        targetUid: friend.userId,
        reason: payload.reason,
        details: payload.notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report submitted for ${friend.displayName}.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send report: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _reporting.remove(friend.userId);
        });
      }
    }
  }

  Future<String?> _showBlockDialog(_FriendCardData friend) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${friend.displayName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'They will be removed from your friends list and can no longer interact with you.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Block user'),
          ),
        ],
      ),
    );
  }

  Future<_ReportPayload?> _showReportDialog(_FriendCardData friend) async {
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? errorText;

    return showDialog<_ReportPayload>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateModal) {
            return AlertDialog(
              title: Text('Report ${friend.displayName}?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Describe what happened so our team can review it.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        labelText: 'Reason',
                        errorText: errorText,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Additional details (optional)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final reason = reasonCtrl.text.trim();
                    if (reason.isEmpty) {
                      setStateModal(() {
                        errorText = 'Please provide a reason.';
                      });
                      return;
                    }
                    Navigator.of(ctx).pop(
                      _ReportPayload(
                        reason: reason,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Submit report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final widgets = <Widget>[];

    if (_incomingRequests.isNotEmpty) {
      widgets.add(
        Text(
          'Pending requests',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));

      for (final request in _incomingRequests) {
        widgets.add(_buildRequestCard(context, request));
        widgets.add(const SizedBox(height: 12));
      }

      widgets.add(const Divider());
      widgets.add(const SizedBox(height: 24));
    }

    widgets.add(
      Text(
        'Friends',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 8));

    if (_friendCards.isEmpty) {
      widgets.add(
        Center(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Icon(
                Icons.people_outline,
                size: 64,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(height: 16),
              Text(
                'No friends yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for friends to connect with',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/friend-search');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1ABFC4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Find Friends'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } else {
      for (final friend in _friendCards) {
        widgets.add(_buildFriendCard(context, friend));
        widgets.add(const SizedBox(height: 12));
      }
    }

    if (_activityFeed.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(const Divider());
      widgets.add(const SizedBox(height: 16));
      widgets.add(
        Text(
          'Friend activity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));

      for (final activity in _activityFeed) {
        widgets.add(_buildActivityCard(context, activity));
        widgets.add(const SizedBox(height: 8));
      }
    }

    return widgets;
  }

  Widget _buildFriendCard(BuildContext context, _FriendCardData friend) {
    final theme = Theme.of(context);
    final mutualCount = friend.mutualFriends;
    final mutualText = mutualCount > 0
        ? '$mutualCount mutual friend${mutualCount == 1 ? '' : 's'}'
        : 'No mutual friends yet';
    final busy = _isFriendBusy(friend.userId);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () => _openFriendProfile(friend),
            leading: _buildAvatar(theme, friend.photoUrl, friend.displayName),
            title: Text(friend.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.statusText),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                    const SizedBox(width: 4),
                    Text(mutualText, style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            trailing: busy
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<_FriendAction>(
                    tooltip: 'More actions',
                    onSelected: (action) {
                      switch (action) {
                        case _FriendAction.unfriend:
                          _confirmUnfriend(friend);
                          break;
                        case _FriendAction.block:
                          _handleBlock(friend);
                          break;
                        case _FriendAction.report:
                          _handleReport(friend);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: _FriendAction.unfriend,
                        child: Text('Unfriend'),
                      ),
                      PopupMenuItem(
                        value: _FriendAction.block,
                        child: Text('Block user'),
                      ),
                      PopupMenuItem(
                        value: _FriendAction.report,
                        child: Text('Report user'),
                      ),
                    ],
                  ),
          ),
          if (friend.recentWalks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRecentWalkPills(friend.recentWalks, theme),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Invite to walk'),
                onPressed: busy ? null : () => _showInviteSheet(friend),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFriendProfile(_FriendCardData friend) {
    Navigator.of(context).pushNamed(
      FriendProfileScreen.routeName,
      arguments: FriendProfileScreenArgs(
        userId: friend.userId,
        displayName: friend.displayName,
        photoUrl: friend.photoUrl,
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, _FriendActivityItem item) {
    final theme = Theme.of(context);
    final subtitle =
        '${_describeActivity(item.activity)} | '
        '${_formatRelativeTime(item.activity.timestamp)}';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: _buildAvatar(theme, item.photoUrl, item.friendName),
        title: Text(item.friendName),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildRecentWalkPills(
    List<_FriendWalkActivity> walks,
    ThemeData theme,
  ) {
    final chips = walks
        .take(3)
        .map((walk) {
          final distance = _formatDistance(walk.distanceKm);
          var label = _describeActivity(walk);
          if (distance != null) {
            label = '$label | $distance';
          }
          label = '$label | ${_formatRelativeTime(walk.timestamp)}';
          return Chip(
            label: Text(label),
            backgroundColor: theme.colorScheme.primaryContainer.withAlpha(90),
          );
        })
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _buildAvatar(ThemeData theme, String? photoUrl, String displayName) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(photoUrl));
    }
    final initial = _initialForName(displayName);
    return CircleAvatar(
      backgroundColor: theme.colorScheme.primary.withAlpha(30),
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showInviteSheet(_FriendCardData friend) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final selection = await showModalBottomSheet<_InviteCandidate>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.75,
        child: _InviteFriendSheet(friend: friend, hostUid: user.uid),
      ),
    );

    if (selection == null) return;

    final link = InviteUtils.buildInviteLink(
      walkId: selection.walkId,
      shareCode: selection.shareCode,
    );
    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selection.title} invite link copied. Share it with '
          '${friend.displayName}.',
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, _FriendRequestItem request) {
    final theme = Theme.of(context);
    final isProcessing = _processingRequests.contains(request.requestId);
    final subtitle = request.sentAt == null
        ? 'Sent just now'
        : 'Sent ${_formatRelativeTime(request.sentAt)}';
    final busy =
        _blocking.contains(request.fromUserId) ||
        _reporting.contains(request.fromUserId);
    final placeholderFriend = _FriendCardData(
      userId: request.fromUserId,
      displayName: request.displayName ?? request.fromUserId,
      email: request.email,
      photoUrl: request.photoUrl,
      bio: null,
      statusText: 'Pending friend request',
      mutualFriends: 0,
      recentWalks: const <_FriendWalkActivity>[],
    );

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withAlpha(30),
              backgroundImage:
                  request.photoUrl != null && request.photoUrl!.isNotEmpty
                  ? NetworkImage(request.photoUrl!)
                  : null,
              child: (request.photoUrl == null || request.photoUrl!.isEmpty)
                  ? Text(
                      _initialFor(request),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            title: Text(request.displayName ?? request.fromUserId),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.email != null && request.email!.isNotEmpty)
                  Text(request.email!, style: theme.textTheme.bodySmall),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
            trailing: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<_FriendAction>(
                    tooltip: 'More actions',
                    onSelected: (action) {
                      switch (action) {
                        case _FriendAction.unfriend:
                          break;
                        case _FriendAction.block:
                          _handleBlock(placeholderFriend);
                          break;
                        case _FriendAction.report:
                          _handleReport(placeholderFriend);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: _FriendAction.block,
                        child: Text('Block user'),
                      ),
                      PopupMenuItem(
                        value: _FriendAction.report,
                        child: Text('Report user'),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _handleRequestAction(request, accept: true),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _handleRequestAction(request, accept: false),
                    child: const Text('Decline'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find Friends',
            onPressed: () async {
              await Navigator.of(context).pushNamed('/friend-search');
              if (mounted) {
                _loadData();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: _buildContent(context),
              ),
            ),
    );
  }
}

class _FriendRequestItem {
  const _FriendRequestItem({
    required this.requestId,
    required this.fromUserId,
    this.displayName,
    this.email,
    this.photoUrl,
    this.sentAt,
  });

  final String requestId;
  final String fromUserId;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final DateTime? sentAt;
}

class _FriendCardData {
  const _FriendCardData({
    required this.userId,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.bio,
    required this.statusText,
    required this.mutualFriends,
    required this.recentWalks,
  });

  final String userId;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String? bio;
  final String statusText;
  final int mutualFriends;
  final List<_FriendWalkActivity> recentWalks;
}

class _FriendWalkActivity {
  const _FriendWalkActivity({
    required this.walkId,
    required this.joinedAt,
    this.completedAt,
    this.status,
    this.distanceKm,
  });

  final String walkId;
  final DateTime joinedAt;
  final DateTime? completedAt;
  final String? status;
  final double? distanceKm;

  DateTime get timestamp => completedAt ?? joinedAt;
}

class _FriendActivityItem {
  const _FriendActivityItem({
    required this.friendId,
    required this.friendName,
    this.photoUrl,
    required this.activity,
  });

  final String friendId;
  final String friendName;
  final String? photoUrl;
  final _FriendWalkActivity activity;
}

class _ReportPayload {
  const _ReportPayload({required this.reason, this.notes});

  final String reason;
  final String? notes;
}

class _InviteCandidate {
  _InviteCandidate({
    required this.walkId,
    required this.title,
    required this.startTime,
    required this.visibility,
    this.shareCode,
  });

  factory _InviteCandidate.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _InviteCandidate(
      walkId: doc.id,
      title: (data['title'] ?? 'Untitled walk').toString(),
      startTime: _readTimestamp(data['dateTime']) ?? DateTime.now(),
      visibility: (data['visibility'] ?? 'open').toString(),
      shareCode: (data['shareCode'] as String?)?.trim(),
    );
  }

  final String walkId;
  final String title;
  final DateTime startTime;
  final String visibility;
  final String? shareCode;

  bool get isPrivate => visibility.toLowerCase() == 'private';
  bool get canShare =>
      !isPrivate || (shareCode != null && shareCode!.isNotEmpty);
  String get visibilityLabel => isPrivate ? 'Private walk' : 'Open walk';
  String get formattedStart =>
      DateFormat('EEE, MMM d | h:mm a').format(startTime);
}

enum _FriendAction { unfriend, block, report }

class _InviteFriendSheet extends StatefulWidget {
  const _InviteFriendSheet({required this.friend, required this.hostUid});

  final _FriendCardData friend;
  final String hostUid;

  @override
  State<_InviteFriendSheet> createState() => _InviteFriendSheetState();
}

class _InviteFriendSheetState extends State<_InviteFriendSheet> {
  late Future<List<_InviteCandidate>> _upcomingWalksFuture;

  @override
  void initState() {
    super.initState();
    _upcomingWalksFuture = _loadWalks();
  }

  Future<List<_InviteCandidate>> _loadWalks() async {
    try {
      final now = DateTime.now().subtract(const Duration(hours: 1));
      debugPrint(
        '🔍 Loading walks for hostUid: ${widget.hostUid}, after: $now',
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('walks')
          .where('hostUid', isEqualTo: widget.hostUid)
          .where('cancelled', isEqualTo: false)
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('dateTime')
          .limit(25)
          .get();

      debugPrint('✅ Found ${snapshot.docs.length} upcoming walks');

      final candidates = snapshot.docs
          .map((doc) => _InviteCandidate.fromDoc(doc))
          .toList(growable: false);

      for (final c in candidates) {
        debugPrint(
          '  - ${c.title}: private=${c.isPrivate}, code=${c.shareCode}, canShare=${c.canShare}',
        );
      }

      return candidates;
    } catch (e, st) {
      debugPrint('❌ Error loading walks: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Invite ${widget.friend.displayName}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick one of your upcoming walks to generate an invite link.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<_InviteCandidate>>(
                future: _upcomingWalksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _InviteErrorState(
                      onRetry: () {
                        setState(() {
                          _upcomingWalksFuture = _loadWalks();
                        });
                      },
                    );
                  }

                  final walks = snapshot.data ?? const [];
                  if (walks.isEmpty) {
                    return _InviteEmptyState(
                      friendName: widget.friend.displayName,
                    );
                  }

                  return ListView.separated(
                    itemCount: walks.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final candidate = walks[index];
                      return _InviteOptionTile(
                        candidate: candidate,
                        onSelected: candidate.canShare
                            ? () => Navigator.of(context).pop(candidate)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteOptionTile extends StatelessWidget {
  const _InviteOptionTile({required this.candidate, this.onSelected});

  final _InviteCandidate candidate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = candidate.isPrivate
        ? (candidate.canShare
              ? 'Private walk | invite code ready'
              : 'Private walk | open event details to generate a code')
        : 'Open walk | anyone with the link can request to join';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Icon(
          candidate.isPrivate
              ? Icons.lock_outline_rounded
              : Icons.public_rounded,
          color: candidate.isPrivate
              ? theme.colorScheme.tertiary
              : theme.colorScheme.primary,
        ),
        title: Text(
          candidate.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidate.formattedStart),
            Text(statusText, style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: candidate.canShare
            ? FilledButton(onPressed: onSelected, child: const Text('Invite'))
            : Icon(Icons.info_outline, color: theme.colorScheme.error),
        onTap: onSelected,
        enabled: candidate.canShare,
      ),
    );
  }
}

class _InviteEmptyState extends StatelessWidget {
  const _InviteEmptyState({required this.friendName});

  final String friendName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'No upcoming walks to share',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a walk first, then send ${friendName.split(' ').first} a link.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InviteErrorState extends StatelessWidget {
  const _InviteErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40),
          const SizedBox(height: 12),
          const Text('Unable to load your walks right now.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}
