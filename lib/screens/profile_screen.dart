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
          ? const Color(0xFF0B1A13)
          : const Color(0xFF4F925C),
      body: Column(
        children: [
          // ===== HEADER =====
          Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF020908), Color(0xFF0B1A13)]
                    : const [Color(0xFF294630), Color(0xFF4F925C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        _HeaderLogo(),
                        SizedBox(width: 8),
                        Text(
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
                        _HeaderNotifications(onTap: _showNotificationsSheet),
                        const SizedBox(width: 12),
                        _HeaderSettings(
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
              decoration: BoxDecoration(
                color: isDark
                    ? const Color.fromARGB(255, 9, 2, 7)
                    : const Color(0xFFF7F9F2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                image: DecorationImage(
                  image: AssetImage(
                    isDark
                        ? 'assets/images/bg_minimal_dark.png'
                        : 'assets/images/bg_minimal_light.png',
                  ),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.35)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                        child: GestureDetector(
                          onTap: _onAvatarTap,
                          child: Column(
                            children: [
                              _buildAvatar(profile),
                              const SizedBox(height: 8),
                              Text(
                                profile?.name.isNotEmpty == true
                                    ? profile!.name
                                    : 'Your name',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
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
                      ),
                      const SizedBox(height: 16),

                      if (profile != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Chip(label: Text('Age: ${profile.age}')),
                            const SizedBox(width: 8),
                            Chip(label: Text('Gender: ${profile.gender}')),
                          ],
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
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.weeklyWalks} walk${widget.weeklyWalks == 1 ? '' : 's'} • '
                                '${widget.weeklyKm.toStringAsFixed(1)} / ${_weeklyGoalKmLocal.toStringAsFixed(1)} km',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: weeklyProgress,
                                  minHeight: 6,
                                  backgroundColor: Colors.green.shade50,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.streakDays > 0
                                    ? 'Streak: ${widget.streakDays} day${widget.streakDays == 1 ? '' : 's'} in a row'
                                    : 'No streak yet. Join a walk today!',
                                style: theme.textTheme.bodySmall,
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
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (achievedBadges.isEmpty)
                                Text(
                                  'Badges will appear here as you walk more.',
                                  style: theme.textTheme.bodySmall,
                                )
                              else
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: achievedBadges.take(6).map((b) {
                                    return GestureDetector(
                                      onTap: () => _showBadgeDetails(b),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            child: Icon(
                                              b.icon,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _openBadgesPage(allBadges),
                                  child: const Text('View all'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Actions
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openEditProfile,
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit profile info'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openSafetyTips,
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Walking safety & community tips'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
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
    return Expanded(
      child: Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodySmall),
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
