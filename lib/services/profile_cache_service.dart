import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'crash_service.dart';

/// Caches user profile data locally for offline viewing.
class ProfileCacheService {
  ProfileCacheService._();

  static final ProfileCacheService instance = ProfileCacheService._();

  static const _profileCacheKey = 'cached_user_profile_v1';
  static const _staleSuffixMs = 3600000; // 1 hour in milliseconds

  /// Save profile to local cache with timestamp.
  Future<void> cacheProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        ...profile.toMap(),
        '_cached_at': DateTime.now().toIso8601String(),
      };
      final encoded = jsonEncode(data);
      await prefs.setString(_profileCacheKey, encoded);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ProfileCacheService.cacheProfile',
      );
    }
  }

  /// Load profile from cache. Returns null if not cached or expired.
  Future<UserProfile?> loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileCacheKey);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = decoded['_cached_at'] as String?;

      if (cachedAt != null) {
        final ts = DateTime.parse(cachedAt);
        final ageMs = DateTime.now().difference(ts).inMilliseconds;
        // Mark stale if older than 1 hour
        if (ageMs > _staleSuffixMs) {
          // Return as stale but don't delete—still useful offline
          decoded['_is_stale'] = true;
        }
      }

      return UserProfile.fromMap(decoded);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ProfileCacheService.loadCachedProfile',
      );
      return null;
    }
  }

  /// Clear cached profile.
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileCacheKey);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'ProfileCacheService.clearCache',
      );
    }
  }
}
