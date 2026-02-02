// lib/services/app_preferences.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  // ===== Keys =====
  static const _keyDefaultDistanceKm = 'default_distance_km';
  static const _keyDefaultGender = 'default_gender';
  static const _keyWalkReminders = 'walk_reminders_enabled';
  static const _keyNearbyAlerts = 'nearby_alerts_enabled';
  static const _keyWeeklyGoalKm = 'weekly_goal_km';
  static const _keyUserCity = 'user_city';
  static const _keyUserCityNormalized = 'user_city_normalized';
  static const _keyPushWalks = 'push_walks_enabled';
  static const _keyPushChat = 'push_chat_enabled';
  static const _keyPushUpdates = 'push_updates_enabled';
  static const _keySearchHistory = 'search_history_v1';
  static const _keySavedSearchFilters = 'search_filter_sets_v1';

  // ===== DEFAULT VALUES (used if nothing saved yet) =====
  static const double defaultDistanceKmFallback = 3.0;
  static const String defaultGenderFallback = 'Mixed';
  static const bool walkRemindersFallback = true;
  static const bool nearbyAlertsFallback = true;
  static const double weeklyGoalKmFallback = 10.0;
  static const bool pushWalksFallback = true;
  static const bool pushChatFallback = true;
  static const bool pushUpdatesFallback = true;

  // ===== Distance =====
  static Future<double> getDefaultDistanceKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyDefaultDistanceKm) ?? defaultDistanceKmFallback;
  }

  static Future<void> setDefaultDistanceKm(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyDefaultDistanceKm, value);
  }

  // ===== Gender preference =====
  static Future<String> getDefaultGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultGender) ?? defaultGenderFallback;
  }

  static Future<void> setDefaultGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultGender, gender);
  }

  // ===== Notifications: walk reminders =====
  static Future<bool> getWalkRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWalkReminders) ?? walkRemindersFallback;
  }

  static Future<void> setWalkRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWalkReminders, enabled);
  }

  // ===== Notifications: nearby alerts =====
  static Future<bool> getNearbyAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNearbyAlerts) ?? nearbyAlertsFallback;
  }

  static Future<void> setNearbyAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNearbyAlerts, enabled);
  }

  // ===== Weekly goal (km) =====
  static Future<double> getWeeklyGoalKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyWeeklyGoalKm) ?? weeklyGoalKmFallback;
  }

  static Future<void> setWeeklyGoalKm(double km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWeeklyGoalKm, km);
  }

  // ===== User's current city =====
  static Future<String?> getUserCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserCity);
  }

  static Future<String?> getUserCityNormalized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserCityNormalized);
  }

  static Future<void> setUserCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserCity, city);
    final normalized = normalizeCity(city);
    if (normalized.isNotEmpty) {
      await prefs.setString(_keyUserCityNormalized, normalized);
    }
  }

  static String normalizeCity(String city) {
    final raw = city.trim();
    if (raw.isEmpty) return '';
    final primary = raw.split(',').first.trim();
    final cleaned = primary.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.toLowerCase();
  }

  // ===== Push Notifications =====
  static Future<bool> getPushWalksEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPushWalks) ?? pushWalksFallback;
  }

  static Future<void> setPushWalksEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushWalks, enabled);
  }

  static Future<bool> getPushChatEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPushChat) ?? pushChatFallback;
  }

  static Future<void> setPushChatEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushChat, enabled);
  }

  static Future<bool> getPushUpdatesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPushUpdates) ?? pushUpdatesFallback;
  }

  static Future<void> setPushUpdatesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushUpdates, enabled);
  }

  // ===== Search helpers =====
  static Future<List<String>> getSearchHistory({int maxItems = 12}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_keySearchHistory) ?? const [];
    if (history.length <= maxItems) return history;
    return history.sublist(0, maxItems);
  }

  static Future<void> addSearchHistoryTerm(
    String raw,
    {
      int maxItems = 12,
    }
  ) async {
    final term = raw.trim();
    if (term.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_keySearchHistory) ?? <String>[];

    history.removeWhere((entry) => entry.toLowerCase() == term.toLowerCase());
    history.insert(0, term);
    if (history.length > maxItems) {
      history.removeRange(maxItems, history.length);
    }

    await prefs.setStringList(_keySearchHistory, history);
  }

  static Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySearchHistory);
  }

  static Future<List<String>> getSavedSearchFilterJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySavedSearchFilters) ?? const [];
  }

  static Future<void> setSavedSearchFilterJson(List<String> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySavedSearchFilters, payload);
  }
}
