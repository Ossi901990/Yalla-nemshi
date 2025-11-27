// lib/screens/profile_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../models/profile_badge.dart';
import 'badges_info_screen.dart';
import 'edit_profile_screen.dart';
import 'safety_tips_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int walksJoined;
  final int eventsHosted;
  final double totalKm;
  final int interestedCount;

  final double weeklyKm;
  final int weeklyWalks;
  final int streakDays;
  final double weeklyGoalKm;

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
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    setState(() {
      _profile = updated;
    });
  }

  void _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile),
      ),
    );
    await _loadProfile();
  }

  void _openBadgesPage(List<ProfileBadge> allBadges) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BadgesInfoScreen(badges: allBadges),
      ),
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
            )
          ],
        );
      },
    );
  }

  void _openSafetyTips() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SafetyTipsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile;

    final allBadges = computeBadges(
      walksJoined: widget.walksJoined,
      eventsHosted: widget.eventsHosted,
      totalKm: widget.totalKm,
    );
    final achievedBadges =
        allBadges.where((b) => b.achieved).toList(growable: false);

    final double weeklyProgress = widget.weeklyGoalKm <= 0
        ? 0
        : (widget.weeklyKm / widget.weeklyGoalKm).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _openEditProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + name + bio
            GestureDetector(
              onTap: _pickAndSaveImage,
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

            // Basic info row (age, gender)
            if (profile != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text('Age: ${profile.age}'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('Gender: ${profile.gender}'),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Weekly stats
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'This week',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.weeklyWalks} walk${widget.weeklyWalks == 1 ? '' : 's'} • '
                      '${widget.weeklyKm.toStringAsFixed(1)} / ${widget.weeklyGoalKm.toStringAsFixed(1)} km',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: weeklyProgress),
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
            const SizedBox(height: 16),

            // Stats cards
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: Text(
                'Marked as interested: ${widget.interestedCount}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),

            // Compact badges row
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Badges',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx) {
                      const double badgeSize = 28;

                      if (allBadges.isEmpty) {
                        return Text(
                          'Badges will appear here as you walk more.',
                          style: theme.textTheme.bodySmall,
                        );
                      }

                      return Row(
                        children: [
                          ...achievedBadges.take(5).map((b) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 6.0),
                              child: GestureDetector(
                                onTap: () => _showBadgeDetails(b),
                                child: CircleAvatar(
                                  radius: badgeSize / 2,
                                  backgroundColor: b.achieved
                                      ? theme.colorScheme.primary
                                      : Colors.grey.shade300,
                                  child: Icon(
                                    b.icon,
                                    size: 16,
                                    color: b.achieved
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (achievedBadges.length > 5)
                            GestureDetector(
                              onTap: () => _openBadgesPage(allBadges),
                              child: CircleAvatar(
                                radius: badgeSize / 2,
                                backgroundColor: Colors.grey.shade200,
                                child: Text(
                                  '+${achievedBadges.length - 5}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _openBadgesPage(allBadges),
                            child: const Text('View all'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
            const SizedBox(height: 12),
            Text(
              'Tip: Tap on your photo to change it.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(UserProfile? profile) {
    final imgPath = profile?.profileImagePath;

    if (imgPath != null &&
        imgPath.isNotEmpty &&
        File(imgPath).existsSync()) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(File(imgPath)),
      );
    }

    return const CircleAvatar(
      radius: 48,
      child: Icon(Icons.person, size: 48),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
