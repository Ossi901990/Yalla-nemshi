import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class ProfileStorage {
  static const _key = 'user_profile';

  // Save profile
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(profile.toMap());
    await prefs.setString(_key, jsonStr);
  }

  // Load profile
  static Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);

    if (jsonStr == null) return null;

    final map = jsonDecode(jsonStr);
    return UserProfile.fromMap(map);
  }

  // Clear cached profile (e.g., after sign out)
  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
