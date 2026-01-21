// lib/screens/settings_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/firestore_user.dart';
import '../services/app_preferences.dart';
import '../services/firestore_user_service.dart';
import '../widgets/redeem_invite_sheet.dart';
import 'safety_tips_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loading = true;

  bool _walkReminders = AppPreferences.walkRemindersFallback;
  bool _nearbyAlerts = AppPreferences.nearbyAlertsFallback;
  bool _pushWalks = AppPreferences.pushWalksFallback;
  bool _pushChat = AppPreferences.pushChatFallback;
  bool _pushUpdates = AppPreferences.pushUpdatesFallback;

  double _defaultDistanceKm = AppPreferences.defaultDistanceKmFallback;
  String _defaultGender = AppPreferences.defaultGenderFallback;

  double _weeklyGoalKmLocal = AppPreferences.weeklyGoalKmFallback;
  bool _monthlyDigestEnabled = false;
  bool _monthlyDigestSaving = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
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

    try {
      _pushWalks = await AppPreferences.getPushWalksEnabled();
    } catch (_) {}

    try {
      _pushChat = await AppPreferences.getPushChatEnabled();
    } catch (_) {}

    try {
      _pushUpdates = await AppPreferences.getPushUpdatesEnabled();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _onMonthlyDigestToggle(
    String uid,
    bool nextValue,
    bool fallback,
  ) async {
    setState(() {
      _monthlyDigestSaving = true;
      _monthlyDigestEnabled = nextValue;
    });

    try {
      await FirestoreUserService.setMonthlyDigestEnabled(
        uid: uid,
        enabled: nextValue,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _monthlyDigestEnabled = fallback;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update email digest: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _monthlyDigestSaving = false;
      });
    }
  }

  Widget _buildMonthlyDigestTile(bool isDark) {
    final uid = _currentUserId;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<FirestoreUser?>(
      stream: FirestoreUserService.watchUser(uid),
      builder: (context, snapshot) {
        final serverValue = snapshot.data?.monthlyDigestEnabled ?? false;
        final effectiveValue =
            _monthlyDigestSaving ? _monthlyDigestEnabled : serverValue;

        final waitingForData =
          snapshot.connectionState == ConnectionState.waiting &&
            !_monthlyDigestSaving &&
            !snapshot.hasData;
        final disableToggle = waitingForData || _monthlyDigestSaving;

        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Monthly email digest'),
          subtitle: const Text(
            'Receive a monthly summary of your walks by email',
          ),
          value: effectiveValue,
          onChanged: disableToggle
              ? null
              : (value) => _onMonthlyDigestToggle(uid, value, serverValue),
        );
      },
    );
  }

  Future<void> _openRedeemInviteSheet() async {
    final redeemed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const RedeemInviteSheet(),
    );

    if (redeemed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite redeemed! Check your walks list.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Shared slider styling (NO dots + framed container like dark mode)
    SliderThemeData sliderTheme() {
      return theme.sliderTheme.copyWith(
        trackHeight: 4,
        inactiveTrackColor: (isDark ? Colors.white : Colors.black).withAlpha(
          (0.14 * 255).round(),
        ),
        activeTrackColor: const Color(0xFF1ABFC4),
        thumbColor: const Color(0xFF1ABFC4),
        overlayColor: Colors.transparent,

        // ✅ remove dots/tick marks even with divisions
        tickMarkShape: SliderTickMarkShape.noTickMark,
        inactiveTickMarkColor: Colors.transparent,
        activeTickMarkColor: Colors.transparent,
      );
    }

    BoxDecoration framedSliderBox() {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withAlpha(
            (0.10 * 255).round(),
          ),
          width: 1,
        ),
        color: isDark
            ? Colors.white.withAlpha((0.03 * 255).round())
            : Colors.black.withAlpha((0.03 * 255).round()),
      );
    }

    return Scaffold(
      // ✅ fixes the green-corner “bleed” in light mode
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF1ABFC4),
      body: Column(
        children: [
          // ===== HEADER (match Home/Nearby) =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Go back',
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Settings',
                          style:
                              Theme.of(
                                context,
                              ).textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 24,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 64,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1ABFC4), Color(0xFF1DB8C0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Settings',
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ===== MAIN AREA (Home-style background + card) =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF071B26), // top (dark blue)
                            Color(0xFF041016), // bottom (almost black)
                          ],
                        )
                      : null,
                  color: isDark ? null : const Color(0xFFF7F9F2),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),

                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Card(
                          color: isDark
                              ? const Color(0xFF0C2430)
                              : const Color(0xFFFBFEF8),
                          elevation: isDark ? 0.0 : 0.6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withAlpha((0.06 * 255).round()),
                            ),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
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
                                subtitle: const Text(
                                  'Notify me before walks I join',
                                ),
                                value: _walkReminders,
                                onChanged: (val) async {
                                  setState(() => _walkReminders = val);
                                  await AppPreferences.setWalkRemindersEnabled(
                                    val,
                                  );
                                  await _bootstrap();
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
                                  await AppPreferences.setNearbyAlertsEnabled(
                                    val,
                                  );
                                  await _bootstrap();
                                },
                              ),
                              const Divider(height: 24),

                              // ===== Push Notifications =====
                              Text(
                                'Push Notifications',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Walk activity'),
                                subtitle: const Text(
                                  'Get notified when someone joins your walks',
                                ),
                                value: _pushWalks,
                                onChanged: (val) async {
                                  setState(() => _pushWalks = val);
                                  await AppPreferences.setPushWalksEnabled(val);
                                  await _bootstrap();
                                },
                              ),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Chat messages'),
                                subtitle: const Text(
                                  'Notify me of new messages in walks I joined',
                                ),
                                value: _pushChat,
                                onChanged: (val) async {
                                  setState(() => _pushChat = val);
                                  await AppPreferences.setPushChatEnabled(val);
                                  await _bootstrap();
                                },
                              ),

                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Walk updates'),
                                subtitle: const Text(
                                  'Notify me when walk details change or are cancelled',
                                ),
                                value: _pushUpdates,
                                onChanged: (val) async {
                                  setState(() => _pushUpdates = val);
                                  await AppPreferences.setPushUpdatesEnabled(
                                    val,
                                  );
                                  await _bootstrap();
                                },
                              ),
                              _buildMonthlyDigestTile(isDark),
                              const SizedBox(height: 16),

                              // ===== Preferences =====
                              Text(
                                'Preferences',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Default walk distance
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Default walk distance',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_defaultDistanceKm.toStringAsFixed(1)} km',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              Container(
                                decoration: framedSliderBox(),
                                child: SliderTheme(
                                  data: sliderTheme(),
                                  child: Slider(
                                    min: 1.0,
                                    max: 10.0,
                                    divisions: 18, // snap 0.5
                                    value: _defaultDistanceKm,
                                    label:
                                        '${_defaultDistanceKm.toStringAsFixed(1)} km',
                                    onChanged: (value) async {
                                      setState(
                                        () => _defaultDistanceKm = value,
                                      );
                                      await AppPreferences.setDefaultDistanceKm(
                                        value,
                                      );
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Weekly distance goal
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Weekly distance goal',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_weeklyGoalKmLocal.toStringAsFixed(1)} km',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              Container(
                                decoration: framedSliderBox(),
                                child: SliderTheme(
                                  data: sliderTheme(),
                                  child: Slider(
                                    min: 5.0,
                                    max: 60.0,
                                    divisions: 55, // snap 1km
                                    value: _weeklyGoalKmLocal.clamp(5.0, 60.0),
                                    label:
                                        '${_weeklyGoalKmLocal.toStringAsFixed(0)} km',
                                    onChanged: (value) async {
                                      setState(
                                        () => _weeklyGoalKmLocal = value,
                                      );
                                      await AppPreferences.setWeeklyGoalKm(
                                        value,
                                      );
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Default gender preference (no grey fill layer)
                              Text(
                                'Default gender preference',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withAlpha((0.28 * 255).round()),
                                    width: 1,
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _defaultGender,
                                    isExpanded: true,
                                    focusColor: Colors.transparent,
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    dropdownColor: isDark
                                        ? const Color(0xFF0C2430)
                                        : Colors.white,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Mixed',
                                        child: Text(
                                          'Mixed',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Women only',
                                        child: Text(
                                          'Women only',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Men only',
                                        child: Text(
                                          'Men only',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],

                                    onChanged: (val) async {
                                      if (val == null) return;
                                      setState(() => _defaultGender = val);
                                      await AppPreferences.setDefaultGender(
                                        val,
                                      );
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
                                leading: const Icon(Icons.vpn_key_outlined),
                                title: const Text('Redeem private invite'),
                                subtitle: const Text(
                                  'Enter a walk ID and invite code from a host',
                                ),
                                onTap: _openRedeemInviteSheet,
                              ),

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
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (_) => _TermsPrivacyDialog(),
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for choosing between Terms and Privacy Policy
class _TermsPrivacyDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Legal',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1ABFC4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1ABFC4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  );
                },
                child: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
