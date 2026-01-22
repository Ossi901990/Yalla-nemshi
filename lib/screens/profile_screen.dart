// lib/screens/profile_screen.dart
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../services/firestore_user_service.dart';
import '../services/host_rating_service.dart';
import '../services/user_stats_service.dart';
import '../services/walk_history_service.dart';
import '../services/walk_export_service.dart';
import '../models/profile_badge.dart';
import '../models/badge.dart';
import '../widgets/app_bottom_nav_bar.dart';

import 'badges_info_screen.dart';
import 'edit_profile_screen.dart';
import 'safety_tips_screen.dart';
import 'login_screen.dart'; // for routeName
import 'settings_screen.dart';
import 'home_screen.dart';
import 'badge_leaderboard_screen.dart';
import '../services/app_preferences.dart';
import '../services/profile_cache_service.dart';
import '../services/offline_service.dart';

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

class _BadgeView {
  final String id;
  final String title;
  final String description;
  final double progress;
  final double target;
  final bool achieved;
  final IconData icon;
  final DateTime? earnedAt;

  const _BadgeView({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.achieved,
    required this.icon,
    this.earnedAt,
  });
}
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
  final int _currentTab = 3; // Profile tab is index 3

  static const Color _deepGreen = Color(0xFF1ABFC4);

  late double _weeklyGoalKmLocal;
  bool _isOffline = false;
  bool _isProfileStale = false;

  late final VoidCallback _offlineListener;

  @override
  void initState() {
    super.initState();
    _weeklyGoalKmLocal = widget.weeklyGoalKm;

    _offlineListener = () {
      if (!mounted) return;
      setState(() {
        _isOffline = OfflineService.instance.isOffline.value;
      });
    };
    OfflineService.instance.isOffline.addListener(_offlineListener);
    _isOffline = OfflineService.instance.isOffline.value;

    _loadProfile();
  }

  @override
  void dispose() {
    OfflineService.instance.isOffline.removeListener(_offlineListener);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _weeklyGoalKmLocal = widget.weeklyGoalKm;
  }

  Widget? _buildStaleDataBanner() {
    if (!_isOffline || !_isProfileStale) return null;
    return Container(
      width: double.infinity,
      color: Colors.orange.shade600,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.info, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing cached profile. Some info may be outdated.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProfile() async {
    UserProfile? p = await ProfileStorage.loadProfile();

    // Fallback to cached profile if offline or on load error
    if (p == null && _isOffline) {
      p = await ProfileCacheService.instance.loadCachedProfile();
      if (p != null && p.toMap().containsKey('_is_stale')) {
        _isProfileStale = true;
      }
    }

    setState(() {
      _profile = p;
      _loading = false;
    });

    // Cache profile for later offline use
    if (p != null) {
      await ProfileCacheService.instance.cacheProfile(p);
    }
  }

  Future<void> _pickAndSaveImage() async {
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill your profile info first.')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    String? imagePath;
    if (kIsWeb) {
      // On web, we can't use file paths, so we store a placeholder or handle differently
      // For now, we'll use the name as a reference (you may want to upload to storage)
      imagePath = 'web_${picked.name}';
    } else {
      imagePath = picked.path;
    }

    final updated = _profile!.copyWith(profileImagePath: imagePath);
    await ProfileStorage.saveProfile(updated);
    setState(() => _profile = updated);
  }


  Future<void> _removeProfileImage() async {
    if (_profile == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    // Delete from Firebase Storage if user is logged in
    if (uid != null) {
      try {
        await FirestoreUserService.deleteProfilePhoto(uid);
      } catch (e) {
        // Continue even if Firebase delete fails
        debugPrint('Warning: Could not delete photo from Firebase: $e');
      }
    }

    final cleared = _profile!.copyWith(
      profileImagePath: null,
      profileImageBase64: null,
    );
    await ProfileStorage.saveProfile(cleared);

    if (!mounted) return;
    setState(() => _profile = cleared);
  }


  void _onAvatarTap() {
    final hasPhoto = (_profile?.profileImageBase64 != null &&
            _profile!.profileImageBase64!.isNotEmpty) ||
        (_profile?.profileImagePath != null &&
            _profile!.profileImagePath!.isNotEmpty);


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
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.red,
                  ),
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

  /// Build host rating widget
  Widget _buildHostRatingCard(BuildContext context, String userId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: HostRatingService.instance.getHostRating(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
            elevation: isDark ? 0.0 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color:
                    (isDark ? Colors.white : Colors.black)
                        .withAlpha((0.08 * 255).round()),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final ratingData = snapshot.data!;
        final rating = ratingData['rating'] as double? ?? 5.0;
        final reviewCount = ratingData['reviewCount'] as int? ?? 0;
        final tier = HostRatingService.getRatingTier(rating);

        // Only show if user has hosted at least one walk
        if (widget.eventsHosted == 0 && reviewCount == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
          elevation: isDark ? 0.0 : 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black)
                  .withAlpha((0.08 * 255).round()),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Host Rating',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Stars
                    Text(
                      HostRatingService.getRatingEmoji(rating),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Rating value and tier
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rating.toStringAsFixed(1),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                          ),
                        ),
                        Text(
                          tier,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Review count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          reviewCount.toString(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'review${reviewCount == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// CP-4: Build walk statistics section showing lifetime stats
  Widget _buildWalkStatsSection(BuildContext context, String userId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: WalkHistoryService.instance.getUserWalkStats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
            elevation: isDark ? 0.0 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withAlpha((0.08 * 255).round()),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        final stats = snapshot.data ?? {};
        final totalWalks = stats['totalWalksCompleted'] as int? ?? 0;
        final totalDistance = stats['totalDistanceKm'] as double? ?? 0.0;
        final totalSeconds = stats['totalDuration'] as int? ?? 0;
        final avgDistance = stats['averageDistancePerWalk'] as double? ?? 0.0;

        // Convert total seconds to hours:minutes
        final totalHours = totalSeconds ~/ 3600;
        final totalMinutes = (totalSeconds % 3600) ~/ 60;
        final timeStr = totalHours > 0
            ? '$totalHours h ${totalMinutes}m'
            : '${totalMinutes}m';

        if (totalWalks == 0) {
          return Card(
            color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
            elevation: isDark ? 0.0 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withAlpha((0.08 * 255).round()),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No completed walks yet. Start walking to see your lifetime stats!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lifetime stats',
              style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : _deepGreen,
                  ) ??
                  const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
              elevation: isDark ? 0.0 : 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withAlpha((0.08 * 255).round()),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            label: 'Total walks',
                            value: totalWalks.toString(),
                            icon: Icons.check_circle,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            label: 'Distance',
                            value: '${totalDistance.toStringAsFixed(1)} km',
                            icon: Icons.route,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            label: 'Time',
                            value: timeStr,
                            icon: Icons.timer,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            label: 'Avg distance',
                            value: '${avgDistance.toStringAsFixed(1)} km',
                            icon: Icons.trending_up,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build past walks section showing recent completed walks
  Widget _buildPastWalksSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: UserStatsService.instance.getQuickStats(uid).then((_) =>
          // Get recent completed walks from the user's walk history
          WalkHistoryService.instance
              .getPastWalks(limit: 5)
              .then((walks) => walks
                  .map((w) => {
                        'walkId': w.walkId,
                        'joinedAt': w.joinedAt,
                        'completed': w.completed,
                        'distance': w.actualDistanceKm ?? 0.0,
                      })
                  .toList())),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
            elevation: isDark ? 0.0 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color:
                    (isDark ? Colors.white : Colors.black)
                        .withAlpha((0.08 * 255).round()),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        final walks = snapshot.data ?? [];

        if (walks.isEmpty) {
          return Card(
            color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
            elevation: isDark ? 0.0 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color:
                    (isDark ? Colors.white : Colors.black)
                        .withAlpha((0.08 * 255).round()),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No completed walks yet. Join a walk to get started!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                ),
              ),
            ),
          );
        }

        return Card(
          color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
          elevation: isDark ? 0.0 : 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (isDark ? Colors.white : Colors.black)
                  .withAlpha((0.08 * 255).round()),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                walks.length,
                (index) {
                  final walk = walks[index];
                  final joinedAt = walk['joinedAt'] as DateTime? ?? DateTime.now();
                  final distance = walk['distance'] as double? ?? 0.0;
                  final isLast = index == walks.length - 1;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: const Color(0xFF00D97E),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Walk on ${joinedAt.day}/${joinedAt.month}/${joinedAt.year}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${distance.toStringAsFixed(1)} km',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withAlpha(150),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!isLast) ...[
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: (isDark ? Colors.white : Colors.black)
                              .withAlpha((0.06 * 255).round()),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgesSection(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Badges',
          style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : Colors.black,
              ) ??
              const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('badges')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Card(
                color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
                elevation: isDark ? 0.0 : 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: (isDark ? Colors.white : Colors.black)
                        .withAlpha((0.08 * 255).round()),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            final existing = {
              for (final d in docs) d.id: d.data() as Map<String, dynamic>
            };

            final merged = kBadgeCatalog.map((def) {
              final data = existing[def.id];
              final progress = ((data?['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
              final achieved = data?['achieved'] as bool? ?? false;
              final earnedAt = (data?['earnedAt'] as Timestamp?)?.toDate();

              return _BadgeView(
                id: def.id,
                title: def.title,
                description: def.description,
                progress: progress,
                target: def.target,
                achieved: achieved,
                icon: def.icon,
                earnedAt: earnedAt,
              );
            }).toList();

            final achievedBadges = merged.where((b) => b.achieved).toList();
            final inProgressBadges = merged
                .where((b) => !b.achieved)
                .toList()
              ..sort((a, b) => b.progress.compareTo(a.progress));

            final profileBadges = merged
                .map(
                  (b) => ProfileBadge(
                    id: b.id,
                    title: b.title,
                    description: b.description,
                    icon: b.icon,
                    achieved: b.achieved,
                  ),
                )
                .toList();

            return Card(
              color: isDark ? const Color(0xFF0C2430) : theme.cardColor,
              elevation: isDark ? 0.0 : 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withAlpha((0.08 * 255).round()),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (achievedBadges.isEmpty && inProgressBadges.isEmpty)
                      Text(
                        'Badges will appear here as you walk more.',
                        style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: isDark ? Colors.white70 : null,
                            ) ??
                            TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: isDark ? Colors.white70 : null,
                            ),
                      )
                    else ...[
                      if (achievedBadges.isNotEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: achievedBadges.take(6).map((b) {
                            return GestureDetector(
                              onTap: () => _showBadgeDetails(
                                ProfileBadge(
                                  id: b.id,
                                  title: b.title,
                                  description: b.description,
                                  icon: b.icon,
                                  achieved: b.achieved,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.primary,
                                child: Icon(
                                  b.icon,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      if (inProgressBadges.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Column(
                          children: inProgressBadges.take(3).map((b) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(b.icon, size: 18, color: theme.colorScheme.primary),
                                          const SizedBox(width: 8),
                                          Text(
                                            b.title,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? Colors.white : Colors.black,
                                                ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${(b.progress * 100).round()}%',
                                        style: theme.textTheme.labelMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: b.progress,
                                      minHeight: 8,
                                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    b.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _openBadgesPage(profileBadges),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('View all'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _openLeaderboard,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('🏆 Leaderboard'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
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

  void _openLeaderboard() {
    Navigator.of(context).pushNamed(BadgeLeaderboardScreen.routeName);
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

  Future<void> _exportWalkHistoryCsv() async {
    await _runExport(() => WalkExportService.instance.exportHistoryCsv());
  }

  Future<void> _exportWalkSummaryPdf() async {
    await _runExport(() => WalkExportService.instance.exportWalkSummaryPdf());
  }

  Future<void> _runExport(Future<void> Function() task) async {
    try {
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          title: Text('Preparing export'),
          content: SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      await task();

      if (!mounted) return;
      if (navigator.canPop()) {
        navigator.pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export ready to share.')),
      );
    } catch (e) {
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

    final double weeklyProgress = _weeklyGoalKmLocal <= 0
        ? 0
        : (widget.weeklyKm / _weeklyGoalKmLocal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF1ABFC4),
      body: Column(
        children: [
          if (_buildStaleDataBanner() != null) _buildStaleDataBanner()!,
          // ===== HEADER (match Home/Nearby) =====
          if (isDark)
            // ✅ Dark: NO BAR, floating header (same as Home)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: logo + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha((0.1 * 255).round()),
                          ),
                          child: const Icon(
                            Icons.directions_walk,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Transform.translate(
                          offset: const Offset(0, -2),
                          child: Text(
                            'Yalla Nemshi',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ) ??
                                const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                    // Right: friends, notif, settings
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.people_outline),
                          tooltip: 'My Friends',
                          onPressed: () {
                            Navigator.of(context).pushNamed('/friends');
                          },
                        ),
                        Semantics(
                          label: 'Notifications',
                          button: true,
                          child: GestureDetector(
                            onTap: _showNotificationsSheet,
                            child: Transform.translate(
                              offset: const Offset(0, -1),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withAlpha(
                                      (0.1 * 255).round(),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ✅ Settings icon (40x40)
                        Semantics(
                          label: 'Settings',
                          button: true,
                          child: GestureDetector(
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
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withAlpha(
                                    (0.1 * 255).round(),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.settings,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
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
            // ✅ Light: gradient bar (same as Home)
            Container(
              height: 80,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: const Icon(
                              Icons.directions_walk,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Transform.translate(
                            offset: const Offset(0, -2),
                            child: Text(
                              'Yalla Nemshi',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ) ??
                                  const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.people_outline),
                            tooltip: 'My Friends',
                            onPressed: () {
                              Navigator.of(context).pushNamed('/friends');
                            },
                          ),
                          Semantics(
                            label: 'Notifications',
                            button: true,
                            child: GestureDetector(
                              onTap: _showNotificationsSheet,
                              child: Transform.translate(
                                offset: const Offset(0, -1),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white24,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: 'Settings',
                            button: true,
                            child: GestureDetector(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                                final wg =
                                    await AppPreferences.getWeeklyGoalKm();
                                if (!mounted) return;
                                setState(() => _weeklyGoalKmLocal = wg);
                                widget.onWeeklyGoalChanged?.call(wg);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white24,
                                  ),
                                  child: const Icon(
                                    Icons.settings,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ),
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    kSpace2,
                    kSpace2,
                    kSpace2,
                    kSpace3 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Card(
                    color: isDark ? const Color(0xFF0C2430) : kLightSurface,
                    elevation: isDark
                        ? kCardElevationDark
                        : kCardElevationLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black).withAlpha(
                          (kCardBorderAlpha * 255).round(),
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
                                  fontFamily: 'Poppins',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark ? Colors.white : Colors.black,
                                ) ??
                                const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track your progress and edit your walking details.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ) ??
                                TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
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
                                    Semantics(
                                      label: 'Change profile picture',
                                      button: true,
                                      child: GestureDetector(
                                        onTap: _onAvatarTap,
                                        child: _buildAvatar(profile),
                                      ),
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
                                                fontFamily: 'Poppins',
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ) ??
                                              const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                              ),
                                        ),
                                      ),

                                      // ✅ Pen icon on the right, does NOT shift the text
                                      Positioned(
                                        right: 0,
                                        child: IconButton(
                                          onPressed: _openEditProfile,
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                          ),
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
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1ABFC4),
                                      ) ??
                                      const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1ABFC4),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile?.bio.isNotEmpty == true
                                      ? profile!.bio
                                      : 'Add a short bio about you',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
                                        color: theme.textTheme.bodySmall?.color,
                                      ) ??
                                      TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
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
                                      .withAlpha((0.12 * 255).round()),
                                ),
                                labelStyle: TextStyle(
                                  fontFamily: 'Inter',
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
                                        Chip(
                                          label: Text('Age: ${profile.age}'),
                                        ),
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
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark ? Colors.white : Colors.black,
                                ) ??
                                const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
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
                                    .withAlpha((0.08 * 255).round()),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
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
                                                    fontFamily: 'Inter',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    height: 1.45,
                                                    color: isDark
                                                        ? Colors.white
                                                        : null,
                                                  ) ??
                                                  TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    height: 1.45,
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
                                              ? Colors.white.withAlpha(
                                                  (0.08 * 255).round(),
                                                )
                                              : const Color(0xFFE5F3D9),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '${(weeklyProgress * 100).round()}%',
                                          style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.1,
                                                    color: isDark
                                                        ? Colors.white
                                                        : null,
                                                  ) ??
                                                  TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.1,
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
                                      final fillW =
                                          (c.maxWidth * weeklyProgress).clamp(
                                            0.0,
                                            c.maxWidth,
                                          );

                                      return Stack(
                                        children: [
                                          Container(
                                            height: trackH,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withAlpha(
                                                      (0.10 * 255).round(),
                                                    )
                                                  : Colors.black.withAlpha(
                                                      (0.06 * 255).round(),
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
                                          Container(
                                            height: trackH,
                                            width: fillW,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1ABFC4)
                                                  : const Color(0xFF1ABFC4),
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ) ??
                                    TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
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
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark ? Colors.white : Colors.black,
                                ) ??
                                const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark ? Colors.white70 : Colors.black54,
                                  ) ??
                                  const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // CP-4: Lifetime Walk Stats
                          _buildWalkStatsSection(
                            context,
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                          ),

                          const SizedBox(height: 24),

                          // Host Rating (only if user has hosted walks)
                          if (widget.eventsHosted > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHostRatingCard(
                                  context,
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),

                          _buildBadgesSection(context),

                          const SizedBox(height: 24),

                          // Past Walks Section
                          Text(
                            'Past walks',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPastWalksSection(context),

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
                                      .withAlpha((0.18 * 255).round()),
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
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _exportWalkHistoryCsv,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: BorderSide(
                                      color: (isDark ? Colors.white : Colors.black)
                                          .withAlpha((0.18 * 255).round()),
                                    ),
                                    foregroundColor: isDark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  icon: const Icon(Icons.table_view),
                                  label: const Text('Export walk history (CSV)'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _exportWalkSummaryPdf,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: BorderSide(
                                      color: (isDark ? Colors.white : Colors.black)
                                          .withAlpha((0.18 * 255).round()),
                                    ),
                                    foregroundColor: isDark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('Export walk summary (PDF)'),
                                ),
                              ),
                            ],
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
                                  color: Colors.red.withAlpha(
                                    (0.5 * 255).round(),
                                  ),
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
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTab,
        onTap: (index) {
          if (index == _currentTab) return;

          if (index == 3) {
            // Already on profile
            return;
          }

          // Navigate back to HomeScreen with the requested tab
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(initialTab: index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(UserProfile? profile) {
    final b64 = profile?.profileImageBase64;

    // Web (testing): show stored base64
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return CircleAvatar(
          radius: 48,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        // ignore decode errors and fall back
      }
    }

    final imgPath = profile?.profileImagePath;

    // Mobile/desktop: show file path
    if (!kIsWeb && imgPath != null && imgPath.isNotEmpty) {
      try {
        final file = File(imgPath);
        if (file.existsSync()) {
          return CircleAvatar(
            radius: 48,
            backgroundImage: FileImage(file),
          );
        }
      } catch (_) {
        // ignore and fall back
      }
    }

    // Firebase Auth photo (e.g., Google sign-in)
    final authPhoto = FirebaseAuth.instance.currentUser?.photoURL;
    if (authPhoto != null && authPhoto.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(authPhoto),
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
    bool compact = false,
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
            color: (isDark ? Colors.white : Colors.black).withAlpha(
              (0.08 * 255).round(),
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 12,
            horizontal: compact ? 8 : 8,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isDark ? Colors.white : null,
                size: compact ? 18 : 24,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                  fontSize: compact ? 13 : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white70 : null,
                  fontSize: compact ? 11 : null,
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
