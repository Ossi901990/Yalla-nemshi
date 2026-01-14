// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import '../models/walk_event.dart';
import '../services/notification_service.dart';
import '../services/app_preferences.dart';
import '../services/crash_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/walk_history_service.dart';
import '../services/user_stats_service.dart';
import '../utils/error_handler.dart';
import '../services/profile_storage.dart';
import '../models/user_profile.dart';
import '../widgets/app_bottom_nav_bar.dart';

import 'create_walk_screen.dart';
import 'event_details_screen.dart';
import 'profile_screen.dart';
import 'walks_screen.dart';
import 'events_screen.dart';
import '../models/app_notification.dart';
import '../services/notification_storage.dart';
import '../providers/auth_provider.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ===== Dark Theme (Neo/Night Forest) palette =====
const kDarkBg = Color(0xFF071B26); // primary background
const kDarkSurface = Color(0xFF0C2430); // cards / sheets
const kDarkSurface2 = Color(0xFF0E242E); // nav / secondary surfaces

const kMint = Color(0xFF8BD5BA); // primary accent
const kMintBright = Color(0xFFA4E4C5); // highlight accent

const kTextPrimary = Color(0xFFD9F5EA); // big text
const kTextSecondary = Color(0xFF9BB9B1); // normal text
const kTextMuted = Color(0xFF6A8580); // hints / placeholders
const kOnMint = Color(0xFF0C1A17); // text on mint buttons

// ===== Design tokens (radius) =====
const double kRadiusCard = 24;
const double kRadiusControl = 16; // buttons, small containers, inputs
const double kRadiusPill = 999; // badges, chips

// ===== Design tokens (spacing) =====
const double kSpace1 = 8;
const double kSpace2 = 16;
const double kSpace3 = 24;
const double kSpace4 = 32;

// ===== Card tokens =====
const kLightSurface = Color(0xFFFBFEF8); // light-mode card background
const double kCardElevationLight = 0.6; // subtle shadow in light mode
const double kCardElevationDark = 0.0; // no shadow in dark mode
const double kCardBorderAlpha = 0.06; // subtle border for both themes

// ===== Button tokens =====
const double kBtnHeight = 52;
const EdgeInsets kBtnPadding = EdgeInsets.symmetric(vertical: kSpace2);

