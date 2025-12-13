import 'package:flutter/material.dart';

import '../services/app_preferences.dart';
import '../theme_controller.dart';
import 'safety_tips_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;

  bool _useSystemTheme = false; // coming soon (kept for UI)
  bool _walkReminders = AppPreferences.walkRemindersFallback;
  bool _nearbyAlerts = AppPreferences.nearbyAlertsFallback;

  double _defaultDistanceKm = AppPreferences.defaultDistanceKmFallback;
  String _defaultGender = AppPreferences.defaultGenderFallback;

  double _weeklyGoalKmLocal = AppPreferences.weeklyGoalKmFallback;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Load each setting safely so one failure doesn't reset everything
    try {
      _defaultDistanceKm = await AppPreferences.getDefaultDistanceKm();
    } catch (_) {}

    try {
      _defaultGender = await AppPreferences.getDefaultGender();
    } catch (_) {}

    try {
      _walkReminders = await AppPreferences.getWalkRemindersEnabled();
    } catch (_) {}

    try {
      _nearbyAlerts = await AppPreferences.getNearbyAlertsEnabled();
    } catch (_) {}

    try {
      _weeklyGoalKmLocal = await AppPreferences.getWeeklyGoalKm();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _showWeeklyGoalPicker() async {
    double tempValue = _weeklyGoalKmLocal.clamp(1.0, 50.0);

    final result = await showModalBottomSheet<double>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly distance goal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('${tempValue.toStringAsFixed(1)} km per week'),
                  const SizedBox(height: 16),
                  Slider(
                    min: 2,
                    max: 30,
                    divisions: 28,
                    value: tempValue,
                    label: '${tempValue.toStringAsFixed(1)} km',
                    onChanged: (v) => setModalState(() => tempValue = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(tempValue),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      await AppPreferences.setWeeklyGoalKm(result);
      if (!mounted) return;
      setState(() => _weeklyGoalKmLocal = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ===== Appearance =====
                Text(
                  'Appearance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                    ),
                    title: const Text('Dark mode'),
                    subtitle: Text(
                      isDark ? 'Using dark theme' : 'Using light theme',
                    ),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (value) async {
                        _useSystemTheme = false;
                        ThemeController.instance.setDarkMode(value);
                        await Future.delayed(const Duration(milliseconds: 50));
                        if (!mounted) return;
                        setState(() {}); // rebuild so isDark updates
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_iphone_outlined),
                  title: const Text('Use system theme'),
                  subtitle: const Text('Coming soon – follow device setting'),
                  trailing: Switch(value: _useSystemTheme, onChanged: null),
                ),

                const SizedBox(height: 16),

                // ===== Notifications =====
                Text(
                  'Notifications',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Walk reminders'),
                  subtitle: const Text('Notify me before walks I join'),
                  value: _walkReminders,
                  onChanged: (val) async {
                    setState(() => _walkReminders = val);
                    await AppPreferences.setWalkRemindersEnabled(val);
                    await _bootstrap(); // re-sync from prefs
                  },
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nearby walks alerts'),
                  subtitle: const Text(
                    'Alert me when a new walk is created nearby',
                  ),
                  value: _nearbyAlerts,
                  onChanged: (val) async {
                    setState(() => _nearbyAlerts = val);
                    await AppPreferences.setNearbyAlertsEnabled(val);
                    await _bootstrap(); // re-sync from prefs
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Weekly distance goal'),
                  subtitle: Text(
                    '${_weeklyGoalKmLocal.toStringAsFixed(1)} km per week',
                  ),
                  onTap: _showWeeklyGoalPicker,
                ),

                const SizedBox(height: 16),

                // ===== Preferences =====
                Text(
                  'Preferences',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Default walk distance'),
                            Text('${_defaultDistanceKm.toStringAsFixed(1)} km'),
                          ],
                        ),
                        Slider(
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          value: _defaultDistanceKm,
                          label: '${_defaultDistanceKm.toStringAsFixed(1)} km',
                          onChanged: (value) async {
                            setState(() => _defaultDistanceKm = value);
                            await AppPreferences.setDefaultDistanceKm(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Default gender preference',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _defaultGender,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Mixed', child: Text('Mixed')),
                        DropdownMenuItem(
                          value: 'Women only',
                          child: Text('Women only'),
                        ),
                        DropdownMenuItem(
                          value: 'Men only',
                          child: Text('Men only'),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;
                        setState(() => _defaultGender = val);
                        await AppPreferences.setDefaultGender(val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ===== More =====
                Text(
                  'More',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Walking safety & tips'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SafetyTipsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About Yalla Nemshi'),
                  subtitle: const Text('Version 1.0.0'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Yalla Nemshi',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Terms & privacy policy'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Terms & privacy policy'),
                        content: const Text(
                          'This is a placeholder.\n\n'
                          'Later you can link to a web page or detailed in-app text '
                          'with your real terms and privacy policy.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
