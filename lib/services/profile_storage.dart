import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'dart:convert';

class ProfileStorage {
  static const _legacyKey = 'user_profile';
  static const _keyPrefix = 'user_profile_v2_';

  // Save profile
  static Future<void> saveProfile(UserProfile profile, {String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(profile.toMap());
    await prefs.setString(_keyFor(uid), jsonStr);
  }

  // Load profile
  static Future<UserProfile?> loadProfile({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString(_keyFor(uid));
    jsonStr ??= prefs.getString(_legacyKey);

    if (jsonStr == null) return null;

    final map = jsonDecode(jsonStr);
    return UserProfile.fromMap(map);
  }

  // Clear cached profile (e.g., after sign out)
  static Future<void> clearProfile({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(uid));
  }

  static String _keyFor(String? uid) {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null || resolvedUid.isEmpty) {
      return _legacyKey;
    }
    return '$_keyPrefix$resolvedUid';
  }
}
