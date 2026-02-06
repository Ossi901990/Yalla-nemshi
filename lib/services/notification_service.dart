// lib/services/notification_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../models/walk_event.dart';
import '../screens/dm_chat_screen.dart';
import '../screens/active_walk_screen.dart';
import '../screens/review_walk_screen.dart';
import 'walk_history_service.dart';
import 'notification_storage.dart';
import 'app_preferences.dart';
import 'crash_service.dart';
import 'walk_control_service.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  // Handle background notification here if needed
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  FirebaseMessaging? _messagingOverride;
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  String? _currentToken;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _notificationListener;
  Map<String, String?>? _pendingDmNavigation;
  bool _walkStartDialogOpen = false;
  String? _lastWalkStartDialogWalkId;
  bool _walkEndDialogOpen = false;
  String? _lastWalkEndDialogWalkId;

  /// Initialize FCM and request permissions
  static Future<void> init() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('🔔🔔🔔 NOTIFICATION SERVICE INIT - Current User: ${currentUser?.uid}');
      debugPrint('🔔🔔🔔 NOTIFICATION SERVICE INIT - Email: ${currentUser?.email}');
      debugPrint('🔔🔔🔔 NOTIFICATION SERVICE INIT - Display Name: ${currentUser?.displayName}');
      
      final instance = NotificationService.instance;

      // Background message handler is registered in main.dart (must be top-level)

      // Request permissions (iOS requires explicit request)
      await instance._requestPermissions();

      // Get and store FCM token
      await instance._initializeToken();

      // Listen for token refresh
      instance._listenForTokenRefresh();

      // Listen for foreground messages
      instance._listenForForegroundMessages();

      // Handle notification taps when app is opened from terminated state
      instance._handleInitialMessage();

      // Persist tokens when auth state changes
      instance._listenForAuthChanges();

      debugPrint('✅ NotificationService initialized');
    } catch (e, st) {
      debugPrint('❌ NotificationService init error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'NotificationService initialization failed',
      );
    }
  }

  /// Start listening to Firestore notifications for current user
  void startListeningToNotifications(String uid) {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('📡 NOTIFICATION SERVICE - Starting listener for user: ${user?.uid}');
    debugPrint('📡 NOTIFICATION SERVICE - User email: ${user?.email}');
    debugPrint('📡 NOTIFICATION SERVICE - Display name: ${user?.displayName}');
    debugPrint('🔔 Starting notification listener for user: $uid');
    
    // Cancel existing listener if any
    _notificationListener?.cancel();
    
    _notificationListener = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('expiresAt', isGreaterThan: Timestamp.now()) // Only non-expired
        .orderBy('timestamp', descending: true) // Newest first
        .limit(100) // Last 100 notifications
        .snapshots()
        .listen(
          (snapshot) async {
            debugPrint('📬 Received ${snapshot.docChanges.length} notification changes');
            
            // Get existing notifications to avoid duplicates
            final existingNotifications = await NotificationStorage.getNotifications();
            final existingIds = existingNotifications.map((n) => n.id).toSet();
            
            for (var change in snapshot.docChanges) {
              debugPrint('   Change type: ${change.type}, doc: ${change.doc.id}');
              
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data() as Map<String, dynamic>;
                debugPrint('   Raw data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
                
                final notif = AppNotification.fromFirestore(data, change.doc.id);
                
                // Don't add if already exists in local storage
                if (existingIds.contains(notif.id)) {
                  debugPrint('   🔄 SKIPPING: Notification already in local storage (${notif.id})');
                  continue;
                }
                
                // Don't add expired notifications
                if (notif.isExpired) {
                  debugPrint('   ⏱️ SKIPPING: Notification expired');
                  continue;
                }
                
                // Don't show notifications for messages we sent ourselves
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                final senderId = notif.userId ?? notif.data?['senderId'] as String?;
                debugPrint('➕ New notification: ${notif.type.name} - ${notif.title}');
                debugPrint('   Doc ID: ${notif.id}');
                debugPrint('   Current user: $currentUid');
                debugPrint('   Sender ID: $senderId');
                debugPrint('   Match: ${currentUid == senderId}');
                
                if (currentUid != null && senderId != null && currentUid == senderId) {
                  debugPrint('   🚫 SKIPPING: This is a notification for a message we sent');
                  continue;
                }
                
                await NotificationStorage.add(notif);

                if (notif.type == NotificationType.walkStarting) {
                  _showWalkStartConfirmationDialog(notif);
                } else if (notif.type == NotificationType.walkEnded) {
                  _showWalkEndedDialog(notif);
                }
              } else if (change.type == DocumentChangeType.modified) {
                final notif = AppNotification.fromFirestore(
                  change.doc.data() as Map<String, dynamic>,
                  change.doc.id,
                );
                debugPrint('🔄 Updated notification: ${notif.id}');
                await NotificationStorage.update(notif);
              } else if (change.type == DocumentChangeType.removed) {
                debugPrint('➖ Removed notification: ${change.doc.id}');
                await NotificationStorage.deleteById(change.doc.id);
              }
            }
          },
          onError: (error, stackTrace) {
            debugPrint('❌ Notification listener error: $error');
            CrashService.recordError(
              error,
              stackTrace,
              reason: 'Firestore notification listener failed',
            );
          },
        );
  }

  Future<void> _showWalkStartConfirmationDialog(AppNotification notification) async {
    final context = navigatorKey.currentState?.overlay?.context;
    final walkId = notification.walkId ?? notification.data?['walkId'] as String?;
    if (context == null || walkId == null) return;

    if (_walkStartDialogOpen && _lastWalkStartDialogWalkId == walkId) {
      return;
    }

    _walkStartDialogOpen = true;
    _lastWalkStartDialogWalkId = walkId;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Walk is starting'),
          content: Text(
            notification.message.isNotEmpty
                ? notification.message
                : 'Please confirm you are joining this walk.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await WalkHistoryService.instance.confirmParticipation(walkId);
                  final snackbarContext = navigatorKey.currentState?.overlay?.context;
                  if (snackbarContext != null && snackbarContext.mounted) {
                    ScaffoldMessenger.of(snackbarContext).showSnackBar(
                      const SnackBar(content: Text('✅ Confirmation sent')),
                    );
                  }
                } catch (e, st) {
                  CrashService.recordError(
                    e,
                    st,
                    reason: 'Walk start confirmation failed',
                  );
                }
              },
              child: const Text('Confirm'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => ActiveWalkScreen(walkId: walkId),
                  ),
                );
              },
              child: const Text('Open walk'),
            ),
          ],
        );
      },
    );

    _walkStartDialogOpen = false;
  }

  Future<void> _showWalkEndedDialog(AppNotification notification) async {
    final context = navigatorKey.currentState?.overlay?.context;
    final walkId = notification.walkId ?? notification.data?['walkId'] as String?;
    if (context == null || walkId == null) return;

    if (_walkEndDialogOpen && _lastWalkEndDialogWalkId == walkId) {
      return;
    }

    _walkEndDialogOpen = true;
    _lastWalkEndDialogWalkId = walkId;

    final distance = (notification.data?['actualDistanceKm'] as num?)?.toDouble();
    final duration = (notification.data?['actualDurationMinutes'] as num?)?.round();
    String statsMessage = '';
    if (distance != null && distance > 0 && duration != null && duration > 0) {
      statsMessage =
          'You walked ${distance.toStringAsFixed(1)} km in $duration min.';
    } else if (distance != null && distance > 0) {
      statsMessage = 'You walked ${distance.toStringAsFixed(1)} km.';
    } else if (duration != null && duration > 0) {
      statsMessage = 'You walked for $duration min.';
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final walk = await WalkControlService().getWalk(walkId);
      if (walk == null) return;
      final isParticipant = currentUid != null &&
          currentUid != walk.hostUid &&
          (walk.joinedUserUids.contains(currentUid) ||
              walk.participantStates.containsKey(currentUid));
      if (!isParticipant) return;
    } catch (_) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Walk ended 🎉'),
          content: Text(
            statsMessage.isNotEmpty
                ? statsMessage
                : (notification.message.isNotEmpty
                    ? notification.message
                    : 'Your walk has ended. Want to leave a review?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  final walk =
                      await WalkControlService().getWalk(walkId);
                  final navContext = navigatorKey.currentState?.overlay?.context;
                  final currentUid =
                      FirebaseAuth.instance.currentUser?.uid;
                  final isParticipant = walk != null &&
                      currentUid != null &&
                      currentUid != walk.hostUid &&
                      (walk.joinedUserUids.contains(currentUid) ||
                          walk.participantStates.containsKey(currentUid));
                  if (isParticipant && navContext != null && navContext.mounted) {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (_) => ReviewWalkScreen(walk: walk),
                      ),
                    );
                  } else if (navContext != null && navContext.mounted) {
                    ScaffoldMessenger.of(navContext).showSnackBar(
                      const SnackBar(content: Text('Unable to load walk')),
                    );
                  }
                } catch (e, st) {
                  CrashService.recordError(
                    e,
                    st,
                    reason: 'Walk ended review navigation failed',
                  );
                }
              },
              child: const Text('Review walk'),
            ),
          ],
        );
      },
    );

    _walkEndDialogOpen = false;
  }

  /// Stop listening to notifications
  void stopListeningToNotifications() {
    debugPrint('🔕 Stopping notification listener');
    _notificationListener?.cancel();
    _notificationListener = null;
  }

  /// Create a notification in Firestore (for local/testing)
  Future<void> createNotification({
    required String uid,
    required NotificationType type,
    required String title,
    required String message,
    String? walkId,
    String? userId,
    String? threadId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final expiresAt = DateTime.now().add(const Duration(days: 30));
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'type': type.name,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        if (walkId != null) 'walkId': walkId,
        if (userId != null) 'userId': userId,
        if (threadId != null) 'threadId': threadId,
        if (data != null) 'data': data,
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
      
      debugPrint('✅ Created notification: $type for user $uid');
    } catch (e, st) {
      debugPrint('❌ Failed to create notification: $e');
      CrashService.recordError(e, st, reason: 'Create notification failed');
    }
  }

  /// Mark notification as read in Firestore
  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      
      debugPrint('✅ Marked notification as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Failed to mark as read: $e');
    }
  }

  /// Delete notification from Firestore
  Future<void> deleteNotification(String uid, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      debugPrint('✅ Deleted notification: $notificationId');
    } catch (e) {
      debugPrint('❌ Failed to delete notification: $e');
    }
  }

  /// Delete all walk-related notifications
  Future<void> deleteWalkNotifications(String uid, String walkId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('walkId', isEqualTo: walkId)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      debugPrint('✅ Deleted ${snapshot.docs.length} walk notifications for walk: $walkId');
    } catch (e) {
      debugPrint('❌ Failed to delete walk notifications: $e');
    }
  }

  /// Delete all notifications for a user in Firestore
  Future<void> deleteAllNotifications(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint(
        '✅ Deleted ${snapshot.docs.length} notifications for user: $uid',
      );
    } catch (e) {
      debugPrint('❌ Failed to delete all notifications: $e');
    }
  }

  /// Handle notification tap - navigate to appropriate screen
  void handleNotificationTap(BuildContext context, AppNotification notification) {
    debugPrint('👆 Notification tapped: ${notification.type.name}');
    
    switch (notification.type) {
      case NotificationType.walkJoined:
      case NotificationType.walkCancelled:
      case NotificationType.walkRescheduled:
      case NotificationType.walkReminder:
      case NotificationType.walkStarting:
      case NotificationType.nearbyWalk:
      case NotificationType.suggestedWalk:
        if (notification.walkId != null) {
          // Navigate to walk details
          // You'll need to import EventDetailsScreen and fetch walk
          debugPrint('Navigate to walk: ${notification.walkId}');
          // navigator.pushNamed('/walk-details', arguments: notification.walkId);
        }
        break;
      case NotificationType.walkEnded:
        if (notification.walkId != null) {
          () async {
            final walk =
                await WalkControlService().getWalk(notification.walkId!);
            if (walk == null) return;
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final isParticipant = currentUid != null &&
                currentUid != walk.hostUid &&
                (walk.joinedUserUids.contains(currentUid) ||
                    walk.participantStates.containsKey(currentUid));
            if (!isParticipant) return;
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReviewWalkScreen(walk: walk),
              ),
            );
          }();
        }
        break;
        
      case NotificationType.dmMessage:
        if (notification.threadId != null && notification.userId != null) {
          _navigateToDmThread(
            threadId: notification.threadId,
            friendUid: notification.userId,
            friendName: notification.data?['friendName'] as String? ?? 'Friend',
            friendPhotoUrl: notification.data?['friendPhotoUrl'] as String?,
          );
        }
        break;
        
      case NotificationType.friendRequest:
        if (notification.userId != null) {
          // Navigate to friend profile or requests screen
          debugPrint('Navigate to friend request from: ${notification.userId}');
        }
        break;
        
      case NotificationType.badgeEarned:
      case NotificationType.milestoneReached:
        // Navigate to profile/badges screen
        debugPrint('Navigate to badges/achievements');
        break;
        
      case NotificationType.weeklyDigest:
      case NotificationType.monthlyAchievements:
        // Navigate to analytics screen
        debugPrint('Navigate to analytics');
        // navigator.pushNamed('/analytics');
        break;
        
      default:
        debugPrint('No navigation action for type: ${notification.type.name}');
    }
  }

  /// Request notification permissions (critical for iOS)
  Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permissions granted');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ Provisional notification permissions granted');
      } else {
        debugPrint('❌ Notification permissions denied');
      }
    } catch (e, st) {
      debugPrint('❌ Permission request error: $e');
      CrashService.recordError(e, st, reason: 'FCM permission request failed');
    }
  }

  /// Get FCM token and store it in Firestore
  Future<void> _initializeToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('📱 FCM Token: ${token.substring(0, 20)}...');
        await _persistTokenForCurrentUser(tokenOverride: token);
      } else {
        debugPrint('⚠️ FCM token is null');
      }
    } catch (e, st) {
      debugPrint('❌ Token initialization error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'FCM token initialization failed',
      );
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token, User user) async {
    try {
      debugPrint(
        '💾 Saving FCM token for ${user.uid} at users/${user.uid}/fcmTokens/${token.substring(0, 12)}...',
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
            'token': token,
            'platform': defaultTargetPlatform.name,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('✅ FCM token saved to Firestore for ${user.uid}');
    } catch (e, st) {
      debugPrint('❌ Token save error: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'Failed to save FCM token to Firestore',
      );
    }
  }

  /// Listen for token refresh
  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh
        .listen((newToken) {
          debugPrint('🔄 FCM token refreshed');
          _currentToken = newToken;
          _persistTokenForCurrentUser(tokenOverride: newToken);
        })
        .onError((error, stackTrace) {
          debugPrint('❌ Token refresh error: $error');
          CrashService.recordError(
            error,
            stackTrace,
            reason: 'FCM token refresh failed',
          );
        });
  }

  /// Listen for foreground messages
  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage
        .listen((RemoteMessage message) {
          debugPrint(
            'Foreground message received: ${message.notification?.title}',
          );

          // Show local notification
          if (message.notification != null) {
            _showLocalNotification(message);
          }

          // Handle data payload
          if (message.data.isNotEmpty) {
            _handleNotificationData(message.data);
          }
        })
        .onError((error, stackTrace) {
          debugPrint('❌ Foreground message error: $error');
          CrashService.recordError(
            error,
            stackTrace,
            reason: 'FCM foreground message handling failed',
          );
        });
  }

  /// Show local notification when app is in foreground
  void _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // ✅ Don't store FCM notifications when app is in foreground
    // The Firestore listener already handles persistent notifications
    // FCM push notifications are only needed for background/terminated state
    debugPrint('📲 FCM notification received in foreground (not stored, Firestore handles it)');
    debugPrint('   Title: ${notification.title}');
    debugPrint('   Body: ${notification.body}');
    
    // Note: If you want to show a banner/toast in the future, add it here
    // For now, Firestore listener provides real-time updates to the UI
  }

  /// Handle notification data payload
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    debugPrint('📦 Notification data type: $type');

    if (type == 'dm_message') {
      _navigateToDmThread(
        threadId: data['threadId'] as String?,
        friendUid: data['senderId'] as String? ?? data['friendUid'] as String?,
        friendName: data['senderName'] as String? ?? 'Friend',
        friendPhotoUrl: data['senderPhotoUrl'] as String?,
      );
    }
  }

  /// Handle initial message when app is opened from terminated state
  void _handleInitialMessage() {
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🚀 App opened from notification: ${message.messageId}');
        if (message.data.isNotEmpty) {
          _handleNotificationData(message.data);
        }
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '📲 App opened from background notification: ${message.messageId}',
      );
      if (message.data.isNotEmpty) {
        _handleNotificationData(message.data);
      }
    });
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _currentToken != null) {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(_currentToken)
            .delete();

        debugPrint('✅ FCM token deleted from Firestore');
      }

      // Delete token from FCM
      await _messaging.deleteToken();
      _currentToken = null;
      debugPrint('✅ FCM token deleted');
    } catch (e, st) {
      debugPrint('❌ Token deletion error: $e');
      CrashService.recordError(e, st, reason: 'FCM token deletion failed');
    }
  }

  Future<void> scheduleWalkReminder(WalkEvent event) async {
    // Respect setting toggle if you use it (walk reminders enabled)
    final enabled = await AppPreferences.getWalkRemindersEnabled();
    if (!enabled) return;

    final n = AppNotification(
      id: 'reminder_${event.firestoreId.isNotEmpty ? event.firestoreId : event.id}',
      type: NotificationType.walkReminder,
      title: 'Walk will start soon',
      message: 'Your walk "${event.title}" is coming up.',
      timestamp: DateTime.now(),
      isRead: false,
      walkId: event.firestoreId.isNotEmpty ? event.firestoreId : event.id,
      expiresAt: event.dateTime.add(const Duration(hours: 2)), // Expire 2 hours after walk
    );

    await NotificationStorage.add(n);
  }

  /// Optional: remove/cancel reminder (for now we just do nothing safely).
  Future<void> cancelWalkReminder(WalkEvent event) async {
    // If later you implement removing by id, do it here.
    // For now, keeping it safe and no-op.
  }

  /// Adds a nearby-walk alert notification to local storage.
  Future<void> showNearbyWalkAlert(WalkEvent event) async {
    final enabled = await AppPreferences.getNearbyAlertsEnabled();
    if (!enabled) return;

    final n = AppNotification(
      id: 'nearby_${event.firestoreId.isNotEmpty ? event.firestoreId : event.id}',
      type: NotificationType.nearbyWalk,
      title: 'New nearby walk',
      message: '"${event.title}" is available nearby.',
      timestamp: DateTime.now(),
      isRead: false,
      walkId: event.firestoreId.isNotEmpty ? event.firestoreId : event.id,
      expiresAt: event.dateTime.add(const Duration(hours: 1)), // Expire 1 hour after walk starts
    );

    await NotificationStorage.add(n);
  }

  void _navigateToDmThread({
    required String? threadId,
    required String? friendUid,
    required String friendName,
    String? friendPhotoUrl,
    bool allowQueue = true,
  }) {
    if (threadId == null || friendUid == null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final navigator = navigatorKey.currentState;
    if (user == null || navigator == null) {
      if (allowQueue) {
        _pendingDmNavigation = {
          'threadId': threadId,
          'friendUid': friendUid,
          'friendName': friendName,
          'friendPhotoUrl': friendPhotoUrl,
        };
      }
      return;
    }

    navigator.pushNamed(
      DmChatScreen.routeName,
      arguments: DmChatScreenArgs(
        threadId: threadId,
        friendUid: friendUid,
        friendName: friendName,
        friendPhotoUrl: friendPhotoUrl,
      ),
    );
  }

  void handlePendingNavigation() {
    final data = _pendingDmNavigation;
    if (data == null) return;
    _pendingDmNavigation = null;
    _navigateToDmThread(
      threadId: data['threadId'],
      friendUid: data['friendUid'],
      friendName: data['friendName'] ?? 'Friend',
      friendPhotoUrl: data['friendPhotoUrl'],
      allowQueue: false,
    );
  }

  void _listenForAuthChanges() {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user == null) {
        stopListeningToNotifications();
        return;
      }
      await _persistTokenForUser(user);
      
      // Start listening to Firestore notifications
      startListeningToNotifications(user.uid);
    });
  }

  Future<void> _persistTokenForCurrentUser({String? tokenOverride}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ Cannot persist token: user not logged in');
      return;
    }
    await _persistTokenForUser(user, tokenOverride: tokenOverride);
  }

  Future<void> _persistTokenForUser(User user, {String? tokenOverride}) async {
    try {
      final token =
          tokenOverride ?? _currentToken ?? await _messaging.getToken();
      if (token == null) {
        debugPrint('⚠️ Cannot persist token: token is null');
        return;
      }
      _currentToken = token;
      await _saveTokenToFirestore(token, user);
    } catch (e, st) {
      debugPrint('❌ Failed to persist FCM token for ${user.uid}: $e');
      CrashService.recordError(
        e,
        st,
        reason: 'Persist FCM token for user ${user.uid}',
      );
    }
  }

  @visibleForTesting
  void overrideMessaging(FirebaseMessaging messaging) {
    _messagingOverride = messaging;
  }
}
