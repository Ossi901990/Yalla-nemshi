import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_nemshi/services/app_preferences.dart';

void main() {
  group('AppPreferences', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns fallback values when nothing set', () async {
      expect(await AppPreferences.getDefaultDistanceKm(), AppPreferences.defaultDistanceKmFallback);
      expect(await AppPreferences.getDefaultGender(), AppPreferences.defaultGenderFallback);
      expect(await AppPreferences.getWalkRemindersEnabled(), AppPreferences.walkRemindersFallback);
      expect(await AppPreferences.getNearbyAlertsEnabled(), AppPreferences.nearbyAlertsFallback);
      expect(await AppPreferences.getWeeklyGoalKm(), AppPreferences.weeklyGoalKmFallback);
    });

    test('persists and retrieves distance', () async {
      await AppPreferences.setDefaultDistanceKm(5.5);
      expect(await AppPreferences.getDefaultDistanceKm(), 5.5);
    });

    test('persists and retrieves gender', () async {
      await AppPreferences.setDefaultGender('Women only');
      expect(await AppPreferences.getDefaultGender(), 'Women only');
    });

    test('persists and retrieves reminders toggle', () async {
      await AppPreferences.setWalkRemindersEnabled(false);
      expect(await AppPreferences.getWalkRemindersEnabled(), false);
    });

    test('persists and retrieves nearby alerts toggle', () async {
      await AppPreferences.setNearbyAlertsEnabled(false);
      expect(await AppPreferences.getNearbyAlertsEnabled(), false);
    });

    test('persists and retrieves weekly goal', () async {
      await AppPreferences.setWeeklyGoalKm(20.0);
      expect(await AppPreferences.getWeeklyGoalKm(), 20.0);
    });
  });
}