class HomeScreen extends ConsumerStatefulWidget {
  final int initialTab;
  
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _currentTab;
  void _listenToWalks() {
    _walksSub?.cancel();

    // Get user's city first
    AppPreferences.getUserCity()
        .then((userCity) {
          if (!mounted) return;

          // Build query: filter by city if user has one set
          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection('walks');

          if (userCity != null && userCity.isNotEmpty) {
            debugPrint('🏙️ Filtering walks by city: $userCity');
            query = query.where('city', isEqualTo: userCity);
          } else {
            debugPrint('⚠️ No user city set; showing all walks');
          }

          // Exclude private walks to satisfy Firestore rules for list queries
          // Note: Firestore requires ordering by the same field when using isNotEqualTo
          query = query
              .where('visibility', isNotEqualTo: 'private')
              .orderBy('visibility')
              .where('cancelled', isEqualTo: false);

          // Add pagination limit
          query = query.limit(_walksPerPage);

          _walksSub = query.snapshots().listen(
            (snap) {
              try {
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                debugPrint(
                  'WALKS SNAP: docs=${snap.docs.length} uid=$currentUid city=$userCity',
                );

                // Track last document for pagination
                if (snap.docs.isNotEmpty) {
                  _lastDocument = snap.docs.last;
                  _hasMoreWalks = snap.docs.length >= _walksPerPage;
                } else {
                  _lastDocument = null;
                  _hasMoreWalks = false;
                }

                final List<WalkEvent> loaded = snap.docs.map((doc) {
                  final data = Map<String, dynamic>.from(doc.data());
                  data['firestoreId'] = doc.id;
                  data['id'] ??= doc.id;

                  final hostUid = data['hostUid'] as String?;
                  data['isOwner'] =
                      (currentUid != null &&
                      hostUid != null &&
                      hostUid == currentUid);

                  final joinedUids =
                      (data['joinedUids'] as List?)
                          ?.whereType<String>()
                          .toList() ??
                      [];
                  data['joined'] =
                      (currentUid != null && joinedUids.contains(currentUid));

                  return WalkEvent.fromMap(data);
                }).toList();

                if (!mounted) return;

                // 🔔 Check for newly added walks and trigger notifications
                for (var change in snap.docChanges) {
                  if (change.type == DocumentChangeType.added) {
                    final data = Map<String, dynamic>.from(
                      change.doc.data() as Map,
                    );
                    data['firestoreId'] = change.doc.id;
                    data['id'] ??= change.doc.id;

                    final hostUid = data['hostUid'] as String?;
                    data['isOwner'] =
                        (currentUid != null &&
                        hostUid != null &&
                        hostUid == currentUid);

                    final joinedUids =
                        (data['joinedUids'] as List?)
                            ?.whereType<String>()
                            .toList() ??
                        [];
                    data['joined'] =
                        (currentUid != null && joinedUids.contains(currentUid));

                    final newWalk = WalkEvent.fromMap(data);
                    // Only notify if it's not the current user's walk
                    if (newWalk.hostUid != currentUid) {
                      _onNewNearbyWalk(newWalk);
                    }
                  }
                }

                // Collapse recurring instances into one card per series (show next upcoming)
                final now = DateTime.now();
                final Map<String, List<WalkEvent>> series = {};
                final List<WalkEvent> singles = [];

                for (final e in loaded) {
                  // Hide recurring templates entirely
                  if (e.isRecurringTemplate) {
                    continue;
                  }

                  if (e.isRecurring && e.recurringGroupId != null) {
                    series.putIfAbsent(e.recurringGroupId!, () => []).add(e);
                  } else {
                    singles.add(e);
                  }
                }

                final List<WalkEvent> merged = []..addAll(singles);

                for (final group in series.values) {
                  // pick the soonest future occurrence, otherwise the earliest in the series
                  WalkEvent? candidate;
                  for (final e in group) {
                    final isFuture = e.dateTime.isAfter(now);
                    if (candidate == null) {
                      candidate = e;
                    } else {
                      final betterFuture =
                          isFuture && !candidate.dateTime.isAfter(now);
                      final earlierSameBucket =
                          (isFuture == candidate.dateTime.isAfter(now)) &&
                          e.dateTime.isBefore(candidate.dateTime);
                      if (betterFuture || earlierSameBucket) {
                        candidate = e;
                      }
                    }
                  }
                  if (candidate != null) {
                    merged.add(candidate);
                  }
                }

                merged.sort((a, b) => a.dateTime.compareTo(b.dateTime));

                setState(() {
                  _events
                    ..clear()
                    ..addAll(merged);
                });
              } catch (e, st) {
                debugPrint('❌ Error processing walks snapshot: $e');
                CrashService.recordError(e, st);
              }
            },
            onError: (e, st) {
              debugPrint('❌ WALKS STREAM ERROR: $e');
              CrashService.recordError(e, st);

              // Attempt to recover by resetting listener
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) {
                  debugPrint('↻ Attempting to reconnect to walks stream...');
                  _listenToWalks();
                }
              });
            },
          );
        })
        .catchError((e, st) {
          debugPrint('❌ Error getting user city: $e');
          CrashService.recordError(e, st ?? StackTrace.current);
          // Try again without city filter
          if (!mounted) return;

          try {
            _walksSub = FirebaseFirestore.instance
                .collection('walks')
                .where('visibility', isNotEqualTo: 'private')
                .orderBy('visibility')
                .limit(_walksPerPage)
                .snapshots()
                .listen(
                  (snap) {
                    try {
                      final currentUid = FirebaseAuth.instance.currentUser?.uid;
                      final List<WalkEvent> loaded = snap.docs.map((doc) {
                        final data = Map<String, dynamic>.from(doc.data());
                        data['firestoreId'] = doc.id;
                        data['id'] ??= doc.id;
                        final hostUid = data['hostUid'] as String?;
                        data['isOwner'] =
                            currentUid != null && hostUid == currentUid;
                        final joinedUids =
                            (data['joinedUids'] as List?)
                                ?.whereType<String>()
                                .toList() ??
                            [];
                        data['joined'] =
                            currentUid != null &&
                            joinedUids.contains(currentUid);
                        return WalkEvent.fromMap(data);
                      }).toList();

                      if (mounted) {
                        setState(() {
                          _events
                            ..clear()
                            ..addAll(loaded);
                        });
                      }
                    } catch (e, st) {
                      CrashService.recordError(e, st);
                    }
                  },
                  onError: (e, st) {
                    CrashService.recordError(e, st);
                  },
                );
          } catch (e, st) {
            CrashService.recordError(e, st);
          }
        });
  }

  /// Load more walks (next page)
  /// Note: If you see a Firestore error about composite indexes on first use,
  /// click the link in the error to create the index for (city, __name__).
  /// Firestore will auto-create it and pagination will work after that.
  Future<void> _loadMoreWalks() async {
    if (_isLoadingMore || !_hasMoreWalks || _lastDocument == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final userCity = await AppPreferences.getUserCity();

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('walks')
          .where('visibility', isNotEqualTo: 'private')
          .orderBy('visibility')
          .startAfterDocument(_lastDocument!);

      if (userCity != null && userCity.isNotEmpty) {
        query = query.where('city', isEqualTo: userCity);
      }

      query = query.limit(_walksPerPage);

      final snap = await query.get().timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        setState(() {
          _hasMoreWalks = false;
          _isLoadingMore = false;
        });
        return;
      }

      _lastDocument = snap.docs.last;
      _hasMoreWalks = snap.docs.length >= _walksPerPage;

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final List<WalkEvent> newWalks = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['firestoreId'] = doc.id;
        data['id'] ??= doc.id;

        final hostUid = data['hostUid'] as String?;
        data['isOwner'] =
            (currentUid != null && hostUid != null && hostUid == currentUid);

        final joinedUids =
            (data['joinedUids'] as List?)?.whereType<String>().toList() ?? [];
        data['joined'] =
            (currentUid != null && joinedUids.contains(currentUid));

        return WalkEvent.fromMap(data);
      }).toList();

      setState(() {
        _events.addAll(newWalks);
        _isLoadingMore = false;
      });

      debugPrint(
        '📄 Loaded ${newWalks.length} more walks. Total: ${_events.length}',
      );
    } on TimeoutException catch (e, st) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        CrashService.recordError(e, st);
        ErrorHandler.showErrorSnackBar(
          context,
          'Loading more walks took too long. Try again.',
        );
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });

        debugPrint('❌ Error loading more walks: $e');
        CrashService.recordError(e, st);

        String message = 'Unable to load more walks';
        if (e.toString().contains('network') ||
            e.toString().contains('Connection')) {
          message = 'Network error. Check your connection and try again.';
        }

        ErrorHandler.showErrorSnackBar(context, message);
      }
    }
  }

  /// All events (hosted by user + nearby).
  final List<WalkEvent> _events = [];

  // Pagination state
  static const int _walksPerPage = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreWalks = true;
  bool _isLoadingMore = false;

  // Loaded from saved profile (falls back to "Walker")
  String _userName = 'Walker';
  UserProfile? _profile;

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  bool _hasUpcomingWalkOnDay(DateTime day) {
    final now = DateTime.now();

    return _events.any((e) {
      if (e.cancelled) return false;
      if (!e.dateTime.isAfter(now)) return false; // exclude past walks
      return isSameDay(e.dateTime, day);
    });
  }

  // --- Step counter (Android, session-based for now) ---
  StreamSubscription<QuerySnapshot>? _walksSub;

  int _unreadNotifCount = 0;

  StreamSubscription<StepCount>? _stepSubscription;
  int _sessionSteps = 0;
  int? _baselineSteps;

  String _greetingForTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // --- Derived views & helpers ---

  List<WalkEvent> get _myHostedWalks =>
      _events.where((e) => e.isOwner && !e.cancelled).toList();

  List<WalkEvent> get _nearbyWalks =>
      _events.where((e) => !e.isOwner && !e.cancelled).toList();

  int get _walksJoined => _events.where((e) => e.joined && !e.cancelled).length;

  int get _eventsHosted =>
      _events.where((e) => e.isOwner && !e.cancelled).length;

  double get _totalKmJoined => _events
      .where((e) => e.joined && !e.cancelled)
      .fold<double>(0.0, (acc, e) => acc + e.distanceKm);

  int get _interestedCount =>
      _events.where((e) => e.interested && !e.cancelled).length;

  // Weekly statistics (for "This week" card)
  // Now loaded from AppPreferences instead of hard-coded.
  double _weeklyGoalKm = 10.0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart {
    // Monday as start of week
    final t = _today;
    return t.subtract(Duration(days: t.weekday - 1));
  }

  List<WalkEvent> get _myWalksThisWeek {
    final start = _weekStart;
    final end = start.add(const Duration(days: 7));

    return _events.where((e) {
      if (e.cancelled) return false;
      if (!(e.joined || e.isOwner)) return false; // only my walks

      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();
  }

  int get _weeklyWalkCount => _myWalksThisWeek.length;

  double get _weeklyKm =>
      _myWalksThisWeek.fold(0.0, (acc, e) => acc + e.distanceKm);

  // Simple streak: how many consecutive days up to today with >=1 of my walks
  int get _streakDays {
    int streak = 0;
    DateTime day = _today;

    while (true) {
      final hasWalkThatDay = _events.any((e) {
        if (e.cancelled) return false;
        if (!(e.joined || e.isOwner)) return false;

        final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
        return d.year == day.year && d.month == day.month && d.day == day.day;
      });

      if (hasWalkThatDay) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // Events that should show as dots on a specific calendar day
  List<WalkEvent> _eventsForDay(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);

    // ✅ Only walks that YOU host or joined and are not cancelled
    return _events.where((e) {
      if (e.cancelled) return false;
      if (!(e.joined || e.isOwner)) return false;

      final ed = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      return ed.year == d0.year && ed.month == d0.month && ed.day == d0.day;
    }).toList();
  }

  String _formatNotificationTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(dt.year, dt.month, dt.day);

    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final timePart = '$hh:$mm';

    if (thatDay == today) {
      return 'Today • $timePart';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (thatDay == yesterday) {
      return 'Yesterday • $timePart';
    }

    // Fallback: simple date
    final dd = dt.day.toString().padLeft(2, '0');
    final mm2 = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$dd/$mm2/$yyyy • $timePart';
  }

  Widget _buildCalendarDayCell(
    DateTime day,
    bool isDark, {
    bool forceSelected = false,
  }) {
    final bool isSelected = forceSelected || isSameDay(_selectedDay, day);
    final bool isToday = isSameDay(day, DateTime.now());
    final bool hasWalk = _hasUpcomingWalkOnDay(day);

    // ✅ Single-letter labels to match your UI
    String dowLetter(int weekday) {
      // weekday: Mon=1 ... Sun=7
      switch (weekday) {
        case DateTime.monday:
          return 'M';
        case DateTime.tuesday:
          return 'T';
        case DateTime.wednesday:
          return 'W';
        case DateTime.thursday:
          return 'T';
        case DateTime.friday:
          return 'F';
        case DateTime.saturday:
          return 'S';
        case DateTime.sunday:
        default:
          return 'S';
      }
    }

    // ✅ Priority: Selected > Walk day > Today > Normal
    Color bg;
    Color border;
    Color labelColor;
    Color numberColor;

    if (isSelected) {
      bg = isDark ? const Color(0xFF2E7D32) : const Color(0xFF14532D);
      border = Colors.transparent;
      labelColor = Colors.white.withAlpha((0.9 * 255).round());
      numberColor = Colors.white;
    } else if (hasWalk) {
      bg = isDark ? const Color(0xFF9BD77A) : const Color(0xFF9BD77A);
      border = Colors.transparent;
      labelColor = isDark ? Colors.black87 : Colors.black87;
      numberColor = Colors.black87;
    } else if (isToday) {
      // ✅ Today gets a subtle outline ONLY (different from walk highlight)
      bg = Colors.transparent;
      border = isDark ? Colors.white24 : Colors.black12;
      labelColor = isDark ? Colors.white70 : Colors.black54;
      numberColor = isDark ? Colors.white : Colors.black87;
    } else {
      bg = isDark ? Colors.white10 : const Color(0xFFEFE6D9);
      border = Colors.transparent;
      labelColor = isDark ? Colors.white70 : Colors.black54;
      numberColor = isDark ? Colors.white : Colors.black87;
    }

    // ✅ FIX: Force every cell to same size to prevent weird pills + overflow
    const double cellSize = 44;

    return Center(
      child: SizedBox(
        width: cellSize,
        height: cellSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(kRadiusPill),

            // ✅ Walk day indicator
            // - if it has an upcoming walk and it's not selected → show a subtle border
            // - if it's selected → keep selected clean (no extra border needed)
            border: (hasWalk && !isSelected)
                ? Border.all(
                    color: isDark
                        ? Colors.white.withAlpha((0.18 * 255).round())
                        : const Color(
                            0xFF2E7D32,
                          ).withAlpha((0.55 * 255).round()),
                    width: 1.4,
                  )
                : Border.all(
                    color:
                        border, // your existing border logic (today/normal/selected)
                    width: 1.0,
                  ),
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dowLetter(day.weekday),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: numberColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step counter setup (Android only for now) ---

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _initStepCounter();
    _loadUserName();
    _loadProfile(); // ✅ load saved avatar
    _loadWeeklyGoal();
    _listenToWalks();

    // 🔹 Sync user profile to Firestore (if missing)
    FirestoreSyncService.syncCurrentUser();

    Future.microtask(() async {
      try {
        final currentUserId = ref.read(currentUserIdProvider);
        final snap = await FirebaseFirestore.instance.collection('walks').get();
        debugPrint('WALKS GET: docs=${snap.docs.length} uid=$currentUserId');
      } catch (e) {
        debugPrint('WALKS GET ERROR: $e');
      }
    });
  }

  @override
  void dispose() {
    _walksSub?.cancel();
    _stepSubscription?.cancel();

    super.dispose();
  }

  Future<void> _loadWeeklyGoal() async {
    try {
      final value = await AppPreferences.getWeeklyGoalKm();
      if (mounted) {
        setState(() {
          _weeklyGoalKm = value;
        });
      }
    } catch (e, st) {
      debugPrint('⚠️ Error loading weekly goal: $e');
      CrashService.recordError(e, st);
      // Fall back to default (already set in class)
    }
  }

  Future<void> _refreshNotificationsCount() async {
    try {
      final unread = await NotificationStorage.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifCount = unread);
    } catch (e, st) {
      debugPrint('⚠️ Error refreshing notification count: $e');
      CrashService.recordError(e, st);
    }
  }

  /// Called when user changes their weekly goal from the Profile settings panel.
  Future<void> _updateWeeklyGoal(double newKm) async {
    setState(() {
      _weeklyGoalKm = newKm;
    });
    await AppPreferences.setWeeklyGoalKm(newKm);
  }

  Future<void> _initStepCounter() async {
    // Only try on Android
    if (!Platform.isAndroid) return;

    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        debugPrint('⚠️ Activity recognition permission denied');
        return;
      }

      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error, stackTrace) {
          debugPrint('❌ Pedometer error: $error');
          CrashService.recordError(error, stackTrace ?? StackTrace.current);
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      debugPrint('❌ Error initializing step counter: $e');
      CrashService.recordError(e, st);
      // Don't fail the entire app, just skip step counter
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ProfileStorage.loadProfile();
      if (!mounted) return;
      setState(() => _profile = p);
    } catch (_) {
      // keep silent; header can fall back to default icon
    }
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      setState(() {
        if (user != null &&
            user.displayName != null &&
            user.displayName!.trim().isNotEmpty) {
          _userName = user.displayName!.trim();
        } else {
          _userName = 'Walker';
        }
      });
    } catch (e, st) {
      debugPrint('❌ Error loading user name: $e');
      CrashService.recordError(e, st);
      // Fall back to default
      if (mounted) {
        setState(() => _userName = 'Walker');
      }
    }
  }

  void _onStepCount(StepCount event) {
    // Android pedometer gives "steps since reboot".
    _baselineSteps ??= event.steps;

    final steps = event.steps - (_baselineSteps ?? event.steps);
    if (steps < 0) return;

    setState(() {
      _sessionSteps = steps;
    });
  }

  // --- Actions ---

  void _onEventCreated(WalkEvent newEvent) {
    setState(() {
      _events.add(newEvent);
    });

    // 🔔 Schedule reminder for the walk you just created (host)
    NotificationService.instance.scheduleWalkReminder(newEvent);
  }

  /// Call this when a *new nearby* walk arrives from your backend / API.
  void _onNewNearbyWalk(WalkEvent event) {
    setState(() {
      _events.add(event); // add to main list
    });

    // 🔔 Instant “nearby walk” notification (honors Settings toggle)
    NotificationService.instance.showNearbyWalkAlert(event);
  }

  Future<void> _toggleJoin(WalkEvent event) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(context, 'Please log in to join walks.');
      return;
    }

    // ✅ Always use Firestore doc id
    final walkId = event.firestoreId.isNotEmpty ? event.firestoreId : event.id;
    final docRef = FirebaseFirestore.instance.collection('walks').doc(walkId);

    final bool wasJoined = event.joined;
    final bool willJoin = !wasJoined;

    // Get current user info for optimistic update
    final currentUser = FirebaseAuth.instance.currentUser;
    final userPhotoUrl = currentUser?.photoURL;

    // ✅ Optimistic UI update
    setState(() {
      final index = _events.indexWhere((e) {
        final idA = e.firestoreId.isNotEmpty ? e.firestoreId : e.id;
        final idB = walkId;
        return idA == idB;
      });
      if (index == -1) return;

      final currentEvent = _events[index];
      final newJoinedUids = List<String>.from(currentEvent.joinedUserUids);
      final newJoinedPhotos = List<String>.from(
        currentEvent.joinedUserPhotoUrls,
      );

      if (willJoin) {
        if (!newJoinedUids.contains(uid)) {
          newJoinedUids.add(uid);
        }
        if (userPhotoUrl != null && !newJoinedPhotos.contains(userPhotoUrl)) {
          newJoinedPhotos.add(userPhotoUrl);
        }
      } else {
        newJoinedUids.remove(uid);
        if (userPhotoUrl != null) {
          newJoinedPhotos.remove(userPhotoUrl);
        }
      }

      _events[index] = currentEvent.copyWith(
        joined: willJoin,
        joinedUserUids: newJoinedUids,
        joinedUserPhotoUrls: newJoinedPhotos,
        joinedCount: newJoinedUids.length,
      );
    });

    try {
      // ✅ Get current user info for participant data
      final currentUser = FirebaseAuth.instance.currentUser;
      final userPhotoUrl = currentUser?.photoURL;

      // ✅ Persist to Firestore with timeout
      final updateData = <String, dynamic>{
        'joinedUids': willJoin
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
        'joinedUserUids': willJoin
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
        'joinedCount': willJoin
            ? FieldValue.increment(1)
            : FieldValue.increment(-1),
      };

      // Only include photo updates when we actually have a photo URL
      if (userPhotoUrl != null) {
        updateData['joinedUserPhotoUrls'] = willJoin
            ? FieldValue.arrayUnion([userPhotoUrl])
            : FieldValue.arrayRemove([userPhotoUrl]);
      }

      await docRef.update(updateData).timeout(const Duration(seconds: 15));

      // ✅ Record walk history for tracking
      if (willJoin) {
        await WalkHistoryService.instance.recordWalkJoin(walkId);
        await UserStatsService.instance.recordWalkJoined(uid);
      } else {
        await WalkHistoryService.instance.recordWalkLeave(walkId);
      }

      // 🔔 Notifications
      final updated = event.copyWith(joined: willJoin);
      if (willJoin) {
        NotificationService.instance.scheduleWalkReminder(updated);
      } else {
        NotificationService.instance.cancelWalkReminder(updated);
      }

      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          willJoin ? 'You joined the walk!' : 'You left the walk.',
          duration: const Duration(seconds: 2),
        );
      }
    } on TimeoutException catch (e, st) {
      // ❌ Roll back on timeout
      _rollbackJoinStatus(walkId, wasJoined);

      if (mounted) {
        CrashService.recordError(e, st);
        ErrorHandler.showErrorSnackBar(
          context,
          'Operation took too long. Please try again.',
        );
      }
    } catch (e, st) {
      // ❌ Roll back if Firestore failed
      _rollbackJoinStatus(walkId, wasJoined);

      if (mounted) {
        debugPrint('❌ Join/Leave error: $e');
        CrashService.recordError(e, st);

        String message = 'Failed to update join status';
        if (e.toString().contains('PERMISSION_DENIED')) {
          message = 'You don\'t have permission to join this walk.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('Connection')) {
          message = 'Network error. Check your connection and try again.';
        }

        ErrorHandler.showErrorSnackBar(context, message);
      }
    }
  }

  /// Helper to rollback join status on error
  void _rollbackJoinStatus(String walkId, bool previousState) {
    if (!mounted) return;
    setState(() {
      final index = _events.indexWhere((e2) {
        final idA = e2.firestoreId.isNotEmpty ? e2.firestoreId : e2.id;
        return idA == walkId;
      });
      if (index == -1) return;
      _events[index] = _events[index].copyWith(joined: previousState);
    });
  }

  void _toggleInterested(WalkEvent event) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index == -1) return;
      final current = _events[index];
      _events[index] = current.copyWith(interested: !current.interested);
    });
  }

  void _cancelHostedWalk(WalkEvent event) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index == -1) return;
      final current = _events[index];
      final updated = current.copyWith(cancelled: true);
      _events[index] = updated;

      // 🔕 Cancel any reminder for this event
      NotificationService.instance.cancelWalkReminder(updated);
    });
  }

  void _navigateToDetails(WalkEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailsScreen(
          event: event,
          onToggleJoin: (e) => _toggleJoin(e),

          onToggleInterested: _toggleInterested,
          onCancelHosted: _cancelHostedWalk,
        ),
      ),
    );
  }

  void _openCreateWalk() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateWalkScreen(
          onEventCreated: _onEventCreated,
          onCreatedNavigateHome: () {
            Navigator.of(context).pop(); // close create screen
            setState(() {
              _currentTab = 0;
            });
          },
        ),
      ),
    );
  }

  // === NEW: notification bottom sheet (uses stored notifications) ===
  Future<void> _openNotificationsSheet() async {
    final List<AppNotification> notifications =
        await NotificationStorage.getNotifications();

    // ✅ mark all read when opening
    await NotificationStorage.markAllRead();
    await _refreshNotificationsCount();

    // Newest first
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFCFEF9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusCard)),
      ),
      builder: (ctx) {
        // ✅ If nothing stored yet → same placeholder as before
        if (notifications.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(kSpace2, 20, kSpace2, kSpace4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 36,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  'No notifications yet',
                  style:
                      Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ) ??
                      const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You’ll see reminders and new nearby walks here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                SizedBox(height: kSpace2),
              ],
            ),
          );
        }

        // ✅ Real notifications list
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(kSpace2, 12, kSpace2, kSpace3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.notifications, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Notifications',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700) ??
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🔹 Clear button (top-right)
                    TextButton(
                      onPressed: () async {
                        await NotificationStorage.clearNotifications();
                        if (!mounted) return;
                        Navigator.of(context).pop(); // close sheet
                        _openNotificationsSheet(); // reopen with updated list
                      },
                      child: const Text(
                        'Clear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                ...notifications.map(
                  (n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.green,
                    ),
                    title: Text(
                      n.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(n.message),
                    trailing: Text(
                      _formatNotificationTime(n.timestamp),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade600,
                          ) ??
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Profile icon should go directly to Profile
  Future<void> _openProfileQuickSheet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          walksJoined: _walksJoined,
          eventsHosted: _eventsHosted,
          totalKm: _totalKmJoined,
          weeklyWalks: _weeklyWalkCount,
          weeklyKm: _weeklyKm,
          weeklyGoalKm: _weeklyGoalKm,
          streakDays: _streakDays,
          interestedCount: _interestedCount,
          onWeeklyGoalChanged: _updateWeeklyGoal,
        ),
      ),
    );

    // ✅ When user returns from Profile, reload the saved profile (avatar)
    await _loadProfile();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    // Listen to auth changes using provider - must be in build method
    ref.listen(authProvider, (previous, next) {
      next.whenData((user) {
        _listenToWalks();
        _refreshNotificationsCount();
      });
    });

    Widget body;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ✅ Force the phone status-bar area to match our header color
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        // ✅ Match the TOP of your gradient bar: Color(0xFF294630)
        statusBarColor: isDark ? Colors.transparent : const Color(0xFF294630),
        statusBarIconBrightness: Brightness.light, // Android icons
        statusBarBrightness: Brightness.dark, // iOS text/icons
      ),
    );

    switch (_currentTab) {
      case 0:
        body = _buildHomeTab(context);
        break;
      case 1:
        {
          debugPrint(
            'WALKS TAB: events=${_events.length} myWalks=${_myHostedWalks.length} '
            'uid=${FirebaseAuth.instance.currentUser?.uid}',
          );

          body = WalksScreen(
            myWalks: _myHostedWalks,
            nearbyWalks: _nearbyWalks,
            onToggleJoin: (e) => _toggleJoin(e),
            onToggleInterested: _toggleInterested,
            onTapEvent: _navigateToDetails,
            onCancelHosted: _cancelHostedWalk,
            onEventCreated: _onEventCreated,
            onCreatedNavigateHome: () {
              Navigator.pop(context);
            },
            walksJoined: _walksJoined,
            eventsHosted: _eventsHosted,
            totalKm: _totalKmJoined,
            interestedCount: _interestedCount,
            weeklyKm: _weeklyKm,
            weeklyWalks: _weeklyWalkCount,
            streakDays: _streakDays,
            weeklyGoalKm: _weeklyGoalKm,
            userName: _userName,

            hasMoreWalks: _hasMoreWalks,
            isLoadingMore: _isLoadingMore,
            onLoadMore: _loadMoreWalks,
          );

          break;
        }

      case 2:
      default:
        body = const EventsScreen();
        break;
    }

    return Scaffold(
      // ✅ Make status-bar area green in LIGHT mode too (matches Profile/Nearby)
      backgroundColor: isDark ? kDarkBg : const Color(0xFF4F925C),

      body: body,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTab,
        onTap: (index) {
          if (index == 3) {
            // Profile lives on its own screen; navigate to it directly
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  walksJoined: _walksJoined,
                  eventsHosted: _eventsHosted,
                  totalKm: _totalKmJoined,
                  interestedCount: _interestedCount,
                  weeklyKm: _weeklyKm,
                  weeklyWalks: _weeklyWalkCount,
                  streakDays: _streakDays,
                  weeklyGoalKm: _weeklyGoalKm,
                ),
              ),
            );
          } else {
            setState(() {
              _currentTab = index;
            });
          }
        },
        onTabSpecificAction: (index) {
          // Trigger specific actions for tabs
          if (index == 0) {
            _loadUserName();
          }
        },
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // ===== HEADER =====
        if (isDark)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          color: Colors.white.withAlpha((0.08 * 255).round()),
                        ),
                        child: const Icon(
                          Icons.directions_walk,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Yalla Nemshi',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ) ??
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                      ),
                    ],
                  ),

                  // Right: notif + profile
                  Row(
                    children: [
                      Semantics(
                        label: _unreadNotifCount > 0
                            ? '$_unreadNotifCount unread notification${_unreadNotifCount == 1 ? '' : 's'}'
                            : 'Notifications',
                        button: true,
                        child: GestureDetector(
                          onTap: _openNotificationsSheet,
                          child: Padding(
                            padding: const EdgeInsets.all(
                              8,
                            ), // ✅ Ensures 48x48 touch target
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withAlpha(
                                      (0.08 * 255).round(),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                if (_unreadNotifCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red,
                                      ),
                                      child: Text(
                                        _unreadNotifCount > 99
                                            ? '99+'
                                            : '$_unreadNotifCount',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.labelSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ) ??
                                            const TextStyle(
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Semantics(
                        label: 'Profile',
                        button: true,
                        child: GestureDetector(
                          onTap: _openProfileQuickSheet,
                          child: Padding(
                            padding: const EdgeInsets.all(
                              8,
                            ), // ✅ Ensures 48x48 touch target
                            child: _HeaderAvatar(
                              profile: _profile,
                              size: 32,
                              isDark: true,
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
                        Text(
                          'Yalla Nemshi',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ) ??
                              const TextStyle(
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
                          onTap: _openNotificationsSheet,
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
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              if (_unreadNotifCount > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red,
                                    ),
                                    child: Text(
                                      _unreadNotifCount > 99
                                          ? '99+'
                                          : '$_unreadNotifCount',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.labelSmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ) ??
                                          const TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _openProfileQuickSheet,
                          child: _HeaderAvatar(
                            profile: _profile,
                            size: 32,
                            isDark: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ===== MAIN CONTENT CARD (ROUNDED TOP, WITH OPTIONAL BG IMAGE) =====
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? kDarkBg : const Color(0xFFF7F3EA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(kRadiusCard),
                topRight: Radius.circular(kRadiusCard),
              ),
            ),

            // overlay so text stays readable on top of the photo
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(kRadiusCard),
                  topRight: Radius.circular(kRadiusCard),
                ),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF071B26), // top
                          Color(0xFF041016), // bottom
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF7F3EA), Color(0xFFEEE6DA)],
                      ),
              ),

              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        kSpace2,
                        12,
                        kSpace2,
                        kSpace3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Big inner card: greeting + calendar + "Your walks"
                          Card(
                            color: isDark ? kDarkSurface : kLightSurface,
                            elevation: isDark
                                ? kCardElevationDark
                                : kCardElevationLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kRadiusCard),
                              side: BorderSide(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withAlpha(
                                      (kCardBorderAlpha * 255).round(),
                                    ),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                kSpace2,
                                kSpace2,
                                kSpace2,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_greetingForTime()}, $_userName',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? kTextPrimary
                                                        : const Color(
                                                            0xFF14532D,
                                                          ),
                                                  ),
                                            ),

                                            const SizedBox(height: 4),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _StepsRing(
                                        steps: _sessionSteps,
                                        goal: 10000,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: kSpace2),

                                  // Ready to walk + buttons
                                  Text(
                                    'Ready to walk?',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: kSpace1),
                                  Text(
                                    'Start a walk now or join others nearby. Your steps, your pace.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  SizedBox(height: kSpace2),
                                  SizedBox(
                                    width: double.infinity,
                                    height: kBtnHeight,
                                    child: FilledButton.icon(
                                      onPressed: _openCreateWalk,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: kMintBright,
                                        foregroundColor: kOnMint,
                                        padding: kBtnPadding,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            kRadiusPill,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.directions_walk_outlined,
                                      ),
                                      label: const Text('Start walk'),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // ===== Calendar (week swipe + no dots + fixed sizing) =====
                                  TableCalendar(
                                    firstDay: DateTime(2020, 1, 1),
                                    lastDay: DateTime(2035, 12, 31),
                                    focusedDay: _focusedDay,
                                    calendarFormat: CalendarFormat.week,
                                    headerVisible: false,
                                    daysOfWeekVisible: false,
                                    rowHeight:
                                        (MediaQuery.of(
                                              context,
                                            ).textScaler.scale(1.0) >
                                            1.15)
                                        ? 72
                                        : 60,

                                    // ✅ smoother swipe between weeks
                                    pageAnimationEnabled: true,
                                    pageAnimationDuration: const Duration(
                                      milliseconds: 220,
                                    ),
                                    pageAnimationCurve: Curves.easeOutCubic,

                                    // ✅ IMPORTANT: keep outside days visible so the week row is consistent
                                    calendarStyle: const CalendarStyle(
                                      isTodayHighlighted: false,
                                      outsideDaysVisible: true,
                                    ),

                                    onPageChanged: (focusedDay) {
                                      setState(() => _focusedDay = focusedDay);
                                    },

                                    selectedDayPredicate: (day) =>
                                        isSameDay(_selectedDay, day),

                                    calendarBuilders: CalendarBuilders(
                                      defaultBuilder:
                                          (context, day, focusedDay) {
                                            return _buildCalendarDayCell(
                                              day,
                                              isDark,
                                              forceSelected: false,
                                            );
                                          },
                                      selectedBuilder:
                                          (context, day, focusedDay) {
                                            return _buildCalendarDayCell(
                                              day,
                                              isDark,
                                              forceSelected: true,
                                            );
                                          },
                                      todayBuilder: (context, day, focusedDay) {
                                        return _buildCalendarDayCell(
                                          day,
                                          isDark,
                                          forceSelected: false,
                                        );
                                      },

                                      // ✅ FIX: outside days were not using your pill builder
                                      outsideBuilder:
                                          (context, day, focusedDay) {
                                            return _buildCalendarDayCell(
                                              day,
                                              isDark,
                                              forceSelected: false,
                                            );
                                          },

                                      // ✅ (optional safety) disabled days also use the same pill rendering
                                      disabledBuilder:
                                          (context, day, focusedDay) {
                                            return _buildCalendarDayCell(
                                              day,
                                              isDark,
                                              forceSelected: false,
                                            );
                                          },
                                    ),

                                    onDaySelected: (selectedDay, focusedDay) {
                                      setState(() {
                                        _selectedDay = selectedDay;
                                        _focusedDay = focusedDay;
                                      });
                                    },
                                  ),

                                  // ===== End Calendar =====
                                  const SizedBox(height: 20),

                                  // Walks for selected date
                                  Text(
                                    DateFormat(
                                      'MMMM d, y',
                                    ).format(_selectedDay),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: kSpace1),
                                  if (_eventsForDay(_selectedDay).isEmpty)
                                    Text(
                                      'No walks scheduled for this date.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                    )
                                  else
                                    Column(
                                      children: _eventsForDay(_selectedDay)
                                          .map(
                                            (e) => _WalkCard(
                                              event: e,
                                              onTap: () =>
                                                  _navigateToDetails(e),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: kSpace2),

                          // ===== WEEKLY SUMMARY =====
                          Text(
                            'This week',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: kSpace1),
                          _WeeklySummaryCard(
                            walks: _weeklyWalkCount,
                            kmSoFar: _weeklyKm,
                            kmGoal: _weeklyGoalKm,
                            streakDays: _streakDays,
                          ),
                          SizedBox(height: kSpace2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
//end of homescreeninstant
// ===== Smaller components =====

class _WeeklySummaryCard extends StatelessWidget {
  final int walks;
  final double kmSoFar;
  final double kmGoal;
  final int streakDays;

  const _WeeklySummaryCard({
    required this.walks,
    required this.kmSoFar,
    required this.kmGoal,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final progress = (kmGoal <= 0)
        ? 0.0
        : (kmSoFar / kmGoal).clamp(0.0, 1.0).toDouble();

    final titleColor = isDark
        ? kTextPrimary
        : (theme.textTheme.titleMedium?.color);
    final bodyColor = isDark
        ? kTextSecondary
        : (theme.textTheme.bodySmall?.color);

    String motivationText(double p) {
      if (kmGoal <= 0) {
        return 'Set a weekly goal in Settings to start tracking.';
      }
      if (p <= 0.01) return 'Let’s get the first steps in 💪';
      if (p < 0.25) return 'Nice start — keep the momentum going!';
      if (p < 0.50) return 'You’re building a habit — great progress!';
      if (p < 0.75) return 'More than halfway — you’ve got this!';
      if (p < 1.00) return 'Almost there — one more push!';
      return 'Goal reached 🎉 Amazing work this week!';
    }

    final percent = (progress * 100).round();

    return Card(
      color: isDark ? kDarkSurface : kLightSurface,
      elevation: isDark ? kCardElevationDark : kCardElevationLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withAlpha(
            (kCardBorderAlpha * 255).round(),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(kSpace2, 12, kSpace2, kSpace3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top line: stats + %
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$walks walk${walks == 1 ? '' : 's'} • '
                    '${kmSoFar.toStringAsFixed(1)} / ${kmGoal.toStringAsFixed(1)} km',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? kDarkSurface2
                        : Colors.black.withAlpha((0.06 * 255).round()),
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Text(
                    kmGoal <= 0 ? '--' : '$percent%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? kTextPrimary : const Color(0xFF14532D),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // progress bar
            LayoutBuilder(
              builder: (context, c) {
                final trackColor = isDark ? kDarkSurface2 : Colors.black12;
                final fillColor = isDark
                    ? kMintBright
                    : const Color(0xFF14532D);

                return Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        width: c.maxWidth * (kmGoal <= 0 ? 0.0 : progress),
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(kRadiusPill),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: isDark ? 0.10 : 0.08,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  kRadiusPill,
                                ),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.white, Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // Motivational microcopy + streak
            Text(
              motivationText(progress),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? kTextPrimary : const Color(0xFF14532D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              streakDays > 0
                  ? 'Streak: $streakDays day${streakDays == 1 ? '' : 's'} in a row'
                  : 'Start a walk today to begin your streak!',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkCard extends StatelessWidget {
  final WalkEvent event;
  final VoidCallback onTap;

  const _WalkCard({required this.event, required this.onTap});

  String _formatDateTime(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy • $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? kDarkSurface
          : kLightSurface,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: Theme.of(context).brightness == Brightness.dark
          ? kCardElevationDark
          : kCardElevationLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusControl),
        side: BorderSide(
          color:
              (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black)
                  .withAlpha((kCardBorderAlpha * 255).round()),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (event.isRecurring && !event.isRecurringTemplate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Recurring',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(_formatDateTime(event.dateTime)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _StepsRing extends StatelessWidget {
  final int steps;
  final int goal;
  final bool isDark;

  const _StepsRing({
    required this.steps,
    required this.goal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final double progress = (goal <= 0)
        ? 0.0
        : (steps / goal).clamp(0.0, 1.0).toDouble();

    const double size = 120;
    const double stroke = 14;

    // Animate the ring smoothly when steps change
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        // Base ring color at full progress
        final Color base = isDark ? kMintBright : const Color(0xFF14532D);

        // Very light color at 0 progress (so the start is almost white)
        final Color veryLight = isDark
            ? Colors.white.withAlpha((0.16 * 255).round())
            : const Color(0xFFE8F1EA); // ✅ light green tint (not white)

        // End color gets darker as progress increases
        final Color endColor = Color.lerp(veryLight, base, animatedProgress)!;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(size, size),
                painter: _GradientRingPainter(
                  progress: animatedProgress,
                  strokeWidth: stroke,
                  trackColor: isDark
                      ? Colors.white.withAlpha((0.10 * 255).round())
                      : const Color(
                          0xFFD7E2D7,
                        ), // ✅ slightly darker track so ring feels consistent
                  // ✅ start ALWAYS very light
                  startColor: veryLight,
                  // ✅ end darkens with progress
                  endColor: endColor,
                ),
              ),

              // Text in the middle
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$steps',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? kTextPrimary : Colors.black87,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Steps',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? kTextSecondary : Colors.black54,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  final double progress; // 0..1
  final double strokeWidth;
  final Color trackColor;
  final Color startColor;
  final Color endColor;

  const _GradientRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);

    final inset = strokeWidth / 2;
    final ringRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    const startAngle = -math.pi / 2; // top

    // Slightly shorten at 100% so rounded caps don't overlap visually
    final safeP = (p >= 1.0) ? 0.999 : p;
    final sweepAngle = 2 * math.pi * safeP;

    // Track (full circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(ringRect, 0, 2 * math.pi, false, trackPaint);

    if (p <= 0) return;

    // Gradient on the progress arc
    final gradient = SweepGradient(
      // ✅ end with startColor again → seam becomes light (no dark tick at top)
      colors: [startColor, endColor, startColor],
      stops: const [0.0, 0.85, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(ringRect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}
class _HeaderAvatar extends StatelessWidget {
  final UserProfile? profile;
  final double size;
  final bool isDark;

  const _HeaderAvatar({
    required this.profile,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;

    ImageProvider? img;

// 1) Base64 avatar (web testing)
final base64Str = p?.profileImageBase64;
if (base64Str != null && base64Str.trim().isNotEmpty) {
  try {
    final bytes = base64Decode(base64Str);
    img = MemoryImage(bytes);
  } catch (_) {
    // ignore
  }
}

// 2) Local file avatar path (mobile only)
if (img == null && !kIsWeb) {
  final path = p?.profileImagePath;
  if (path != null && path.trim().isNotEmpty) {
    final f = File(path);
    if (f.existsSync()) {
      img = FileImage(f);
    }
  }
}


    // 3) Fallback to Firebase photoURL
    if (img == null) {
      final url = FirebaseAuth.instance.currentUser?.photoURL;
      if (url != null && url.trim().isNotEmpty) {
        img = NetworkImage(url);
      }
    }

    // 4) Final fallback: icon
    if (img == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        ),
        child: Icon(
          Icons.person,
          size: size * 0.55,
          color: isDark ? Colors.white : Colors.black87,
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
      backgroundImage: img,
    );
  }
}
