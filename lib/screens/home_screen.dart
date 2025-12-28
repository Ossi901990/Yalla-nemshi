// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/walk_event.dart';
import '../services/notification_service.dart';
import '../services/profile_storage.dart';

import 'create_walk_screen.dart';
import 'event_details_screen.dart';
import 'nearby_walks_screen.dart';
import 'profile_screen.dart';
import '../models/app_notification.dart';
import '../services/notification_storage.dart';
import '../services/app_preferences.dart';
import 'dart:math' as math;
import 'walk_chat_screen.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  void _listenToWalks() {
    _walksSub?.cancel();

    _walksSub = FirebaseFirestore.instance
        .collection('walks')
        .snapshots()
        .listen(
          (snap) {
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            debugPrint('WALKS SNAP: docs=${snap.docs.length} uid=$currentUid');

            final loaded = snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['firestoreId'] = doc.id;
              data['id'] ??= doc.id;

              final hostUid = data['hostUid'] as String?;
              data['isOwner'] =
                  (currentUid != null &&
                  hostUid != null &&
                  hostUid == currentUid);

              final joinedUids =
                  (data['joinedUids'] as List?)?.whereType<String>().toList() ??
                  [];
              data['joined'] =
                  (currentUid != null && joinedUids.contains(currentUid));

              return WalkEvent.fromMap(data);
            }).toList();

            if (!mounted) return;
            setState(() {
              _events
                ..clear()
                ..addAll(loaded);
            });
          },
          onError: (e) {
            debugPrint('WALKS STREAM ERROR: $e');
          },
        );
  }

  /// All events (hosted by user + nearby).
  final List<WalkEvent> _events = [];

  // Loaded from saved profile (falls back to "Walker")
  String _userName = 'Walker';

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
  StreamSubscription<User?>? _authSub;

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
      .fold<double>(0.0, (sum, e) => sum + e.distanceKm);

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
      _myWalksThisWeek.fold(0.0, (sum, e) => sum + e.distanceKm);

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

  String _formatFullDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day}, ${date.year}';
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

  Widget _buildDayPill(
    String label,
    int dayNumber,
    bool isSelected, {
    required bool isDark,
  }) {
    final labelColor = isDark
        ? (isSelected ? Colors.white : Colors.white70)
        : (isSelected ? Colors.black87 : Colors.black54);

    final numberColor = isDark
        ? (isSelected ? Colors.black87 : Colors.white)
        : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 10,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$dayNumber',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: numberColor,
          ),
        ),
      ],
    );
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
      labelColor = Colors.white.withOpacity(0.9);
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
                        ? Colors.white.withValues(alpha: 0.18)
                        : const Color(0xFF2E7D32).withValues(alpha: 0.55),
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
    _initStepCounter();
    _loadUserName();
    _loadWeeklyGoal();
    _listenToWalks();

    Future.microtask(() async {
      try {
        final snap = await FirebaseFirestore.instance.collection('walks').get();
        debugPrint(
          'WALKS GET: docs=${snap.docs.length} uid=${FirebaseAuth.instance.currentUser?.uid}',
        );
      } catch (e) {
        debugPrint('WALKS GET ERROR: $e');
      }
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _listenToWalks();
      _refreshNotificationsCount();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _walksSub?.cancel();
    _stepSubscription?.cancel();

    super.dispose();
  }

  Future<void> _loadWeeklyGoal() async {
    final value = await AppPreferences.getWeeklyGoalKm();
    setState(() {
      _weeklyGoalKm = value;
    });
  }

  Future<void> _refreshNotificationsCount() async {
    final notifications = await NotificationStorage.getNotifications();
    final unread = notifications.where((n) => n.isRead == false).length;

    if (!mounted) return;
    setState(() => _unreadNotifCount = unread);
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

    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      return; // permission denied, keep at 0
    }

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepError,
        cancelOnError: false,
      );
    } catch (_) {
      // silently ignore for now
    }
  }

  Future<void> _loadUserName() async {
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

  void _onStepError(error) {
    // You could log this or show a SnackBar if needed
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to join walks.')),
      );
      return;
    }

    // ✅ Always use Firestore doc id
    final walkId = event.firestoreId.isNotEmpty ? event.firestoreId : event.id;
    final docRef = FirebaseFirestore.instance.collection('walks').doc(walkId);

    final bool wasJoined = event.joined;
    final bool willJoin = !wasJoined;

    // ✅ Optimistic UI update (UI only — NO Firestore here)
    setState(() {
      final index = _events.indexWhere((e) {
        final idA = e.firestoreId.isNotEmpty ? e.firestoreId : e.id;
        final idB = walkId;
        return idA == idB;
      });
      if (index == -1) return;
      _events[index] = _events[index].copyWith(joined: willJoin);
    });

    try {
      // ✅ Persist to Firestore
      await docRef.update({
        'joinedUids': willJoin
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
      });

      // 🔔 Notifications
      final updated = event.copyWith(joined: willJoin);
      if (willJoin) {
        NotificationService.instance.scheduleWalkReminder(updated);
      } else {
        NotificationService.instance.cancelWalkReminder(updated);
      }
    } catch (e) {
      // ❌ Roll back if Firestore failed
      setState(() {
        final index = _events.indexWhere((e2) {
          final idA = e2.firestoreId.isNotEmpty ? e2.firestoreId : e2.id;
          return idA == walkId;
        });
        if (index == -1) return;
        _events[index] = _events[index].copyWith(joined: wasJoined);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update join status: $e')),
      );
    }
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
                const Text(
                  'No notifications yet',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.notifications, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    // 🔹 NEW: Clear button (top-right)
                    TextButton(
                      onPressed: () async {
                        await NotificationStorage.clearNotifications();
                        Navigator.of(context).pop(); // close sheet
                        _openNotificationsSheet(); // reopen with updated list
                      },
                      child: const Text(
                        'Clear',
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
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
  void _openProfileQuickSheet() {
    setState(() => _currentTab = 2);
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    Widget body;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (_currentTab) {
      case 0:
        body = _buildHomeTab(context);
        break;
      case 1:
        {
          debugPrint(
            'NEARBY TAB: events=${_events.length} nearby=${_nearbyWalks.length} '
            'uid=${FirebaseAuth.instance.currentUser?.uid}',
          );

          if (_events.isNotEmpty) {
            final e0 = _events.first;
            debugPrint(
              'SAMPLE WALK: title=${e0.title} isOwner=${e0.isOwner} cancelled=${e0.cancelled} '
              'joined=${e0.joined} firestoreId=${e0.firestoreId}',
            );
          }

          body = NearbyWalksScreen(
            events: _nearbyWalks,
            onToggleJoin: (e) => _toggleJoin(e),
            onToggleInterested: _toggleInterested,
            onTapEvent: _navigateToDetails,
            onCancelHosted: _cancelHostedWalk,
            walksJoined: _walksJoined,
            eventsHosted: _eventsHosted,
            totalKm: _totalKmJoined,
            interestedCount: _interestedCount,
            weeklyKm: _weeklyKm,
            weeklyWalks: _weeklyWalkCount,
            streakDays: _streakDays,
            weeklyGoalKm: _weeklyGoalKm,
            userName: _userName,
          ); // ✅ THIS LINE MUST EXIST

          break;
        }

      case 2:
      default:
        body = ProfileScreen(
          walksJoined: _walksJoined,
          eventsHosted: _eventsHosted,
          totalKm: _totalKmJoined,
          weeklyWalks: _weeklyWalkCount,
          weeklyKm: _weeklyKm,
          weeklyGoalKm: _weeklyGoalKm,
          streakDays: _streakDays,
          interestedCount: _interestedCount,
          onWeeklyGoalChanged: _updateWeeklyGoal, // 👈 NEW
        );
        break;
    }

    return Scaffold(
      // Deep green behind the top bar only – content sits on a card.
      backgroundColor: isDark ? kDarkBg : const Color(0xFFF7F3EA),

      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
          if (index == 0) {
            _loadUserName();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? kDarkSurface2 : Colors.white,
        elevation: 0,
        selectedItemColor: isDark ? kMintBright : const Color(0xFF14532D),
        unselectedItemColor: isDark ? kTextMuted : Colors.black54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Nearby',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          // ===== HEADER =====
          if (isDark)
            // --- Dark: floating header (no bar) ---
            Padding(
              padding: EdgeInsets.fromLTRB(kSpace2, 12, kSpace2, kSpace3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        child: const Icon(
                          Icons.directions_walk,
                          size: 30,
                          color: kMintBright,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Yalla Nemshi',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
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
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: const Icon(
                                Icons.notifications_none,
                                size: 18,
                                color: kTextPrimary,
                              ),
                            ),
                            if (_unreadNotifCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    _unreadNotifCount > 99
                                        ? '99+'
                                        : '$_unreadNotifCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
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
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            // --- Light: keep the gradient bar ---
            Container(
              padding: EdgeInsets.fromLTRB(kSpace2, 12, kSpace2, kSpace3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF294630), Color(0xFF4F925C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
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
                          size: 18,
                          color: Colors.white,
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
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            if (_unreadNotifCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    _unreadNotifCount > 99
                                        ? '99+'
                                        : '$_unreadNotifCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
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
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Color(0xFF14532D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                                borderRadius: BorderRadius.circular(
                                  kRadiusCard,
                                ),
                                side: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: kCardBorderAlpha),
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
                                                style: theme
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? kTextPrimary
                                                          : const Color(
                                                              0xFF14532D,
                                                            ),
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatFullDate(today),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: isDark
                                                          ? kTextSecondary
                                                          : Colors.black54,
                                                    ),
                                              ),
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

                                    // Today + date row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Today',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          _formatFullDate(today),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: kSpace1),

                                    // ===== Calendar (week swipe + no dots + fixed sizing) =====
                                    TableCalendar(
                                      firstDay: DateTime(2020, 1, 1),
                                      lastDay: DateTime(2035, 12, 31),
                                      focusedDay: _focusedDay,
                                      calendarFormat: CalendarFormat.week,
                                      headerVisible: false,
                                      daysOfWeekVisible: false,
                                      rowHeight: 60,

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
                                        setState(
                                          () => _focusedDay = focusedDay,
                                        );
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
                                        todayBuilder:
                                            (context, day, focusedDay) {
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

                                        final events = _eventsForDay(
                                          selectedDay,
                                        );
                                        if (events.isNotEmpty) {
                                          _navigateToDetails(events.first);
                                        }
                                      },
                                    ),

                                    // ===== End Calendar =====
                                    const SizedBox(height: 20),

                                    // Ready to walk + buttons
                                    Text(
                                      'Ready to walk?',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    SizedBox(height: kSpace1),
                                    Text(
                                      'Start a walk now or join others nearby. Your steps, your pace.',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    SizedBox(height: kSpace2),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _openCreateWalk,
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              kMintBright, // mint button
                                          foregroundColor:
                                              kOnMint, // dark text/icon
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
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
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () {
                                              setState(() => _currentTab = 1);
                                            },
                                            child: const Text(
                                              'Find nearby walks',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () {
                                              setState(() => _currentTab = 2);
                                            },
                                            child: const Text(
                                              'Profile & stats',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 20),

                                    // Your walks inside main card
                                    Text(
                                      'Your walks',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    SizedBox(height: kSpace1),
                                    if (_myHostedWalks.isEmpty)
                                      Text(
                                        'No walks yet.\nTap "Start walk" above to create your first one.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                      )
                                    else
                                      Column(
                                        children: _myHostedWalks
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

                            // ===== QUICK STATS =====
                            Text(
                              'Your quick stats',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatCard(
                                  label: 'Walks joined',
                                  value: '$_walksJoined',
                                ),
                                _StatCard(
                                  label: 'Events hosted',
                                  value: '$_eventsHosted',
                                ),
                                _StatCard(
                                  label: 'Total km',
                                  value: _totalKmJoined.toStringAsFixed(1),
                                  isLast: true,
                                ),
                              ],
                            ),
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
      ),
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
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: kCardBorderAlpha,
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
                        : Colors.black.withValues(alpha: 0.06),
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

            // Fancy progress bar (step-counter style but horizontal)
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

                      // subtle “shine” overlay to feel more premium
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
              style: theme.textTheme.bodySmall?.copyWith(color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _StatCard({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Card(
        color: isDark ? kDarkSurface : kLightSurface,
        margin: EdgeInsets.only(right: isLast ? 0 : 8),
        elevation: isDark ? kCardElevationDark : kCardElevationLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusControl),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: kCardBorderAlpha,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? kTextPrimary : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? kTextSecondary : null,
                ),
              ),
            ],
          ),
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
                  .withValues(alpha: kCardBorderAlpha),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          event.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(_formatDateTime(event.dateTime)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
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
            ? Colors.white.withValues(alpha: 0.16)
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
                      ? Colors.white.withValues(alpha: 0.10)
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
