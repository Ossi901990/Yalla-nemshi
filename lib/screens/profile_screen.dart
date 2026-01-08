// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../models/profile_badge.dart';

import 'badges_info_screen.dart';
import 'edit_profile_screen.dart';
import 'safety_tips_screen.dart';
import 'login_screen.dart'; // for routeName
import 'settings_screen.dart';
import '../services/app_preferences.dart';

// ===== Design tokens (match HomeScreen) =====
const double kRadiusCard = 24;
const double kRadiusControl = 16;
const double kRadiusPill = 999;

const double kSpace1 = 8;
const double kSpace2 = 16;
const double kSpace3 = 24;
const double kSpace4 = 32;

const kLightSurface = Color(0xFFFBFEF8);
const double kCardElevationLight = 0.6;
const double kCardElevationDark = 0.0;
const double kCardBorderAlpha = 0.06;

class ProfileScreen extends StatefulWidget {
  final int walksJoined;
  final int eventsHosted;
  final double totalKm;
  final int interestedCount;

  final double weeklyKm;
  final int weeklyWalks;
  final int streakDays;
  final double weeklyGoalKm;

  final ValueChanged<double>? onWeeklyGoalChanged;

  const ProfileScreen({
    super.key,
    required this.walksJoined,
    required this.eventsHosted,
    required this.totalKm,
    required this.interestedCount,
    required this.weeklyKm,
    required this.weeklyWalks,
    required this.streakDays,
    required this.weeklyGoalKm,
    this.onWeeklyGoalChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  static const Color _deepGreen = Color(0xFF294630);

  late double _weeklyGoalKmLocal;

  @override
  void initState() {
    super.initState();
    _weeklyGoalKmLocal = widget.weeklyGoalKm;
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _weeklyGoalKmLocal = widget.weeklyGoalKm;
  }

  Future<void> _loadProfile() async {
    final p = await ProfileStorage.loadProfile();
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _pickAndSaveImage() async {
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill your profile info first.')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final updated = _profile!.copyWith(profileImagePath: picked.path);
    await ProfileStorage.saveProfile(updated);
    setState(() => _profile = updated);
  }

  Future<void> _removeProfileImage() async {
    if (_profile == null) return;

    final cleared = _profile!.copyWith(profileImagePath: null);
    await ProfileStorage.saveProfile(cleared);

    if (!mounted) return;
    setState(() => _profile = cleared);
  }

  void _onAvatarTap() {
    final hasPhoto =
        _profile?.profileImagePath != null &&
        _profile!.profileImagePath!.isNotEmpty;

    if (!hasPhoto) {
      _pickAndSaveImage();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Change photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndSaveImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _removeProfileImage();
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  String _weeklyMotivationText({
    required double progress,
    required double weeklyKm,
    required double weeklyGoalKm,
    required int streakDays,
  }) {
    if (weeklyKm <= 0.0) return 'Let’s start small—join a short walk today.';
    if (progress >= 1.0) return 'Goal achieved! Bonus walk? 💪';
    if (progress >= 0.75) return 'Great pace—almost there!';
    if (progress >= 0.50) return 'You’re building momentum—keep going!';
    if (progress >= 0.25) return 'Nice start—stay consistent!';
    return 'Good start—one more walk will help a lot.';
  }

  String get _walkerLevel {
    final km = widget.totalKm;
    if (km < 5) return 'New walker';
    if (km < 25) return 'Getting active';
    if (km < 100) return 'Regular walker';
    if (km < 250) return 'Committed walker';
    return 'Trail pro';
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _profile)),
    );
    await _loadProfile();
  }

  void _openBadgesPage(List<ProfileBadge> allBadges) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BadgesInfoScreen(badges: allBadges)),
    );
  }

  void _showBadgeDetails(ProfileBadge badge) {
    showDialog(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: badge.achieved
                    ? theme.colorScheme.primary
                    : Colors.grey.shade300,
                child: Icon(
                  badge.icon,
                  color: badge.achieved ? Colors.white : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(badge.title)),
            ],
          ),
          content: Text(badge.description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openSafetyTips() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SafetyTipsScreen()));
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBFEF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 40,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You’ll see reminders and new nearby walks here.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = _profile;

    final allBadges = computeBadges(
      walksJoined: widget.walksJoined,
      eventsHosted: widget.eventsHosted,
      totalKm: widget.totalKm,
    );

    final achievedBadges = allBadges
        .where((b) => b.achieved)
        .toList(growable: false);

    final double weeklyProgress = _weeklyGoalKmLocal <= 0
        ? 0
        : (widget.weeklyKm / _weeklyGoalKmLocal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF4F925C),

      body: Column(
        children: [
          // ===== HEADER (match Home/Nearby) =====
          if (isDark)
            // ✅ Dark: NO BAR, floating header (same as Nearby/Home)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: logo + title
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                          ),
                          child: const Icon(
                            Icons.directions_walk,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Yalla Nemshi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    // Right: notif + settings (NO profile icon)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _showNotificationsSheet,
                          child: Container(
                            width: 32,
                            height: 32,
                              decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                            child: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ✅ Keep SAME settings functionality from Profile
                        GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );

                            final wg = await AppPreferences.getWeeklyGoalKm();
                            if (!mounted) return;

                            setState(() => _weeklyGoalKmLocal = wg);
                            widget.onWeeklyGoalChanged?.call(wg);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                            child: const Icon(
                              Icons.settings,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            // ✅ Light: gradient bar (same as Nearby style)
            Container(
              height: 64,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF294630), Color(0xFF4F925C)],
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: const Icon(
                              Icons.directions_walk,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Yalla Nemshi',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showNotificationsSheet,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                              ),
                              child: const Icon(
                                Icons.notifications_none,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );

                              final wg = await AppPreferences.getWeeklyGoalKm();
                              if (!mounted) return;

                              setState(() => _weeklyGoalKmLocal = wg);
                              widget.onWeeklyGoalChanged?.call(wg);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                              ),
                              child: const Icon(
                                Icons.settings,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

// ===== MAIN AREA =====
Expanded(
  child: Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          kSpace2,
          kSpace2,
          kSpace2,
          kSpace3 + MediaQuery.of(context).padding.bottom,
        ),
        child: Card(

                  color: isDark ? const Color(0xFF0C2430) : kLightSurface,
                  elevation: isDark ? kCardElevationDark : kCardElevationLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusCard),
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        kCardBorderAlpha,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      kSpace2,
                      kSpace3,
                      kSpace2,
                      kSpace3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My profile',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : _deepGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track your progress and edit your walking details.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Avatar, name, level, bio
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  GestureDetector(
                                    onTap: _onAvatarTap,
                                    child: _buildAvatar(profile),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // ✅ Name stays perfectly centered
                                    Center(
                                      child: Text(
                                        profile?.name.isNotEmpty == true
                                            ? profile!.name
                                            : 'Your name',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),

                                    // ✅ Pen icon on the right, does NOT shift the text
                                    Positioned(
                                      right: 0,
                                      child: IconButton(
                                        onPressed: _openEditProfile,
                                        icon: const Icon(Icons.edit, size: 18),
                                        tooltip: 'Edit profile',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 4),
                              Text(
                                _walkerLevel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF4F925C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile?.bio.isNotEmpty == true
                                    ? profile!.bio
                                    : 'Add a short bio about you',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (profile != null)
                          ChipTheme(
                            data: theme.chipTheme.copyWith(
                              backgroundColor: isDark
                                  ? const Color(
                                      0xFF123647,
                                    ) // 👈 bluish chip surface
                                  : theme.colorScheme.surface,
                              side: BorderSide(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.12),
                              ),
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(label: Text('Age: ${profile.age}')),
                                      Chip(
                                        label: Text(
                                          'Gender: ${profile.gender}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        // This week
                        Text(
                          'This week',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: isDark
                              ? const Color(0xFF0C2430)
                              : theme.cardColor,
                          elevation: isDark ? 0.0 : 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.08),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${widget.weeklyWalks} walk${widget.weeklyWalks == 1 ? '' : 's'} • '
                                        '${widget.weeklyKm.toStringAsFixed(1)} / ${_weeklyGoalKmLocal.toStringAsFixed(1)} km',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : null,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : const Color(0xFFE5F3D9),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '${(weeklyProgress * 100).round()}%',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.white
                                                  : null,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                LayoutBuilder(
                                  builder: (context, c) {
                                    final trackH = 10.0;
                                    final fillW = (c.maxWidth * weeklyProgress)
                                        .clamp(0.0, c.maxWidth);

                                    return Stack(
                                      children: [
                                        Container(
                                          height: trackH,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.10)
                                                : Colors.black.withOpacity(
                                                    0.06,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: trackH,
                                          width: fillW,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF9BD77A)
                                                : const Color(0xFF4F925C),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _weeklyMotivationText(
                                    progress: weeklyProgress,
                                    weeklyKm: widget.weeklyKm,
                                    weeklyGoalKm: _weeklyGoalKmLocal,
                                    streakDays: widget.streakDays,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Stats
                        Text(
                          'Your stats',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statCard(
                              label: 'Walks joined',
                              value: widget.walksJoined.toString(),
                              icon: Icons.directions_walk,
                            ),
                            _statCard(
                              label: 'Hosted',
                              value: widget.eventsHosted.toString(),
                              icon: Icons.flag,
                            ),
                            _statCard(
                              label: 'Total km',
                              value: widget.totalKm.toStringAsFixed(1),
                              icon: Icons.map,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Marked as interested: ${widget.interestedCount}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Badges
                        Text(
                          'Badges',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: isDark
                              ? const Color(0xFF0C2430)
                              : theme.cardColor,
                          elevation: isDark ? 0.0 : 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.08),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (achievedBadges.isEmpty)
                                  Text(
                                    'Badges will appear here as you walk more.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white70 : null,
                                    ),
                                  )
                                else ...[
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: achievedBadges.take(6).map((b) {
                                      return GestureDetector(
                                        onTap: () => _showBadgeDetails(b),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          child: Icon(
                                            b.icon,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),

                                  // ✅ Compact "View all" (doesn't inflate card height)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          _openBadgesPage(allBadges),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('View all'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Actions
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openSafetyTips,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.18),
                              ),
                              foregroundColor: isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text(
                              'Walking safety & community tips',
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _signOut,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: Colors.red.withOpacity(0.5),
                              ),
                              foregroundColor: Colors.red,
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign out'),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Tip: Tap on your photo to change it.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildAvatar(UserProfile? profile) {
    final imgPath = profile?.profileImagePath;

    if (imgPath != null && imgPath.isNotEmpty && File(imgPath).existsSync()) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(File(imgPath)),
      );
    }

    return const CircleAvatar(
      radius: 48,
      backgroundColor: Color(0xFFB7E76A),
      child: Icon(Icons.person, size: 48, color: Color(0xFF166534)),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Card(
        color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
        elevation: isDark ? 0.0 : 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: isDark ? Colors.white : null),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white70 : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small reusable header pieces
class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white24,
      ),
      child: const Icon(Icons.directions_walk, size: 18, color: Colors.white),
    );
  }
}

class _HeaderNotifications extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderNotifications({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 18,
              color: Colors.white,
            ),
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Text(
                '3',
                style: TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSettings extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderSettings({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white24,
        ),
        child: const Icon(Icons.settings, size: 18, color: Colors.white),
      ),
    );
  }
}
