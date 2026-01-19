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
import 'notification_storage.dart';
import 'app_preferences.dart';
import 'crash_service.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  // Handle background notification here if needed
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  FirebaseMessaging? _messagingOverride;
  FirebaseMessaging get _messaging => _messagingOverride ?? FirebaseMessaging.instance;
  String? _currentToken;
  StreamSubscription<User?>? _authSubscription;
  Map<String, String?>? _pendingDmNavigation;

  /// Initialize FCM and request permissions
  static Future<void> init() async {
    try {
      final instance = NotificationService.instance;
      
      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
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
      CrashService.recordError(e, st, reason: 'NotificationService initialization failed');
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
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
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
      CrashService.recordError(e, st, reason: 'FCM token initialization failed');
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
      CrashService.recordError(e, st, reason: 'Failed to save FCM token to Firestore');
    }
  }

  /// Listen for token refresh
  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM token refreshed');
      _currentToken = newToken;
      _persistTokenForCurrentUser(tokenOverride: newToken);
    }).onError((error, stackTrace) {
      debugPrint('❌ Token refresh error: $error');
      CrashService.recordError(error, stackTrace, reason: 'FCM token refresh failed');
    });
  }

  /// Listen for foreground messages
  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Foreground message received: ${message.notification?.title}');
      
      // Show local notification
      if (message.notification != null) {
        _showLocalNotification(message);
      }
      
      // Handle data payload
      if (message.data.isNotEmpty) {
        _handleNotificationData(message.data);
      }
    }).onError((error, stackTrace) {
      debugPrint('❌ Foreground message error: $error');
      CrashService.recordError(error, stackTrace, reason: 'FCM foreground message handling failed');
    });
  }

  /// Show local notification when app is in foreground
  void _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final appNotification = AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? 'Yalla Nemshi',
      message: notification.body ?? '',
      timestamp: DateTime.now(),
      isRead: false,
    );

    await NotificationStorage.addNotification(appNotification);
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
      debugPrint('📲 App opened from background notification: ${message.messageId}');
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
      title: 'Walk will start soon',
      message: 'Your walk "${event.title}" is coming up.',
      timestamp: DateTime.now(),
      isRead: false,
    );

    await NotificationStorage.addNotification(n);
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
      title: 'New nearby walk',
      message: '"${event.title}" is available nearby.',
      timestamp: DateTime.now(),
      isRead: false,
    );

    await NotificationStorage.addNotification(n);
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
    _authSubscription ??=
        FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        return;
      }
      await _persistTokenForUser(user);
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

  Future<void> _persistTokenForUser(
    User user, {
    String? tokenOverride,
  }) async {
    try {
      final token = tokenOverride ?? _currentToken ?? await _messaging.getToken();
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
