// lib/services/local_profile_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

class LocalProfilePrefs {
  static const _keyWalksJoined = 'walksJoined';
  static const _keyEventsHosted = 'eventsHosted';
  static const _keyTotalKm = 'totalKm';

  /// Load saved stats. If nothing saved yet, returns zeros.
  static Future<ProfileStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final walksJoined = prefs.getInt(_keyWalksJoined) ?? 0;
    final eventsHosted = prefs.getInt(_keyEventsHosted) ?? 0;
    final totalKm = prefs.getDouble(_keyTotalKm) ?? 0.0;

    return ProfileStats(
      walksJoined: walksJoined,
      eventsHosted: eventsHosted,
      totalKm: totalKm,
    );
  }

  /// Save all three stats in one go.
  static Future<void> saveStats(ProfileStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWalksJoined, stats.walksJoined);
    await prefs.setInt(_keyEventsHosted, stats.eventsHosted);
    await prefs.setDouble(_keyTotalKm, stats.totalKm);
  }
}

/// Simple data holder for profile stats.
class ProfileStats {
  final int walksJoined;
  final int eventsHosted;
  final double totalKm;

  const ProfileStats({
    required this.walksJoined,
    required this.eventsHosted,
    required this.totalKm,
  });

  ProfileStats copyWith({
    int? walksJoined,
    int? eventsHosted,
    double? totalKm,
  }) {
    return ProfileStats(
      walksJoined: walksJoined ?? this.walksJoined,
      eventsHosted: eventsHosted ?? this.eventsHosted,
      totalKm: totalKm ?? this.totalKm,
    );
  }
}
