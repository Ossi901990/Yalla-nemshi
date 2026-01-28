import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class ProfileStorage {
  static String _keyForUser(String uid) => 'user_profile_$uid';

  // Save profile
  static Future<void> saveProfile(UserProfile profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(profile.toMap());
    await prefs.setString(_keyForUser(uid), jsonStr);
  }

  // Load profile
  static Future<UserProfile?> loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyForUser(uid));

    if (jsonStr == null) return null;

    final map = jsonDecode(jsonStr);
    return UserProfile.fromMap(map);
  }

  // Clear cached profile (e.g., after sign out)
  static Future<void> clearProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyForUser(uid));
  }
}
