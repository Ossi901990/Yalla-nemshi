// lib/services/app_preferences.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  // ===== Keys =====
  static const _keyDefaultDistanceKm = 'default_distance_km';
  static const _keyDefaultGender = 'default_gender';
  static const _keyWalkReminders = 'walk_reminders_enabled';
  static const _keyNearbyAlerts = 'nearby_alerts_enabled';
  static const _keyWeeklyGoalKm = 'weekly_goal_km'; // 👈 NEW

  // ===== DEFAULT VALUES (used if nothing saved yet) =====
  static const double defaultDistanceKmFallback = 3.0;
  static const String defaultGenderFallback = 'Mixed';
  static const bool walkRemindersFallback = true;
  static const bool nearbyAlertsFallback = true;
  static const double weeklyGoalKmFallback = 10.0; // 👈 NEW

  // ===== Distance =====
  static Future<double> getDefaultDistanceKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyDefaultDistanceKm) ??
        defaultDistanceKmFallback;
  }

  static Future<void> setDefaultDistanceKm(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyDefaultDistanceKm, value);
  }

  // ===== Gender preference =====
  static Future<String> getDefaultGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultGender) ??
        defaultGenderFallback;
  }

  static Future<void> setDefaultGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultGender, gender);
  }

  // ===== Notifications: walk reminders =====
  static Future<bool> getWalkRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWalkReminders) ??
        walkRemindersFallback;
  }

  static Future<void> setWalkRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWalkReminders, enabled);
  }

  // ===== Notifications: nearby alerts =====
  static Future<bool> getNearbyAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNearbyAlerts) ??
        nearbyAlertsFallback;
  }

  static Future<void> setNearbyAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNearbyAlerts, enabled);
  }

  // ===== Weekly goal (km) =====
  static Future<double> getWeeklyGoalKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyWeeklyGoalKm) ??
        weeklyGoalKmFallback;
  }

  static Future<void> setWeeklyGoalKm(double km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWeeklyGoalKm, km);
  }
}
