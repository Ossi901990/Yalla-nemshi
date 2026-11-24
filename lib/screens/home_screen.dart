// lib/screens/home_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/walk_event.dart';
import '../services/notification_service.dart';
import '../services/app_preferences.dart';
import '../services/crash_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/offline_service.dart';
import '../services/walk_history_service.dart';
import '../services/walk_control_service.dart';
import '../services/gps_tracking_service.dart';
import '../services/user_stats_service.dart';
import '../utils/error_handler.dart';

import 'create_walk_screen.dart';
import 'event_details_screen.dart';
import 'profile_screen.dart';
import 'walks_screen.dart';
import 'events_screen.dart';
import 'walk_search_screen.dart';
import 'active_walk_screen.dart';
import '../services/notification_storage.dart';
import '../screens/notifications_screen.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_sender.dart';
import 'home/home_tab.dart';
import '../theme/app_palette.dart';
import '../widgets/ui/floating_nav_bar.dart';

// ===== Dark Theme (Neo/Night Forest) palette =====
const kDarkBg = Color(0xFF071B26); // primary background
const kDarkSurface = Color(0xFF0C2430); // cards / sheets
const kDarkSurface2 = Color(0xFF0E242E); // nav / secondary surfaces

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
  static const Duration _hostStartEarlyWindow = Duration(minutes: 10);
  static const Duration _hostStartGraceWindow = Duration(minutes: 15);

  /// Poll walks periodically (every 30s) instead of real-time listening
  /// This reduces Firestore read costs and battery drain while keeping the feed fresh
  /// Real-time updates are only needed for active walks, not discovery
  void _listenToWalks() {
    _walksSub?.cancel();
    _walksPollingTimer?.cancel();

    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('Skipping walk polling: no authenticated user');
      return;
    }

    // Initial load
    _fetchWalks();

    // Set up periodic polling (every 30 seconds)
    _walksPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchWalks();
      }
    });
  }

  /// Fetch walks using a one-time query (not a real-time listener)
  Future<void> _fetchWalks() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('Skipping walk fetch: no authenticated user');
        _walksPollingTimer?.cancel();
        return;
      }
      final userCity = await AppPreferences.getUserCity();
      final userCityNormalized =
          await AppPreferences.getUserCityNormalized() ??
          (userCity != null ? AppPreferences.normalizeCity(userCity) : null);
      if (!mounted) return;

      final nowTimestamp = Timestamp.fromDate(DateTime.now());

      // Build query: filter by city if user has one set
      // Only open walks are discoverable; private walks the user hosts or
      // joined are fetched separately below (security rules enforce this).
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('walks')
          .where('visibility', isEqualTo: 'open');

      if ((userCityNormalized != null && userCityNormalized.isNotEmpty) ||
          (userCity != null && userCity.isNotEmpty)) {
        debugPrint('Polling walks by city (including cityless): $userCity');
        Filter? cityFilter;
        if (userCityNormalized != null && userCityNormalized.isNotEmpty) {
          cityFilter = Filter('cityNormalized', isEqualTo: userCityNormalized);
        }
        if (userCity != null && userCity.isNotEmpty) {
          final rawFilter = Filter('city', isEqualTo: userCity);
          cityFilter = cityFilter != null
              ? Filter.or(cityFilter, rawFilter)
              : rawFilter;
        }
        final nullCity = Filter('city', isNull: true);
        cityFilter = cityFilter != null
            ? Filter.or(cityFilter, nullCity)
            : nullCity;
        query = query.where(cityFilter);
      } else {
        debugPrint('⚠️ No user city set; polling all walks');
      }

      // Upcoming walks query (future dateTime)
      final upcomingQuery = query
          .where('cancelled', isEqualTo: false)
          .where('dateTime', isGreaterThan: nowTimestamp)
          .orderBy('dateTime')
          .orderBy('createdAt', descending: true)
          .limit(_walksPerPage);

      // Active walks query (keep visible even if dateTime is in the past)
      final activeQuery = query
          .where('cancelled', isEqualTo: false)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(_walksPerPage);

      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // Always include the user's own walks regardless of city filter
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> futures = [
        upcomingQuery.get(),
        activeQuery.get(),
      ];

      Query<Map<String, dynamic>>? ownHostQuery;
      Query<Map<String, dynamic>>? ownJoinedQuery;
      if (currentUid != null) {
        final ownBase = FirebaseFirestore.instance
            .collection('walks')
            .where('cancelled', isEqualTo: false);

        ownHostQuery = ownBase
            .where('hostUid', isEqualTo: currentUid)
            .limit(_walksPerPage);
        ownJoinedQuery = ownBase
            .where('joinedUserUids', arrayContains: currentUid)
            .limit(_walksPerPage);

        futures.add(ownHostQuery.get());
        futures.add(ownJoinedQuery.get());
      }

      final results = await Future.wait(futures);
      final upcomingSnap = results[0];
      final activeSnap = results[1];
      final ownHostSnap = results.length > 2 ? results[2] : null;
      final ownJoinedSnap = results.length > 3 ? results[3] : null;

      final docMap = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in upcomingSnap.docs) {
        docMap[doc.id] = doc;
      }
      for (final doc in activeSnap.docs) {
        docMap[doc.id] = doc;
      }
      if (ownHostSnap != null) {
        for (final doc in ownHostSnap.docs) {
          docMap[doc.id] = doc;
        }
      }
      if (ownJoinedSnap != null) {
        for (final doc in ownJoinedSnap.docs) {
          docMap[doc.id] = doc;
        }
      }
      final combinedDocs = docMap.values.toList();

      if (!mounted) return;

      if (upcomingSnap.docs.isNotEmpty) {
        _lastDocument = upcomingSnap.docs.last;
        _hasMoreWalks = upcomingSnap.docs.length >= _walksPerPage;
      } else {
        _lastDocument = null;
        _hasMoreWalks = false;
      }

      final List<WalkEvent> loaded = _parseWalkDocs(combinedDocs, currentUid);
      final List<WalkEvent> merged = _collapseRecurringWalks(loaded);

      setState(() {
        _events
          ..clear()
          ..addAll(merged);
      });

      _refreshHostedCountdown();
      _refreshParticipantCountdown();

      OfflineService.instance.cacheWalks(merged);

      final fromCache =
          upcomingSnap.metadata.isFromCache &&
          activeSnap.metadata.isFromCache &&
          (ownHostSnap?.metadata.isFromCache ?? true) &&
          (ownJoinedSnap?.metadata.isFromCache ?? true);

      _logHomeFeedSummary(
        source: 'polling',
        totalDocs: combinedDocs.length,
        parsedCount: loaded.length,
        keptCount: merged.length,
        fromCache: fromCache,
      );
    } catch (e, st) {
      debugPrint('❌ Error fetching walks: $e');
      CrashService.recordError(e, st);
    }
  }

  void _openWalkSearch() {
    Navigator.of(context).pushNamed(WalkSearchScreen.routeName);
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
      final userCityNormalized =
          await AppPreferences.getUserCityNormalized() ??
          (userCity != null ? AppPreferences.normalizeCity(userCity) : null);
      final nowTimestamp = Timestamp.fromDate(DateTime.now());

      Query<Map<String, dynamic>> baseQuery = FirebaseFirestore.instance
          .collection('walks')
          .where('visibility', isEqualTo: 'open')
          .where('cancelled', isEqualTo: false);

      if ((userCityNormalized != null && userCityNormalized.isNotEmpty) ||
          (userCity != null && userCity.isNotEmpty)) {
        Filter? cityFilter;
        if (userCityNormalized != null && userCityNormalized.isNotEmpty) {
          cityFilter = Filter('cityNormalized', isEqualTo: userCityNormalized);
        }
        if (userCity != null && userCity.isNotEmpty) {
          final rawFilter = Filter('city', isEqualTo: userCity);
          cityFilter = cityFilter != null
              ? Filter.or(cityFilter, rawFilter)
              : rawFilter;
        }
        final nullCity = Filter('city', isNull: true);
        cityFilter = cityFilter != null
            ? Filter.or(cityFilter, nullCity)
            : nullCity;
        baseQuery = baseQuery.where(cityFilter);
      }

      final upcomingQuery = baseQuery
          .where('dateTime', isGreaterThan: nowTimestamp)
          .orderBy('dateTime')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_walksPerPage);

      final activeQuery = baseQuery
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(_walksPerPage);

      final results = await Future.wait([
        upcomingQuery.get(),
        activeQuery.get(),
      ]).timeout(const Duration(seconds: 20));
      final upcomingSnap = results[0];
      final activeSnap = results[1];

      final docMap = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in upcomingSnap.docs) {
        docMap[doc.id] = doc;
      }
      for (final doc in activeSnap.docs) {
        docMap[doc.id] = doc;
      }
      final combinedDocs = docMap.values.toList();

      if (!mounted) return;

      if (upcomingSnap.docs.isEmpty && activeSnap.docs.isEmpty) {
        setState(() {
          _hasMoreWalks = false;
          _isLoadingMore = false;
        });
        return;
      }

      if (upcomingSnap.docs.isNotEmpty) {
        _lastDocument = upcomingSnap.docs.last;
        _hasMoreWalks = upcomingSnap.docs.length >= _walksPerPage;
      } else {
        _hasMoreWalks = false;
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final List<WalkEvent> newWalks = _parseWalkDocs(combinedDocs, currentUid);
      final existingIds = _events.map((e) => e.firestoreId).toSet();
      final List<WalkEvent> uniqueWalks = newWalks
          .where((w) => !existingIds.contains(w.firestoreId))
          .toList();

      _logHomeFeedSummary(
        source: 'load_more',
        totalDocs: combinedDocs.length,
        parsedCount: newWalks.length,
        keptCount: uniqueWalks.length,
        fromCache:
            upcomingSnap.metadata.isFromCache &&
            activeSnap.metadata.isFromCache,
      );

      setState(() {
        _events.addAll(uniqueWalks);
        _isLoadingMore = false;
      });

      _refreshHostedCountdown();
      _refreshParticipantCountdown();

      OfflineService.instance.cacheWalks(_events);

      debugPrint(
        '📄 Loaded ${uniqueWalks.length} more walks. Total: ${_events.length}',
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

  List<WalkEvent> _parseWalkDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? currentUid,
  ) {
    final results = <WalkEvent>[];
    for (final doc in docs) {
      final walk = _parseWalkDoc(
        doc,
        currentUid,
        isFromCache: doc.metadata.isFromCache,
      );
      if (walk != null) {
        results.add(walk);
      }
    }
    return results;
  }

  WalkEvent? _parseWalkDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String? currentUid, {
    bool isFromCache = false,
  }) {
    try {
      final raw = doc.data();
      if (raw == null) {
        _debugWalkDrop(
          'snapshot data null',
          id: doc.id,
          isFromCache: isFromCache,
        );
        return null;
      }

      final data = Map<String, dynamic>.from(raw);
      if (data['dateTime'] == null) {
        _debugWalkDrop(
          'missing required fields: dateTime',
          id: doc.id,
          data: data,
          isFromCache: isFromCache,
        );
        return null;
      }
      data['firestoreId'] = doc.id;
      data['id'] ??= doc.id;

      final hostUid = data['hostUid'] as String?;
      data['isOwner'] = currentUid != null && hostUid == currentUid;

      final joinedUids =
          (data['joinedUids'] as List?)?.whereType<String>().toList() ?? [];
      data['joined'] = currentUid != null && joinedUids.contains(currentUid);

      final walk = WalkEvent.fromMap(data);
      if (walk.cancelled) {
        _debugWalkDrop(
          'status=cancelled',
          id: doc.id,
          data: data,
          parsed: walk,
          isFromCache: isFromCache,
        );
        return null;
      }
      if (walk.status == 'ended') {
        _debugWalkDrop(
          'status=ended',
          id: doc.id,
          data: data,
          parsed: walk,
          isFromCache: isFromCache,
        );
        return null;
      }
      if (walk.status == 'completed') {
        _debugWalkDrop(
          'status=completed',
          id: doc.id,
          data: data,
          parsed: walk,
          isFromCache: isFromCache,
        );
        return null;
      }
      if (walk.visibility == 'private' && !walk.isOwner && !walk.joined) {
        _debugWalkDrop(
          'visibility=private for non-owner who hasn\'t joined',
          id: doc.id,
          data: data,
          parsed: walk,
          isFromCache: isFromCache,
        );
        return null;
      }

      return walk;
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to parse walk ${doc.id}: $error');
      _debugWalkDrop(
        'parse failure: $error',
        id: doc.id,
        data: doc.data(),
        isFromCache: isFromCache,
      );
      CrashService.recordError(
        error,
        stackTrace,
        reason: 'HomeScreen.walkParse.${doc.id}',
      );
      return null;
    }
  }

  List<WalkEvent> _collapseRecurringWalks(List<WalkEvent> loaded) {
    final now = DateTime.now();
    final Map<String, List<WalkEvent>> series = {};
    final List<WalkEvent> singles = [];

    for (final event in loaded) {
      if (event.isRecurringTemplate) {
        _debugWalkDrop(
          'recurring template suppressed',
          id: event.id,
          parsed: event,
        );
        continue;
      }

      if (event.isRecurring && event.recurringGroupId != null) {
        series.putIfAbsent(event.recurringGroupId!, () => []).add(event);
      } else {
        singles.add(event);
      }
    }

    final merged = [...singles];

    for (final group in series.values) {
      WalkEvent? candidate;
      for (final event in group) {
        final isFuture = event.dateTime.isAfter(now);
        if (candidate == null) {
          candidate = event;
          continue;
        }

        final candidateFuture = candidate.dateTime.isAfter(now);
        final betterFuture = isFuture && !candidateFuture;
        final earlierSameBucket =
            (isFuture == candidateFuture) &&
            event.dateTime.isBefore(candidate.dateTime);

        if (betterFuture || earlierSameBucket) {
          candidate = event;
        }
      }

      if (candidate != null) {
        for (final event in group) {
          if (event.id == candidate.id) continue;
          final reason = event.dateTime.isAfter(now)
              ? 'recurring collapse kept ${candidate.id} (group ${event.recurringGroupId})'
              : 'recurring collapse dropped past instance (kept ${candidate.id})';
          _debugWalkDrop(reason, id: event.id, parsed: event);
        }
        merged.add(candidate);
      }
    }

    merged.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return merged;
  }

  /// All events (hosted by user + nearby).
  final List<WalkEvent> _events = [];
  bool _isOffline = false;
  int _pendingActions = 0;

  late final VoidCallback _offlineListener;
  late final VoidCallback _pendingListener;

  // Pagination state
  static const int _walksPerPage = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreWalks = true;
  bool _isLoadingMore = false;

  // Loaded from saved profile (falls back to "Walker")
  String _userName = 'Walker';

  // --- Step counter (Android, session-based for now) ---
  StreamSubscription<QuerySnapshot>? _walksSub;
  Timer? _walksPollingTimer; // For periodic polling instead of real-time

  int _unreadNotifCount = 0;

  Timer? _hostedCountdownTimer;
  WalkEvent? _nextHostedWalk;
  bool _isStartingHostedWalk = false;
  Timer? _participantCountdownTimer;
  WalkEvent? _nextParticipantWalk;
  bool _isConfirmingParticipant = false;

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

  WalkEvent? _computeNextHostedWalk() {
    if (_myHostedWalks.isEmpty) return null;

    final now = DateTime.now();

    // Filter: only non-cancelled walks with upcoming or active status
    final eligible = _myHostedWalks
        .where(
          (walk) =>
              !walk.cancelled &&
              (walk.status == 'scheduled' || walk.status == 'active') &&
              walk.dateTime.isAfter(now.subtract(const Duration(minutes: 15))),
        )
        .toList();

    if (eligible.isEmpty) return null;

    // Sort by dateTime ascending to find the nearest/soonest walk
    eligible.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return eligible.first;
  }

  WalkEvent? _computeNextParticipantWalk() {
    final now = DateTime.now();
    final eligible = _events
        .where(
          (walk) =>
              !walk.cancelled &&
              !walk.isOwner &&
              walk.joined &&
              (walk.status == 'scheduled' || walk.status == 'active') &&
              walk.dateTime.isAfter(now.subtract(const Duration(minutes: 15))),
        )
        .toList();

    if (eligible.isEmpty) return null;

    eligible.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return eligible.first;
  }

  void _refreshHostedCountdown() {
    _hostedCountdownTimer?.cancel();
    final next = _computeNextHostedWalk();

    if (!mounted) {
      _nextHostedWalk = next;
      return;
    }

    if (next == null) {
      setState(() {
        _nextHostedWalk = null;
      });
      return;
    }

    void updateRemaining() {
      if (!mounted) return;
      setState(() {
        _nextHostedWalk = next;
      });
    }

    updateRemaining();

    if (next.status == 'scheduled') {
      _hostedCountdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => updateRemaining(),
      );
    }
  }

  void _refreshParticipantCountdown() {
    _participantCountdownTimer?.cancel();
    final next = _computeNextParticipantWalk();

    if (!mounted) {
      _nextParticipantWalk = next;
      return;
    }

    if (next == null) {
      setState(() {
        _nextParticipantWalk = null;
      });
      return;
    }

    void updateRemaining() {
      if (!mounted) return;
      setState(() {
        _nextParticipantWalk = next;
      });
    }

    updateRemaining();

    if (next.status == 'scheduled') {
      _participantCountdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => updateRemaining(),
      );
    }
  }

  Future<void> _handleParticipantConfirm(WalkEvent walk) async {
    if (_isConfirmingParticipant) return;
    setState(() {
      _isConfirmingParticipant = true;
    });
    try {
      await WalkHistoryService.instance.confirmParticipation(walk.firestoreId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Confirmation sent')));
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'HomeScreen.confirmParticipation',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to confirm participation')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingParticipant = false;
        });
      }
    }
  }

  bool _canHostStartWalk(WalkEvent walk) {
    if (!walk.isOwner || walk.status != 'scheduled') {
      return false;
    }
    final now = DateTime.now();
    final earliest = walk.dateTime.subtract(_hostStartEarlyWindow);
    final latest = walk.dateTime.add(_hostStartGraceWindow);
    return !now.isBefore(earliest) && !now.isAfter(latest);
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
  // --- Step counter setup (Android only for now) ---

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;

    // DEBUG: Print current user info
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('🆔 HOME SCREEN - Current User ID: ${user?.uid}');
    debugPrint('🆔 HOME SCREEN - Current User Name: ${user?.displayName}');

    _offlineListener = () {
      if (!mounted) return;
      setState(() {
        _isOffline = OfflineService.instance.isOffline.value;
      });
    };

    _pendingListener = () {
      if (!mounted) return;
      setState(() {
        _pendingActions = OfflineService.instance.pendingActionCount.value;
      });
    };

    OfflineService.instance.isOffline.addListener(_offlineListener);
    OfflineService.instance.pendingActionCount.addListener(_pendingListener);
    _isOffline = OfflineService.instance.isOffline.value;
    _pendingActions = OfflineService.instance.pendingActionCount.value;

    _loadUserName();
    _loadWeeklyGoal();
    _loadCachedWalks();
    _listenToWalks();

    // 🔹 Sync user profile to Firestore (if missing)
    FirestoreSyncService.syncCurrentUser();
  }

  @override
  void dispose() {
    _participantCountdownTimer?.cancel();
    _walksSub?.cancel();
    _walksPollingTimer?.cancel(); // Stop periodic polling
    _hostedCountdownTimer?.cancel();

    OfflineService.instance.isOffline.removeListener(_offlineListener);
    OfflineService.instance.pendingActionCount.removeListener(_pendingListener);

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

  Future<void> _loadCachedWalks() async {
    _refreshParticipantCountdown();
    try {
      final cached = await OfflineService.instance.loadCachedWalks();
      if (!mounted || cached.isEmpty) return;
      if (_events.isEmpty) {
        setState(() {
          _events.addAll(cached);
        });
      }
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'HomeScreen.loadCachedWalks');
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

  // --- Actions ---

  void _onEventCreated(WalkEvent newEvent) {
    setState(() {
      _events.add(newEvent);
    });

    _refreshHostedCountdown();

    // 🔔 Schedule reminder for the walk you just created (host)
    NotificationService.instance.scheduleWalkReminder(newEvent);
  }

  void _logHomeFeedSummary({
    required String source,
    required int totalDocs,
    required int parsedCount,
    required int keptCount,
    bool fromCache = false,
  }) {
    if (!kDebugMode) {
      return;
    }
    final int dropped = totalDocs - keptCount;
    final int safeDropped = dropped < 0 ? 0 : dropped;
    debugPrint(
      '📊 HOME FEED [$source] cache=$fromCache total=$totalDocs parsed=$parsedCount kept=$keptCount dropped=$safeDropped',
    );
  }

  void _debugWalkDrop(
    String reason, {
    required String id,
    Map<String, dynamic>? data,
    WalkEvent? parsed,
    bool? isFromCache,
  }) {
    if (!kDebugMode) {
      return;
    }

    DateTime? normalizeDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    final dynamic rawDateTime = parsed?.dateTime ?? data?['dateTime'];
    final DateTime? dateTime = normalizeDateTime(rawDateTime);
    final buffer = StringBuffer()
      ..writeln(
        '🕵️ WALK DROP id=$id reason=$reason cache=${isFromCache ?? false}',
      )
      ..writeln(
        '  dateTime=${dateTime ?? data?['dateTime']} status=${parsed?.status ?? data?['status']} visibility=${parsed?.visibility ?? data?['visibility']}',
      )
      ..writeln(
        '  hostUid=${parsed?.hostUid ?? data?['hostUid']} city=${parsed?.city ?? data?['city']} createdAt=${parsed?.createdAt ?? data?['createdAt']} updatedAt=${parsed?.updatedAt ?? data?['updatedAt']}',
      )
      ..writeln(
        '  recurringGroupId=${parsed?.recurringGroupId ?? data?['recurringGroupId']} isRecurring=${parsed?.isRecurring ?? data?['isRecurring']} template=${parsed?.isRecurringTemplate ?? data?['isRecurringTemplate']}',
      )
      ..writeln(
        '  distanceKm=${parsed?.distanceKm ?? data?['distanceKm']} meetingPlace=${parsed?.meetingPlaceName ?? data?['meetingPlaceName']}',
      );

    debugPrint(buffer.toString());
  }

  Future<void> _toggleJoin(WalkEvent event) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(context, 'Please log in to join walks.');
      return;
    }

    if (!event.joined && event.status == 'active') {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(
        context,
        'This walk is already active. Ask the host to invite you directly.',
      );
      return;
    }

    // ✅ Always use Firestore doc id
    final walkId = event.firestoreId.isNotEmpty ? event.firestoreId : event.id;
    final docRef = FirebaseFirestore.instance.collection('walks').doc(walkId);

    final bool wasJoined = event.joined;
    final bool willJoin = !wasJoined;
    final bool leavingActive = !willJoin && event.status == 'active';

    // Get current user info for optimistic update
    final currentUser = FirebaseAuth.instance.currentUser;
    final userPhotoUrl = currentUser?.photoURL;
    final rawDisplayName = currentUser?.displayName?.trim();
    final userDisplayName =
        (rawDisplayName != null && rawDisplayName.isNotEmpty)
        ? rawDisplayName
        : 'User ${uid.substring(0, 6)}';

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
      final newJoinedNames = List<String>.from(currentEvent.joinedUserNames);
      final newJoinedPhotos = List<String>.from(
        currentEvent.joinedUserPhotoUrls,
      );
      final newParticipantStates = Map<String, String>.from(
        currentEvent.participantStates,
      );

      if (willJoin) {
        if (!newJoinedUids.contains(uid)) {
          newJoinedUids.add(uid);
        }
        if (!newJoinedNames.contains(userDisplayName)) {
          newJoinedNames.add(userDisplayName);
        }
        if (userPhotoUrl != null && !newJoinedPhotos.contains(userPhotoUrl)) {
          newJoinedPhotos.add(userPhotoUrl);
        }
        newParticipantStates[uid] = 'joined';
      } else {
        newJoinedUids.remove(uid);
        newJoinedNames.remove(userDisplayName);
        if (userPhotoUrl != null) {
          newJoinedPhotos.remove(userPhotoUrl);
        }
        newParticipantStates[uid] = 'left';
      }

      _events[index] = currentEvent.copyWith(
        joined: willJoin,
        joinedUserUids: newJoinedUids,
        joinedUserNames: newJoinedNames,
        joinedUserPhotoUrls: newJoinedPhotos,
        joinedCount: newJoinedUids.length,
        participantStates: newParticipantStates,
      );
    });

    try {
      // ✅ Get current user info for participant data
      final currentUser = FirebaseAuth.instance.currentUser;
      final userPhotoUrl = currentUser?.photoURL;
      final rawDisplayName = currentUser?.displayName?.trim();
      final userDisplayName =
          (rawDisplayName != null && rawDisplayName.isNotEmpty)
          ? rawDisplayName
          : 'User ${uid.substring(0, 6)}';

      // ✅ Persist to Firestore with timeout
      final updateData = <String, dynamic>{
        'joinedUids': willJoin
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
        'joinedUserUids': willJoin
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
        'joinedUserNames': willJoin
            ? FieldValue.arrayUnion([userDisplayName])
            : FieldValue.arrayRemove([userDisplayName]),
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

      updateData['participantStates.$uid'] = willJoin ? 'joined' : 'left';

      await docRef.update(updateData).timeout(const Duration(seconds: 15));

      if (_isOffline) {
        await OfflineService.instance.queueJoinAction(
          walkId: walkId,
          join: willJoin,
        );
      }

      // ✅ Record walk history for tracking
      if (willJoin) {
        await WalkHistoryService.instance.recordWalkJoin(walkId);
        await UserStatsService.instance.recordWalkJoined(uid);
      } else {
        if (leavingActive) {
          await WalkHistoryService.instance.leaveWalkEarly(walkId);
          await GPSTrackingService.instance.stopTracking(walkId);
        } else {
          await WalkHistoryService.instance.recordWalkLeave(walkId);
        }
      }

      // 🔔 Tell the host (in-app; Spark has no Cloud Functions)
      if (!_isOffline && event.hostUid.isNotEmpty && event.hostUid != uid) {
        unawaited(
          willJoin
              ? NotificationSender.walkJoined(
                  walkId: walkId,
                  hostUid: event.hostUid,
                  walkTitle: event.title,
                )
              : NotificationSender.walkLeft(
                  walkId: walkId,
                  hostUid: event.hostUid,
                  walkTitle: event.title,
                ),
        );
      }

      // 🔔 Local reminders
      final updated = event.copyWith(joined: willJoin);
      if (willJoin) {
        NotificationService.instance.scheduleWalkReminder(updated);
      } else {
        NotificationService.instance.cancelWalkReminder(updated);
      }

      if (mounted) {
        final msg = _isOffline
            ? "Saved offline. We'll sync when you're back online."
            : (willJoin
                  ? 'You joined the walk!'
                  : (leavingActive
                        ? 'You left the active walk.'
                        : 'You cancelled your spot.'));
        ErrorHandler.showErrorSnackBar(
          context,
          msg,
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
    // Get the correct walk ID (use firestoreId if available)
    final walkId = event.firestoreId.isNotEmpty ? event.firestoreId : event.id;

    // ✅ Save cancellation to Firestore FIRST
    WalkControlService.instance
        .cancelWalk(walkId)
        .then((_) {
          // Firestore listener will auto-update UI via snapshot
          debugPrint('✅ Walk $walkId cancelled on Firestore');
        })
        .catchError((e, st) {
          debugPrint('❌ Error cancelling walk: $e');
          CrashService.recordError(e, st);
          // Show error to user
          if (mounted) {
            ErrorHandler.showErrorSnackBar(
              context,
              'Failed to cancel walk: $e',
            );
          }
        });

    // Optimistic UI update (will be confirmed by listener)
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

  void _openActiveWalk(WalkEvent walk) {
    final walkId = walk.firestoreId.isNotEmpty ? walk.firestoreId : walk.id;
    if (walkId.isEmpty) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Unable to open walk - missing identifier.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWalkScreen(walkId: walkId, initialWalk: walk),
      ),
    );
  }

  Future<void> _handleHostedStart(WalkEvent walk) async {
    if (_isStartingHostedWalk) return;

    final walkId = walk.firestoreId.isNotEmpty ? walk.firestoreId : walk.id;
    if (walkId.isEmpty) {
      ErrorHandler.showErrorSnackBar(
        context,
        'Unable to start walk: missing walk ID.',
      );
      return;
    }

    setState(() {
      _isStartingHostedWalk = true;
    });

    try {
      await WalkControlService.instance.startWalk(walkId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Walk started. Participants are being notified.'),
        ),
      );

      _refreshHostedCountdown();
    } catch (e, st) {
      CrashService.recordError(e, st);
      if (mounted) {
        final friendly = e.toString().replaceFirst('Exception: ', '');
        ErrorHandler.showErrorSnackBar(
          context,
          friendly.isEmpty ? 'Failed to start walk.' : friendly,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingHostedWalk = false;
        });
      }
    }
  }

  // === Open notifications screen (full page) ===
  Future<void> _openNotificationsSheet() async {
    // Mark all as read when opening
    await NotificationStorage.markAllRead();
    await _refreshNotificationsCount();

    if (!mounted) return;

    await Navigator.pushNamed(context, NotificationsScreen.routeName);

    // Refresh count when returning
    await _refreshNotificationsCount();
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

    // The user may have changed their name or photo on the profile screen.
    await _loadUserName();
  }

  // --- UI ---

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Offline mode: showing cached walks. Changes will sync when back online.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingBanner() {
    return Container(
      width: double.infinity,
      color: Colors.blueGrey.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Syncing your pending actions...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailVerificationBanner() {
    final user = FirebaseAuth.instance.currentUser;

    // Only show if user is logged in and email is not verified
    if (user == null || user.emailVerified) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.amber.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Email not verified',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Check your inbox for the verification link',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _resendVerificationEmail(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Resend',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.emailVerified) return;

    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email sent to ${user.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

    // Status bar: transparent, icons readable on the page background.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
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
      backgroundColor: AppPalette.of(context).background,
      // The floating bar overlays the page; pages leave room for it.
      extendBody: true,
      body: _currentTab == 0
          ? body // Home shows the banners inside its own scroll view
          : Column(
              children: [
                if (_isOffline) _buildOfflineBanner(),
                if (_pendingActions > 0 && !_isOffline) _buildSyncingBanner(),
                _buildEmailVerificationBanner(),
                // Not redesigned yet: keep their content above the
                // floating bar.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: FloatingNavBar.reservedHeight - 24,
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
      bottomNavigationBar: FloatingNavBar(
        // Bar: 0 home, 1 map (walks tab), 2 calendar (events tab), 3 profile
        currentIndex: _currentTab,
        onCreate: _openCreateWalk,
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
      ),
    );
  }

  /// Which walk the big card at the top of Home shows, and in which mode.
  (WalkEvent?, HomeHeroMode?) _homeHero() {
    final hosted = _nextHostedWalk;
    final joined = _nextParticipantWalk;
    if (hosted != null && hosted.status == 'active') {
      return (hosted, HomeHeroMode.hostActive);
    }
    if (joined != null && joined.status == 'active') {
      return (joined, HomeHeroMode.joinedActive);
    }
    if (hosted != null &&
        (joined == null || !joined.dateTime.isBefore(hosted.dateTime))) {
      return (hosted, HomeHeroMode.hostUpcoming);
    }
    if (joined != null) return (joined, HomeHeroMode.joinedUpcoming);

    // Nothing of mine planned: suggest the next open walk nearby.
    final now = DateTime.now();
    final open =
        _events
            .where(
              (e) =>
                  !e.cancelled &&
                  !e.isOwner &&
                  !e.joined &&
                  e.status == 'scheduled' &&
                  e.dateTime.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (open.isNotEmpty) return (open.first, HomeHeroMode.suggested);
    return (null, null);
  }

  Widget _buildHomeTab(BuildContext context) {
    final (heroWalk, heroMode) = _homeHero();
    final authUser = FirebaseAuth.instance.currentUser;
    return HomeTab(
      userName: _userName,
      photoUrl: authUser?.photoURL,
      unreadCount: _unreadNotifCount,
      walks: _events,
      heroWalk: heroWalk,
      heroMode: heroMode,
      canStartHosted: heroWalk != null && _canHostStartWalk(heroWalk),
      heroBusy: _isStartingHostedWalk || _isConfirmingParticipant,
      streakDays: _streakDays,
      weeklyKm: _weeklyKm,
      weeklyGoalKm: _weeklyGoalKm,
      banners: [
        if (_isOffline) _buildOfflineBanner(),
        if (_pendingActions > 0 && !_isOffline) _buildSyncingBanner(),
        _buildEmailVerificationBanner(),
      ],
      actions: HomeTabActions(
        onOpenNotifications: _openNotificationsSheet,
        onOpenProfile: _openProfileQuickSheet,
        onSearch: _openWalkSearch,
        onOpenWalk: _navigateToDetails,
        onJoin: (walk) => _toggleJoin(walk),
        onStartHosted: _handleHostedStart,
        onConfirmHere: _handleParticipantConfirm,
        onOpenActive: _openActiveWalk,
        onCreateWalk: _openCreateWalk,
        onBrowseWalks: () => setState(() => _currentTab = 1),
        onRefresh: () async {
          _listenToWalks();
          await _refreshNotificationsCount();
        },
      ),
    );
  }
}
//end of homescreeninstant
// ===== Smaller components =====

// ===== RECOMMENDATION CARD (horizontal carousel card) =====
