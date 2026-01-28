// lib/services/local_profile_prefs.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalProfilePrefs {
  static String _keyWalksJoined(String uid) => 'walksJoined_$uid';
  static String _keyEventsHosted(String uid) => 'eventsHosted_$uid';
  static String _keyTotalKm(String uid) => 'totalKm_$uid';

  /// Load saved stats. If nothing saved yet, returns zeros.
  static Future<ProfileStats> loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const ProfileStats(walksJoined: 0, eventsHosted: 0, totalKm: 0.0);
    
    final prefs = await SharedPreferences.getInstance();
    final walksJoined = prefs.getInt(_keyWalksJoined(uid)) ?? 0;
    final eventsHosted = prefs.getInt(_keyEventsHosted(uid)) ?? 0;
    final totalKm = prefs.getDouble(_keyTotalKm(uid)) ?? 0.0;

    return ProfileStats(
      walksJoined: walksJoined,
      eventsHosted: eventsHosted,
      totalKm: totalKm,
    );
  }

  /// Save all three stats in one go.
  static Future<void> saveStats(ProfileStats stats) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWalksJoined(uid), stats.walksJoined);
    await prefs.setInt(_keyEventsHosted(uid), stats.eventsHosted);
    await prefs.setDouble(_keyTotalKm(uid), stats.totalKm);
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
