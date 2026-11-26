// lib/screens/profile_screen.dart
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../services/firestore_user_service.dart';
import '../services/host_rating_service.dart';
import '../services/user_stats_service.dart';
import '../services/walk_history_service.dart';
import '../services/crash_service.dart';
import '../services/walk_completion_service.dart';
import '../services/walk_export_service.dart';
import '../models/profile_badge.dart';
import '../models/badge.dart';

import 'badges_info_screen.dart';
import 'edit_profile_screen.dart';
import 'safety_tips_screen.dart';
import 'login_screen.dart'; // for routeName
import 'settings_screen.dart';
import 'badge_leaderboard_screen.dart';
import 'analytics_screen.dart';
import '../services/app_preferences.dart';
import '../services/profile_cache_service.dart';
import '../services/offline_service.dart';
import '../screens/notifications_screen.dart';
import '../theme/app_palette.dart';
import 'profile/profile_view.dart';
import '../widgets/ui/ui_kit.dart';

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

  late double _weeklyGoalKmLocal;
  bool _isOffline = false;
  bool _isProfileStale = false;

  late final VoidCallback _offlineListener;

  // Lifetime / weekly numbers loaded from Firestore. The values passed in by
  // HomeScreen only cover walks currently on the home list (upcoming/active),
  // so finished walks never counted; these replace them once loaded.
  int? _cloudJoined;
  int? _cloudHosted;
  double? _cloudTotalKm;
  int? _cloudWeeklyWalks;
  double? _cloudWeeklyKm;

  int get _walksJoined => _cloudJoined ?? widget.walksJoined;
  int get _eventsHosted => _cloudHosted ?? widget.eventsHosted;
  double get _totalKm => _cloudTotalKm ?? widget.totalKm;
  int get _weeklyWalks => _cloudWeeklyWalks ?? widget.weeklyWalks;
  double get _weeklyKm => _cloudWeeklyKm ?? widget.weeklyKm;

  @override
  void initState() {
    super.initState();

    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint(
      '👤👤👤 PROFILE_SCREEN.initState - Current User: ${currentUser?.uid}',
    );
    debugPrint(
      '👤👤👤 PROFILE_SCREEN.initState - Display Name: ${currentUser?.displayName}',
    );

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
    _loadCloudStats();
  }

  /// Count finished walks first (free plan: nobody else does it), then load
  /// the user's real totals from Firestore.
  Future<void> _loadCloudStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await WalkCompletionService.completePendingForMe();

      final db = FirebaseFirestore.instance;
      final walks = db.collection('walks');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));

      final results = await Future.wait([
        walks
            .where('hostUid', isEqualTo: uid)
            .where('cancelled', isEqualTo: false)
            .count()
            .get(),
        walks
            .where('joinedUserUids', arrayContains: uid)
            .where('cancelled', isEqualTo: false)
            .count()
            .get(),
      ]);
      final statsDoc = await db
          .collection('users')
          .doc(uid)
          .collection('stats')
          .doc('walkStats')
          .get();
      final thisWeek = await db
          .collection('users')
          .doc(uid)
          .collection('walks')
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .get();
      final weekly = thisWeek.docs.where((d) => d.data()['completed'] == true);

      if (!mounted) return;
      setState(() {
        _cloudHosted = results[0].count ?? 0;
        _cloudJoined = results[1].count ?? 0;
        _cloudTotalKm =
            (statsDoc.data()?['totalDistanceKm'] as num?)?.toDouble() ?? 0.0;
        _cloudWeeklyWalks = weekly.length;
        _cloudWeeklyKm = weekly.fold<double>(
          0.0,
          (acc, d) =>
              acc + ((d.data()['actualDistanceKm'] as num?)?.toDouble() ?? 0.0),
        );
      });
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'ProfileScreen._loadCloudStats');
    }
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

    // Nothing (or no name) saved on this device, e.g. a new browser or phone:
    // use the account's profile (Firestore), then the sign-in name.
    if (p == null || p.name.trim().isEmpty) {
      final cloud = await FirestoreUserService.getCurrentUser();
      final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
      final name = (cloud?.displayName.trim().isNotEmpty ?? false)
          ? cloud!.displayName.trim()
          : (authName ?? '');
      if (name.isNotEmpty) {
        p = UserProfile(
          name: name,
          age: p?.age ?? cloud?.age ?? 0,
          gender: p?.gender ?? cloud?.gender ?? 'Not set',
          bio: (p?.bio.isNotEmpty ?? false) ? p!.bio : (cloud?.bio ?? ''),
          profileImagePath: p?.profileImagePath,
          profileImageBase64: p?.profileImageBase64,
        );
        await ProfileStorage.saveProfile(p);
      }
    }

    if (!mounted) return;
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
    final hasPhoto =
        (_profile?.profileImageBase64 != null &&
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
                  style: TextStyle(fontFamily: 'Inter', color: Colors.red),
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
    final km = _totalKm;
    if (km < 5) return 'New walker';
    if (km < 25) return 'Getting active';
    if (km < 100) return 'Regular walker';
    if (km < 250) return 'Committed walker';
    return 'Trail pro';
  }

  /// Build host rating widget
  Widget _buildHostRatingCard(BuildContext context, String userId) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: HostRatingService.instance.getHostRating(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            padding: EdgeInsets.zero,
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
        if (_eventsHosted == 0 && reviewCount == 0) {
          return const SizedBox.shrink();
        }

        return AppCard(
          padding: EdgeInsets.zero,
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
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 20),
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
                        Text(tier, style: theme.textTheme.bodySmall),
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

    return FutureBuilder<Map<String, dynamic>>(
      future: WalkHistoryService.instance.getUserWalkStats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            padding: EdgeInsets.zero,
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
          return AppCard(
            padding: EdgeInsets.zero,
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
            AppCard(
              padding: EdgeInsets.zero,
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
      future: UserStatsService.instance
          .getQuickStats(uid)
          .then(
            (_) =>
                // Get recent completed walks from the user's walk history
                WalkHistoryService.instance
                    .getPastWalks(limit: 5)
                    .then(
                      (walks) => walks
                          .map(
                            (w) => {
                              'walkId': w.walkId,
                              'joinedAt': w.joinedAt,
                              'completed': w.completed,
                              'distance': w.actualDistanceKm ?? 0.0,
                            },
                          )
                          .toList(),
                    ),
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppCard(
            padding: EdgeInsets.zero,
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
          return AppCard(
            padding: EdgeInsets.zero,
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

        return AppCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(walks.length, (index) {
                final walk = walks[index];
                final joinedAt =
                    walk['joinedAt'] as DateTime? ?? DateTime.now();
                final distance = walk['distance'] as double? ?? 0.0;
                final isLast = index == walks.length - 1;

                return Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: AppPalette.lime,
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
                        color: (isDark ? Colors.white : Colors.black).withAlpha(
                          (0.06 * 255).round(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }),
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
        const SectionHeader(title: 'Badges'),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('badges')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return AppCard(
                padding: EdgeInsets.zero,
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
              for (final d in docs) d.id: d.data() as Map<String, dynamic>,
            };

            final merged = kBadgeCatalog.map((def) {
              final data = existing[def.id];
              final progress = ((data?['progress'] as num?)?.toDouble() ?? 0)
                  .clamp(0.0, 1.0);
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
            final inProgressBadges = merged.where((b) => !b.achieved).toList()
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

            return AppCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (achievedBadges.isEmpty && inProgressBadges.isEmpty)
                      Text(
                        'Badges will appear here as you walk more.',
                        style:
                            theme.textTheme.bodySmall?.copyWith(
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            b.icon,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            b.title,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
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
                                      backgroundColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.4),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    b.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey.shade700,
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
                              child: const Text('Leaderboard'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export ready to share.')));
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
    await ProfileCacheService.instance.clearCache();
    await FirebaseAuth.instance.signOut();

    // Clear Google Sign-In cache so next login shows account picker
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint('Google Sign-In signOut error: $e');
      }
    }

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  Future<void> _switchAccount() async {
    try {
      // Sign out from Firebase and Google
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();

      if (!mounted) return;

      // Immediately trigger Google Sign-In which shows account picker
      if (kIsWeb) {
        // Web: use Firebase popup
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        await FirebaseAuth.instance.signInWithPopup(googleProvider);

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Mobile: Use google_sign_in plugin which shows account picker
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // User cancelled - go to login screen
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      debugPrint('Error switching account: $e');
      if (!mounted) return;
      // On error, go to login screen
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
    }
  }

  void _showNotificationsSheet() {
    Navigator.pushNamed(context, NotificationsScreen.routeName);
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    final wg = await AppPreferences.getWeeklyGoalKm();
    if (!mounted) return;
    setState(() => _weeklyGoalKmLocal = wg);
    widget.onWeeklyGoalChanged?.call(wg);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppPalette.of(context).background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final weeklyProgress = _weeklyGoalKmLocal <= 0
        ? 0.0
        : (_weeklyKm / _weeklyGoalKmLocal).clamp(0.0, 1.0);

    return ProfileView(
      name: profile?.name ?? '',
      bio: profile?.bio ?? '',
      age: profile?.age,
      gender: profile?.gender,
      walkerLevel: _walkerLevel,
      weeklyWalks: _weeklyWalks,
      weeklyKm: _weeklyKm,
      weeklyGoalKm: _weeklyGoalKmLocal,
      motivation: _weeklyMotivationText(
        progress: weeklyProgress,
        weeklyKm: _weeklyKm,
        weeklyGoalKm: _weeklyGoalKmLocal,
        streakDays: widget.streakDays,
      ),
      walksJoined: _walksJoined,
      walksHosted: _eventsHosted,
      totalKm: _totalKm,
      interestedCount: widget.interestedCount,
      avatar: _buildAvatar(profile),
      banner: _buildStaleDataBanner(),
      lifetimeStats: _buildWalkStatsSection(context, uid),
      hostRating: _buildHostRatingCard(context, uid),
      badges: _buildBadgesSection(context),
      pastWalks: _buildPastWalksSection(context),
      actions: ProfileActions(
        onFriends: () => Navigator.of(context).pushNamed('/friends'),
        onNotifications: _showNotificationsSheet,
        onSettings: _openSettings,
        onAvatarTap: _onAvatarTap,
        onEditProfile: _openEditProfile,
        onAnalytics: () =>
            Navigator.of(context).pushNamed(AnalyticsScreen.routeName),
        onSafetyTips: _openSafetyTips,
        onExportCsv: _exportWalkHistoryCsv,
        onExportPdf: _exportWalkSummaryPdf,
        onSwitchAccount: _switchAccount,
        onSignOut: _signOut,
        // Close Profile and tell Home which tab to show (-1 = create a walk).
        onNavTap: (index) => Navigator.of(context).pop(index),
        onCreateWalk: () => Navigator.of(context).pop(-1),
      ),
    );
  }

  Widget _buildAvatar(UserProfile? profile) {
    final b64 = profile?.profileImageBase64;

    // Web (testing): show stored base64
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return CircleAvatar(radius: 48, backgroundImage: MemoryImage(bytes));
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
          return CircleAvatar(radius: 48, backgroundImage: FileImage(file));
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
        backgroundColor: AppPalette.lime,
        foregroundImage: NetworkImage(authPhoto),
        onForegroundImageError: (_, _) {},
        child: const Icon(Icons.person, size: 48, color: AppPalette.ink),
      );
    }

    return const CircleAvatar(
      radius: 48,
      backgroundColor: AppPalette.lime,
      child: Icon(Icons.person, size: 48, color: AppPalette.ink),
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
      child: AppCard(
        padding: EdgeInsets.zero,
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
