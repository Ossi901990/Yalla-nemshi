// lib/services/notification_storage.dart
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

class NotificationStorage {
  static String _keyForUser(String uid) => 'app_notifications_$uid';

  static Future<List<AppNotification>> getNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyForUser(uid));

    if (raw == null) return [];

    return raw
        .map((s) {
          try {
            final map = jsonDecode(s) as Map<String, dynamic>;
            return AppNotification.fromJson(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<AppNotification>()
        .toList();
  }

  static Future<void> _save(List<AppNotification> list) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_keyForUser(uid), raw);
  }

  static Future<void> add(AppNotification notification) async {
    final list = await getNotifications();
    list.add(notification);
    await _save(list);
  }

  // ✅ Backwards-compatible alias (in case other files call addNotification)
  static Future<void> addNotification(AppNotification notification) async {
    await add(notification);
  }

  static Future<void> clearNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyForUser(uid));
  }

  /// Update one notification (used for read / unread)
  static Future<void> update(AppNotification updated) async {
    final list = await getNotifications();
    final index = list.indexWhere((n) => n.id == updated.id);
    if (index == -1) return;
    list[index] = updated;
    await _save(list);
  }

  /// Mark all notifications as read (so badge becomes 0)
  static Future<void> markAllRead() async {
    final list = await getNotifications();
    final updated = list
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
    await _save(updated);
  }

  // ✅ Count only unread notifications
  static Future<int> getUnreadCount() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).length;
  }

  /// Delete notification by ID
  static Future<void> deleteById(String id) async {
    final list = await getNotifications();
    final filtered = list.where((n) => n.id != id).toList();
    await _save(filtered);
  }

  /// Delete all walk-related notifications
  static Future<void> deleteByWalkId(String walkId) async {
    final list = await getNotifications();
    final filtered = list.where((n) => n.walkId != walkId).toList();
    await _save(filtered);
  }

  /// Delete all expired notifications
  static Future<void> deleteExpired() async {
    final list = await getNotifications();
    final now = DateTime.now();
    final filtered = list.where((n) {
      if (n.expiresAt == null) return true;
      return n.expiresAt!.isAfter(now);
    }).toList();
    await _save(filtered);
  }

  /// Get notifications by type
  static Future<List<AppNotification>> getByType(NotificationType type) async {
    final list = await getNotifications();
    return list.where((n) => n.type == type).toList();
  }

  /// Get walk-related notifications
  static Future<List<AppNotification>> getByWalkId(String walkId) async {
    final list = await getNotifications();
    return list.where((n) => n.walkId == walkId).toList();
  }
}
