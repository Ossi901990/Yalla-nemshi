// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
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
import '../services/offline_service.dart';
import '../services/walk_history_service.dart';
import '../services/walk_control_service.dart';
import '../services/gps_tracking_service.dart';
import '../services/tag_recommendation_service.dart';
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
import 'walk_search_screen.dart';
import 'active_walk_screen.dart';
import '../services/notification_storage.dart';
import '../screens/notifications_screen.dart';
import '../providers/auth_provider.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        final userCity = await AppPreferences.getUserCity();
        final userCityNormalized =
          await AppPreferences.getUserCityNormalized() ??
          (userCity != null ? AppPreferences.normalizeCity(userCity) : null);
      if (!mounted) return;

      final nowTimestamp = Timestamp.fromDate(DateTime.now());

      // Build query: filter by city if user has one set
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        'walks',
      );

      if ((userCityNormalized != null && userCityNormalized.isNotEmpty) ||
          (userCity != null && userCity.isNotEmpty)) {
        debugPrint(
          'Polling walks by city (including cityless): $userCity',
        );
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
        debugPrint('ΓÜá∩╕Å No user city set; polling all walks');
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

        ownHostQuery = ownBase.where('hostUid', isEqualTo: currentUid).limit(
          _walksPerPage,
        );
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

      final fromCache = upcomingSnap.metadata.isFromCache &&
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
      debugPrint('Γ¥î Error fetching walks: $e');
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
      final List<WalkEvent> newWalks =
          _parseWalkDocs(combinedDocs, currentUid);
      final existingIds = _events.map((e) => e.firestoreId).toSet();
      final List<WalkEvent> uniqueWalks =
          newWalks.where((w) => !existingIds.contains(w.firestoreId)).toList();

      _logHomeFeedSummary(
        source: 'load_more',
        totalDocs: combinedDocs.length,
        parsedCount: newWalks.length,
        keptCount: uniqueWalks.length,
        fromCache: upcomingSnap.metadata.isFromCache && activeSnap.metadata.isFromCache,
      );

      setState(() {
        _events.addAll(uniqueWalks);
        _isLoadingMore = false;
      });

      _refreshHostedCountdown();
      _refreshParticipantCountdown();

      OfflineService.instance.cacheWalks(_events);

      debugPrint(
        '≡ƒôä Loaded ${uniqueWalks.length} more walks. Total: ${_events.length}',
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

        debugPrint('Γ¥î Error loading more walks: $e');
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
      debugPrint('Γ¥î Failed to parse walk ${doc.id}: $error');
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
  List<WalkEvent> _recommendations =
      []; // For future UI recommendations section
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
  Timer? _walksPollingTimer; // For periodic polling instead of real-time

  int _unreadNotifCount = 0;

  StreamSubscription<StepCount>? _stepSubscription;
  int _sessionSteps = 0;
  int? _baselineSteps;
  Timer? _hostedCountdownTimer;
  WalkEvent? _nextHostedWalk;
  Duration _hostedCountdownRemaining = Duration.zero;
  bool _isStartingHostedWalk = false;
  Timer? _participantCountdownTimer;
  WalkEvent? _nextParticipantWalk;
  Duration _participantCountdownRemaining = Duration.zero;
  bool _isConfirmingParticipant = false;

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
      _hostedCountdownRemaining = Duration.zero;
      return;
    }

    if (next == null) {
      setState(() {
        _nextHostedWalk = null;
        _hostedCountdownRemaining = Duration.zero;
      });
      return;
    }

    void updateRemaining() {
      if (!mounted) return;
      final remaining = next.dateTime.difference(DateTime.now());
      setState(() {
        _nextHostedWalk = next;
        _hostedCountdownRemaining = remaining.isNegative
            ? Duration.zero
            : remaining;
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
      _participantCountdownRemaining = Duration.zero;
      return;
    }

    if (next == null) {
      setState(() {
        _nextParticipantWalk = null;
        _participantCountdownRemaining = Duration.zero;
      });
      return;
    }

    void updateRemaining() {
      if (!mounted) return;
      final remaining = next.dateTime.difference(DateTime.now());
      setState(() {
        _nextParticipantWalk = next;
        _participantCountdownRemaining = remaining.isNegative
            ? Duration.zero
            : remaining;
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

  String _formatHostedCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleParticipantConfirm(WalkEvent walk) async {
    if (_isConfirmingParticipant) return;
    setState(() {
      _isConfirmingParticipant = true;
    });
    try {
      await WalkHistoryService.instance.confirmParticipation(walk.firestoreId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Confirmation sent')),
      );
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
  List<WalkEvent> _eventsForDay(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);

    // Γ£à Only walks that YOU host or joined and are not cancelled
    return _events.where((e) {
      if (e.cancelled) return false;
      if (!(e.joined || e.isOwner)) return false;

      final ed = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      return ed.year == d0.year && ed.month == d0.month && ed.day == d0.day;
    }).toList();
  }

  Widget _buildCalendarDayCell(
    DateTime day,
    bool isDark, {
    bool forceSelected = false,
  }) {
    final bool isSelected = forceSelected || isSameDay(_selectedDay, day);
    final bool isToday = isSameDay(day, DateTime.now());
    final bool hasWalk = _hasUpcomingWalkOnDay(day);

    // Γ£à Single-letter labels to match your UI
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

    // Γ£à Priority: Selected > Walk day > Today > Normal
    Color bg;
    Color border;
    Color labelColor;
    Color numberColor;

    if (isSelected) {
      bg = isDark ? const Color(0xFF00D97E) : const Color(0xFF1ABFC4);
      border = Colors.transparent;
      labelColor = Colors.white.withAlpha((0.9 * 255).round());
      numberColor = Colors.white;
    } else if (hasWalk) {
      bg = isDark ? const Color(0xFF00D97E) : const Color(0xFF00D97E);
      border = Colors.transparent;
      labelColor = isDark ? Colors.black87 : Colors.black87;
      numberColor = Colors.black87;
    } else if (isToday) {
      // Γ£à Today gets a subtle outline ONLY (different from walk highlight)
      bg = Colors.transparent;
      border = isDark ? Colors.white24 : Colors.black12;
      labelColor = isDark ? Colors.white70 : Colors.black54;
      numberColor = isDark ? Colors.white : Colors.black87;
    } else {
      bg = isDark ? Colors.white10 : Colors.white;
      border = Colors.transparent;
      labelColor = isDark ? Colors.white70 : Colors.black54;
      numberColor = isDark ? Colors.white : Colors.black87;
    }

    // Γ£à FIX: Force every cell to same size to prevent weird pills + overflow
    const double cellSize = 44;

    return Center(
      child: SizedBox(
        width: cellSize,
        height: cellSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(kRadiusPill),

            // Γ£à Walk day indicator
            // - if it has an upcoming walk and it's not selected ΓåÆ show a subtle border
            // - if it's selected ΓåÆ keep selected clean (no extra border needed)
            border: (hasWalk && !isSelected)
                ? Border.all(
                    color: isDark
                        ? Colors.white.withAlpha((0.18 * 255).round())
                        : const Color(
                            0xFF00D97E,
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
                  fontFamily: 'Inter',
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
                  fontFamily: 'Inter',
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
    
    // DEBUG: Print current user info
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('🆔 HOME SCREEN - Current User ID: ${user?.uid}');
    debugPrint('🆔 HOME SCREEN - Current User Email: ${user?.email}');
    debugPrint('🆔 HOME SCREEN - Current User Name: ${user?.displayName}');
    
    if (!kIsWeb) {
      _initStepCounter();
    }

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
    _loadProfile(); // Γ£à load saved avatar
    _loadWeeklyGoal();
    _loadCachedWalks();
    _loadRecommendations(); // Γ£à Load tag-based recommendations
    _listenToWalks();

    // ≡ƒö╣ Sync user profile to Firestore (if missing)
    FirestoreSyncService.syncCurrentUser();
  }

  @override
  void dispose() {
      _participantCountdownTimer?.cancel();
    _walksSub?.cancel();
    _walksPollingTimer?.cancel(); // Stop periodic polling
    _stepSubscription?.cancel();
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
      debugPrint('ΓÜá∩╕Å Error loading weekly goal: $e');
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

  Future<void> _loadRecommendations() async {
    try {
      final recs = await TagRecommendationService.instance.getRecommendations();
      if (!mounted) return;
      setState(() {
        _recommendations = recs; // Can be used for "Recommended" section in UI
      });
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'HomeScreen.loadRecommendations');
    }
  }

  Future<void> _refreshNotificationsCount() async {
    try {
      final unread = await NotificationStorage.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifCount = unread);
    } catch (e, st) {
      debugPrint('ΓÜá∩╕Å Error refreshing notification count: $e');
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
    if (kIsWeb) return; // Pedometer plugin is native-only

    // Only try on Android
    if (!Platform.isAndroid) return;

    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        debugPrint('ΓÜá∩╕Å Activity recognition permission denied');
        return;
      }

      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error, stackTrace) {
          debugPrint('Γ¥î Pedometer error: $error');
          CrashService.recordError(error, stackTrace ?? StackTrace.current);
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      debugPrint('Γ¥î Error initializing step counter: $e');
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
      debugPrint('Γ¥î Error loading user name: $e');
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

    _refreshHostedCountdown();

    // ≡ƒöö Schedule reminder for the walk you just created (host)
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

    // Γ£à Always use Firestore doc id
    final walkId = event.firestoreId.isNotEmpty ? event.firestoreId : event.id;
    final docRef = FirebaseFirestore.instance.collection('walks').doc(walkId);

    final bool wasJoined = event.joined;
    final bool willJoin = !wasJoined;
    final bool leavingActive = !willJoin && event.status == 'active';

    // Get current user info for optimistic update
    final currentUser = FirebaseAuth.instance.currentUser;
    final userPhotoUrl = currentUser?.photoURL;

    // Γ£à Optimistic UI update
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
      final newParticipantStates = Map<String, String>.from(
        currentEvent.participantStates,
      );

      if (willJoin) {
        if (!newJoinedUids.contains(uid)) {
          newJoinedUids.add(uid);
        }
        if (userPhotoUrl != null && !newJoinedPhotos.contains(userPhotoUrl)) {
          newJoinedPhotos.add(userPhotoUrl);
        }
        newParticipantStates[uid] = 'joined';
      } else {
        newJoinedUids.remove(uid);
        if (userPhotoUrl != null) {
          newJoinedPhotos.remove(userPhotoUrl);
        }
        newParticipantStates[uid] = 'left';
      }

      _events[index] = currentEvent.copyWith(
        joined: willJoin,
        joinedUserUids: newJoinedUids,
        joinedUserPhotoUrls: newJoinedPhotos,
        joinedCount: newJoinedUids.length,
        participantStates: newParticipantStates,
      );
    });

    try {
      // Γ£à Get current user info for participant data
      final currentUser = FirebaseAuth.instance.currentUser;
      final userPhotoUrl = currentUser?.photoURL;

      // Γ£à Persist to Firestore with timeout
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

      updateData['participantStates.$uid'] = willJoin ? 'joined' : 'left';

      await docRef.update(updateData).timeout(const Duration(seconds: 15));

      if (_isOffline) {
        await OfflineService.instance.queueJoinAction(
          walkId: walkId,
          join: willJoin,
        );
      }

      // Γ£à Record walk history for tracking
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

      // ≡ƒöö Notifications
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
      // Γ¥î Roll back on timeout
      _rollbackJoinStatus(walkId, wasJoined);

      if (mounted) {
        CrashService.recordError(e, st);
        ErrorHandler.showErrorSnackBar(
          context,
          'Operation took too long. Please try again.',
        );
      }
    } catch (e, st) {
      // Γ¥î Roll back if Firestore failed
      _rollbackJoinStatus(walkId, wasJoined);

      if (mounted) {
        debugPrint('Γ¥î Join/Leave error: $e');
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

    // Γ£à Save cancellation to Firestore FIRST
    WalkControlService.instance
        .cancelWalk(walkId)
        .then((_) {
          // Firestore listener will auto-update UI via snapshot
          debugPrint('Γ£à Walk $walkId cancelled on Firestore');
        })
        .catchError((e, st) {
          debugPrint('Γ¥î Error cancelling walk: $e');
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

      // ≡ƒöò Cancel any reminder for this event
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

    // Γ£à When user returns from Profile, reload the saved profile (avatar)
    await _loadProfile();
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

  Widget _buildHostedWalkBanner(BuildContext context, bool isDark) {
    final walk = _nextHostedWalk;
    if (walk == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final Color headlineColor = isDark ? Colors.white : const Color(0xFF0A3B3A);
    final Color detailColor = isDark
        ? Colors.white.withAlpha(220)
        : const Color(0xFF0D5552).withValues(alpha: 0.85);
    final Color chipColor = isDark ? Colors.white : const Color(0xFF0D5552);
    final bool isActive = walk.status == 'active';
    final countdownText = isActive
        ? 'Walk in progress'
        : 'Starts in ${_formatHostedCountdown(_hostedCountdownRemaining)}';
    final subtitle = walk.meetingPlaceName != null
        ? '${walk.meetingPlaceName} ΓÇó ${DateFormat('MMM d, hh:mm a').format(walk.dateTime)}'
        : DateFormat('MMM d, hh:mm a').format(walk.dateTime);

    final primaryLabel = isActive ? 'Open Active Walk' : 'Start Walk';
    final bool canStart = _canHostStartWalk(walk);
    final bool isStartLoading = _isStartingHostedWalk && !isActive;
    final VoidCallback? primaryAction = isActive
        ? () => _openActiveWalk(walk)
        : (canStart ? () => _handleHostedStart(walk) : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F2734), Color(0xFF143D4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE2FBF7), Color(0xFFC6EEE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(30)
              : const Color(0xFF0A3B3A).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, size: 18, color: chipColor),
              const SizedBox(width: 8),
              Text(
                'Your next hosted walk',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            walk.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: headlineColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: detailColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isActive ? Icons.run_circle : Icons.timer_outlined,
                color: chipColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                countdownText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isStartLoading ? null : primaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF0F8A7B),
                    foregroundColor: isDark
                        ? const Color(0xFF0F2734)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isStartLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? const Color(0xFF0F2734) : Colors.white,
                            ),
                          ),
                        )
                      : Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _navigateToDetails(walk),
                style: OutlinedButton.styleFrom(
                  foregroundColor: chipColor,
                  side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
                ),
                child: const Text('View details'),
              ),
            ],
          ),
        ],
      ),
    );
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

    // Γ£à Force the phone status-bar area to match our header color
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        // Γ£à Match the TOP of your gradient bar: Color(0xFF1ABFC4)
        statusBarColor: isDark ? Colors.transparent : const Color(0xFF1ABFC4),
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
      // Γ£à Make status-bar area green in LIGHT mode too (matches Profile/Nearby)
      backgroundColor: isDark ? kDarkBg : const Color(0xFF1ABFC4),

      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          if (_pendingActions > 0 && !_isOffline) _buildSyncingBanner(),
          _buildEmailVerificationBanner(),
          Expanded(child: body),
        ],
      ),
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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

                  // Right: search + notif + profile
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'Search walks',
                        button: true,
                        child: GestureDetector(
                          onTap: _openWalkSearch,
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
                              Icons.search,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: _unreadNotifCount > 0
                            ? '$_unreadNotifCount unread notification${_unreadNotifCount == 1 ? '' : 's'}'
                            : 'Notifications',
                        button: true,
                        child: GestureDetector(
                          onTap: _openNotificationsSheet,
                          child: Transform.translate(
                            offset: const Offset(0, -1),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
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
                                  if (_unreadNotifCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          _unreadNotifCount > 99
                                              ? '99+'
                                              : '$_unreadNotifCount',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Profile',
                        button: true,
                        child: GestureDetector(
                          onTap: _openProfileQuickSheet,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withAlpha(
                                  (0.2 * 255).round(),
                                ),
                                width: 2,
                              ),
                            ),
                            child: _HeaderAvatar(
                              profile: _profile,
                              size: 40,
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
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
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
                        Semantics(
                          label: 'Search walks',
                          button: true,
                          child: GestureDetector(
                            onTap: _openWalkSearch,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                              ),
                              child: const Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openNotificationsSheet,
                          child: Transform.translate(
                            offset: const Offset(0, -1),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
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
                                  if (_unreadNotifCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          _unreadNotifCount > 99
                                              ? '99+'
                                              : '$_unreadNotifCount',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openProfileQuickSheet,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withAlpha(
                                  (0.3 * 255).round(),
                                ),
                                width: 2,
                              ),
                            ),
                            child: _HeaderAvatar(
                              profile: _profile,
                              size: 40,
                              isDark: false,
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

        // ===== MAIN CONTENT CARD (ROUNDED TOP, WITH OPTIONAL BG IMAGE) =====
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? kDarkBg : const Color(0xFF1ABFC4),
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
                    : null,
                color: isDark ? null : const Color(0xFFF7F9F2),
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
                          if (_nextHostedWalk != null) ...[
                            _buildHostedWalkBanner(context, isDark),
                            const SizedBox(height: 20),
                          ],
                          if (_nextParticipantWalk != null) ...[
                            _buildParticipantWalkBanner(context, isDark),
                            const SizedBox(height: 20),
                          ],
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
                                              style:
                                                  theme.textTheme.titleLarge
                                                      ?.copyWith(
                                                        fontFamily: 'Poppins',
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: -0.2,
                                                        color: isDark
                                                            ? kTextPrimary
                                                            : const Color(
                                                                0xFF1A2332,
                                                              ),
                                                      ) ??
                                                  const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.2,
                                                    color: Color(0xFF1A2332),
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
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                          fontFamily: 'Poppins',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ) ??
                                        const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                  ),
                                  SizedBox(height: kSpace1),
                                  Text(
                                    'Start a walk now or join others nearby. Your steps, your pace.',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          height: 1.55,
                                          color: const Color(0xFF2F2F2F),
                                        ) ??
                                        const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          height: 1.55,
                                          color: Color(0xFF2F2F2F),
                                        ),
                                  ),
                                  SizedBox(height: kSpace2),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: FilledButton.icon(
                                      onPressed: _openCreateWalk,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1ABFC4,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            kRadiusPill,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.directions_walk_outlined,
                                      ),
                                      label: const Text('Create walk'),
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

                                    // Γ£à smoother swipe between weeks
                                    pageAnimationEnabled: true,
                                    pageAnimationDuration: const Duration(
                                      milliseconds: 220,
                                    ),
                                    pageAnimationCurve: Curves.easeOutCubic,

                                    // Γ£à IMPORTANT: keep outside days visible so the week row is consistent
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

                                      // Γ£à FIX: outside days were not using your pill builder
                                      outsideBuilder:
                                          (context, day, focusedDay) {
                                            return _buildCalendarDayCell(
                                              day,
                                              isDark,
                                              forceSelected: false,
                                            );
                                          },

                                      // Γ£à (optional safety) disabled days also use the same pill rendering
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

                          // ===== TAG-BASED RECOMMENDATIONS =====
                          if (_recommendations.isNotEmpty) ...[
                            Text(
                              'Recommended for you',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: kSpace1),
                            Text(
                              'Based on walks you\'ve joined',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            SizedBox(height: kSpace2),
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recommendations.length,
                                itemBuilder: (context, index) {
                                  final rec = _recommendations[index];
                                  return Container(
                                    width: 280,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: _RecommendationCard(
                                      event: rec,
                                      onTap: () => _navigateToDetails(rec),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: kSpace2),
                          ],
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

  Widget _buildParticipantWalkBanner(BuildContext context, bool isDark) {
    final walk = _nextParticipantWalk;
    if (walk == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final Color headlineColor = isDark ? Colors.white : const Color(0xFF0A3B3A);
    final Color detailColor = isDark
        ? Colors.white.withAlpha(220)
        : const Color(0xFF0D5552).withValues(alpha: 0.85);
    final Color chipColor = isDark ? Colors.white : const Color(0xFF0D5552);
    final bool isActive = walk.status == 'active';
    final countdownText = isActive
        ? 'Walk in progress'
        : 'Starts in ${_formatHostedCountdown(_participantCountdownRemaining)}';
    final subtitle = walk.meetingPlaceName != null
        ? '${walk.meetingPlaceName} • ${DateFormat('MMM d, hh:mm a').format(walk.dateTime)}'
        : DateFormat('MMM d, hh:mm a').format(walk.dateTime);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final participantState = uid == null ? null : walk.participantStates[uid];
    final bool needsConfirmation = isActive && participantState != 'confirmed';
    final String primaryLabel = isActive
        ? (needsConfirmation ? "Confirm I'm here" : 'Open Active Walk')
        : 'Waiting for host';
    final VoidCallback? primaryAction = isActive
        ? (needsConfirmation
            ? () => _handleParticipantConfirm(walk)
            : () => _openActiveWalk(walk))
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF12202A), Color(0xFF153D45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFEAFBF7), Color(0xFFD7F2EC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(30)
              : const Color(0xFF0A3B3A).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_walk, size: 18, color: chipColor),
              const SizedBox(width: 8),
              Text(
                'Your next walk',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            walk.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: headlineColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: detailColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isActive ? Icons.run_circle : Icons.timer_outlined,
                color: chipColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                countdownText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isConfirmingParticipant ? null : primaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF0F8A7B),
                    foregroundColor: isDark
                        ? const Color(0xFF0F2734)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isConfirmingParticipant && needsConfirmation
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? const Color(0xFF0F2734) : Colors.white,
                            ),
                          ),
                        )
                      : Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: isActive && needsConfirmation
                    ? () => _openActiveWalk(walk)
                    : () => _navigateToDetails(walk),
                style: OutlinedButton.styleFrom(
                  foregroundColor: chipColor,
                  side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  isActive && needsConfirmation
                      ? 'Open Active Walk'
                      : 'View details',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
//end of homescreeninstant
// ===== Smaller components =====

// ===== RECOMMENDATION CARD (horizontal carousel card) =====
class _RecommendationCard extends StatelessWidget {
  final WalkEvent event;
  final VoidCallback onTap;

  const _RecommendationCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Card(
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: isDark ? kTextPrimary : Colors.black87,
                    ) ??
                    const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${event.distanceKm} km • ${event.dateTime.month}/${event.dateTime.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? kTextSecondary : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              if (event.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: event.tags.take(2).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        border: Border.all(color: Colors.teal, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      if (p <= 0.01) return 'Let\'s get the first steps in!';
      if (p < 0.25) return 'Nice start - keep the momentum going!';
      if (p < 0.50) return 'You\'re building a habit - great progress!';
      if (p < 0.75) return 'More than halfway - you\'ve got this!';
      if (p < 1.00) return 'Almost there - one more push!';
      return 'Goal reached! Amazing work this week!';
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
                      color: isDark ? kTextPrimary : const Color(0xFF1A2332),
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
                    ? const Color(0xFF1ABFC4)
                    : const Color(0xFF1ABFC4);

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
                color: isDark ? kTextPrimary : const Color(0xFF1A2332),
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
        final Color base = isDark
            ? const Color(0xFF1ABFC4)
            : const Color(0xFF1ABFC4);

        // Very light color at 0 progress (so the start is almost white)
        final Color veryLight = isDark
            ? Colors.white.withAlpha((0.16 * 255).round())
            : const Color(0xFFE8F1EA); // Γ£à light green tint (not white)

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
                        ), // Γ£à slightly darker track so ring feels consistent
                  // Γ£à start ALWAYS very light
                  startColor: veryLight,
                  // Γ£à end darkens with progress
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
      // Γ£à end with startColor again ΓåÆ seam becomes light (no dark tick at top)
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

    // Prefer Auth photo (Google sign-in) if present
    final authUrl = FirebaseAuth.instance.currentUser?.photoURL;
    if (authUrl != null && authUrl.trim().isNotEmpty) {
      img = NetworkImage(authUrl);
    }

    // Base64 avatar (web testing)
    final base64Str = p?.profileImageBase64;
    if (img == null && base64Str != null && base64Str.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(base64Str);
        img = MemoryImage(bytes);
      } catch (_) {
        // ignore
      }
    }

    // Local file avatar path (mobile only)
    if (img == null && !kIsWeb) {
      final path = p?.profileImagePath;
      if (path != null && path.trim().isNotEmpty) {
        final f = File(path);
        if (f.existsSync()) {
          img = FileImage(f);
        }
      }
    }

    // 4) Final fallback: icon
    if (img == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withAlpha((0.08 * 255).round())
              : Colors.white,
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
      backgroundColor: isDark
          ? Colors.white.withAlpha((0.08 * 255).round())
          : Colors.white,
      backgroundImage: img,
    );
  }
}
