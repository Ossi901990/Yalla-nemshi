import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/notification_storage.dart';
import '../services/walk_control_service.dart';
import 'dm_chat_screen.dart';
import 'friend_profile_screen.dart';
import 'analytics_screen.dart';
import 'active_walk_screen.dart';
import 'review_walk_screen.dart';

class NotificationsScreen extends StatefulWidget {
  static const String routeName = '/notifications';

  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('🔔 NOTIFICATIONS SCREEN - Current User: ${user?.uid}');
    debugPrint('🔔 NOTIFICATIONS SCREEN - Email: ${user?.email}');
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final notifications = await NotificationStorage.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await NotificationService.instance.markAsRead(
          user.uid,
          notification.id,
        );
        final updatedNotification = notification.copyWith(isRead: true);
        await NotificationStorage.update(updatedNotification);
        if (mounted) {
          setState(() {
            final index = _notifications.indexWhere((n) => n.id == notification.id);
            if (index != -1) {
              _notifications[index] = notification.copyWith(isRead: true);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  Future<bool> _deleteNotification(AppNotification notification) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await NotificationService.instance.deleteNotification(user.uid, notification.id);
        await NotificationStorage.deleteById(notification.id);

        if (mounted) {
          setState(() {
            _notifications.removeWhere((n) => n.id == notification.id);
          });
        }
        return true;
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationStorage.markAllRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await NotificationStorage.clearNotifications();
        if (mounted) {
          setState(() => _notifications.clear());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear notifications: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    _markAsRead(notification);
    
    debugPrint('🔔 Notification tapped: type=${notification.type}');
    debugPrint('🔔   userId=${notification.userId}, threadId=${notification.threadId}');
    debugPrint('🔔   data=${notification.data}');
    
    // Navigate based on notification type
    switch (notification.type) {
      // Walk-related notifications → event details or walks screen
      case NotificationType.walkStarting:
        if (notification.walkId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveWalkScreen(walkId: notification.walkId!),
            ),
          );
        }
        break;
      case NotificationType.walkJoined:
      case NotificationType.walkLeft:
      case NotificationType.walkInterested:
      case NotificationType.walkFull:
      case NotificationType.participantConfirmed:
      case NotificationType.participantDeclined:
      case NotificationType.walkReviewed:
      case NotificationType.walkCancelled:
      case NotificationType.walkRescheduled:
      case NotificationType.walkLocationChanged:
      case NotificationType.walkReminder:
      case NotificationType.walkHostLeft:
      case NotificationType.nearbyWalk:
      case NotificationType.suggestedWalk:
        // TODO: Navigate to event details when we have the screen
        // For now, just mark as read
        break;
      case NotificationType.walkEnded:
        if (notification.walkId != null) {
          final walk =
              await WalkControlService().getWalk(notification.walkId!);
          if (!mounted) return;
          if (walk != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewWalkScreen(walk: walk),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to load walk')),
            );
          }
        }
        break;

      // Message notifications → DM chat
      case NotificationType.dmMessage:
        debugPrint('🔔 dmMessage - userId: ${notification.userId}, threadId: ${notification.threadId}');
        if (notification.userId != null && notification.threadId != null) {
          debugPrint('🔔 Navigating to DM chat...');
          Navigator.pushNamed(
            context,
            DmChatScreen.routeName,
            arguments: DmChatScreenArgs(
              friendUid: notification.userId!,
              friendName: notification.data?['friendName'] as String? ?? 'User',
              friendPhotoUrl: notification.data?['friendPhotoUrl'] as String?,
              threadId: notification.threadId!,
            ),
          );
        } else {
          debugPrint('🔔 Missing userId or threadId - cannot navigate');
        }
        break;

      case NotificationType.walkChatMessage:
      case NotificationType.hostAnnouncement:
      case NotificationType.mentioned:
        // TODO: Navigate to walk chat when we have the screen
        break;

      // Friend notifications → profile screen
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
      case NotificationType.friendJoinedWalk:
      case NotificationType.friendHosting:
      case NotificationType.friendMilestone:
      case NotificationType.friendBadge:
        if (notification.userId != null) {
          Navigator.pushNamed(
            context,
            FriendProfileScreen.routeName,
            arguments: {'friendId': notification.userId},
          );
        }
        break;

      // Achievement notifications → analytics screen
      case NotificationType.milestoneReached:
      case NotificationType.badgeEarned:
      case NotificationType.streakMilestone:
      case NotificationType.goalAchieved:
      case NotificationType.monthlySummary:
      case NotificationType.leaderboardUpdate:
      case NotificationType.personalRecord:
      case NotificationType.weeklyDigest:
      case NotificationType.monthlyAchievements:
        Navigator.pushNamed(context, AnalyticsScreen.routeName);
        break;

      // Safety and system notifications → just mark as read
      case NotificationType.weatherAlert:
      case NotificationType.safetyCheckIn:
      case NotificationType.emergencyAlert:
      case NotificationType.appUpdate:
      case NotificationType.newFeature:
      case NotificationType.accountSecurity:
      case NotificationType.inactiveReminder:
      case NotificationType.missedGoal:
        // Just mark as read, no navigation needed
        break;
        
      case NotificationType.systemMaintenance:
        // TEMPORARY: Check if this is actually a DM notification with wrong type
        if (notification.threadId != null || notification.data?['threadId'] != null) {
          final threadId = notification.threadId ?? notification.data?['threadId'] as String?;
          final senderId = notification.userId ?? notification.data?['senderId'] as String?;
          final senderName = notification.data?['senderName'] as String? ?? 'User';
          final senderPhotoUrl = notification.data?['senderPhotoUrl'] as String?;
          
          if (threadId != null && senderId != null) {
            debugPrint('🔔 systemMaintenance with DM data - treating as DM message');
            debugPrint('🔔   threadId: $threadId, senderId: $senderId');
            Navigator.pushNamed(
              context,
              DmChatScreen.routeName,
              arguments: DmChatScreenArgs(
                friendUid: senderId,
                friendName: senderName,
                friendPhotoUrl: senderPhotoUrl,
                threadId: threadId,
              ),
            );
          } else {
            debugPrint('🔔 systemMaintenance missing required data: threadId=$threadId, senderId=$senderId');
          }
        }
        break;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFFF7F9F2),
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1ABFC4), const Color(0xFF0D8B8F)]
                    : [const Color(0xFF1ABFC4), const Color(0xFF1DB8C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            'Notifications',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (_notifications.isNotEmpty) ...[
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            onSelected: (value) {
                              if (value == 'mark_all_read') {
                                _markAllRead();
                              } else if (value == 'clear_all') {
                                _clearAll();
                              }
                            },
                            itemBuilder: (context) => [
                              if (unreadCount > 0)
                                const PopupMenuItem(
                                  value: 'mark_all_read',
                                  child: Text('Mark all as read'),
                                ),
                              const PopupMenuItem(
                                value: 'clear_all',
                                child: Text(
                                  'Clear all',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: _notifications.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              return _buildNotificationItem(notification);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see walk updates and messages here',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _deleteNotification(notification);
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            debugPrint('🔔 TAP DETECTED on notification: ${notification.id}');
            await _handleNotificationTap(notification);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? (notification.isRead
                      ? const Color(0xFF0A2533)
                      : const Color(0xFF0D3343))
                  : (notification.isRead
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.95)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bell icon
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABFC4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: const Color(0xFF1ABFC4),
                    size: 20,
                  ),
                ),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'Inter',
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00D97E),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(notification.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
