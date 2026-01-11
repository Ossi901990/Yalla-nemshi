import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_preferences.dart';

/// Provides user's saved city (async)
final userCityProvider = FutureProvider<String?>((ref) async {
  return AppPreferences.getUserCity();
});

/// Provides walk reminders enabled state
final walkRemindersEnabledProvider = FutureProvider<bool>((ref) async {
  return AppPreferences.getWalkRemindersEnabled();
});

/// Provides nearby alerts enabled state
final nearbyAlertsEnabledProvider = FutureProvider<bool>((ref) async {
  return AppPreferences.getNearbyAlertsEnabled();
});

/// Provides user's weekly goal (km)
final weeklyGoalProvider = FutureProvider<double>((ref) async {
  return AppPreferences.getWeeklyGoalKm();
});

/// Notifier to update user city and invalidate the cache
class UserCityNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return AppPreferences.getUserCity();
  }

  Future<void> setUserCity(String city) async {
    await AppPreferences.setUserCity(city);
    // Invalidate and rebuild
    ref.invalidateSelf();
  }
}

/// Mutable provider for user city
final userCityNotifierProvider =
    AsyncNotifierProvider<UserCityNotifier, String?>(
  UserCityNotifier.new,
);

/// Notifier to update walk reminders toggle
class WalkRemindersNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return AppPreferences.getWalkRemindersEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await AppPreferences.setWalkRemindersEnabled(enabled);
    ref.invalidateSelf();
  }
}

/// Mutable provider for walk reminders
final walkRemindersNotifierProvider =
    AsyncNotifierProvider<WalkRemindersNotifier, bool>(
  WalkRemindersNotifier.new,
);
