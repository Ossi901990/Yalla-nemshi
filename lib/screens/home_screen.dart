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
              final data = Map<String, dynamic>.from(
                doc.data() as Map<String, dynamic>,
              );
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

  // --- Step counter (Android, session-based for now) ---
  StreamSubscription<QuerySnapshot>? _walksSub;
  StreamSubscription<User?>? _authSub;

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

  // --- Step counter setup (Android only for now) ---

  @override
  void initState() {
    super.initState();
    _initStepCounter();
    _loadUserName();
    _loadWeeklyGoal();
    _listenToWalks(); // ✅ start listening immediately on app start
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      // When user switches accounts, re-subscribe so Firestore reads work
      _listenToWalks();
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
    final profile = await ProfileStorage.loadProfile();

    if (!mounted) return;

    setState(() {
      if (profile != null && profile.name.trim().isNotEmpty) {
        _userName = profile.name.trim();
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
    // Load history from SharedPreferences
    final List<AppNotification> notifications =
        await NotificationStorage.getNotifications();

    // Newest first
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFCFEF9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // ✅ If nothing stored yet → same placeholder as before
        if (notifications.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
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
                const SizedBox(height: 16),
              ],
            ),
          );
        }

        // ✅ Real notifications list
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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

  // === NEW: profile quick-view bottom sheet (no design change to main page) ===
  void _openProfileQuickSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFCFEF9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 28,
                child: Icon(Icons.person, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                _userName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Quick look at your progress',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MiniStat(label: 'Walks', value: '$_walksJoined'),
                  _MiniStat(
                    label: 'Total km',
                    value: _totalKmJoined.toStringAsFixed(1),
                  ),
                  _MiniStat(label: 'Streak', value: '${_streakDays}d'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // close sheet
                    setState(() => _currentTab = 2); // go to Profile tab
                  },
                  child: const Text('View full profile'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() => _currentTab = 2);
                    // Later, you could auto-open Edit on profile screen
                  },
                  child: const Text('Edit profile info'),
                ),
              ),
            ],
          ),
        );
      },
    );
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
        body = NearbyWalksScreen(
          events: _nearbyWalks,
          onToggleJoin: (e) => _toggleJoin(e),

          onToggleInterested: _toggleInterested,
          onTapEvent: _navigateToDetails,
          onCancelHosted: _cancelHostedWalk,
          // Stats for quick profile sheet + full profile screen
          walksJoined: _walksJoined,
          eventsHosted: _eventsHosted,
          totalKm: _totalKmJoined,
          interestedCount: _interestedCount,
          weeklyKm: _weeklyKm,
          weeklyWalks: _weeklyWalkCount,
          streakDays: _streakDays,
          weeklyGoalKm: _weeklyGoalKm,
          userName: _userName,
        );
        break;

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
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
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),

              // overlay so text stays readable on top of the photo
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
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
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Big inner card: greeting + calendar + "Your walks"
                            Card(
                              color: isDark
                                  ? kDarkSurface
                                  : const Color(0xFFFBFEF8),
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
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
                                                '${_greetingForTime()}, $_userName 👋',
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
                                          steps: 9000,
                                          goal: 10000, // you can change later
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

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

                                    const SizedBox(height: 8),

                                    // Calendar
                                    TableCalendar(
                                      firstDay: DateTime.utc(2020, 1, 1),
                                      lastDay: DateTime.utc(2030, 12, 31),
                                      focusedDay: _selectedDay,
                                      selectedDayPredicate: (day) =>
                                          isSameDay(day, _selectedDay),
                                      calendarFormat: CalendarFormat.week,
                                      headerVisible: false,
                                      daysOfWeekVisible: false,
                                      rowHeight: 60,
                                      eventLoader: (day) => _eventsForDay(day),
                                      calendarStyle: const CalendarStyle(
                                        isTodayHighlighted: false,
                                        outsideDaysVisible: false,
                                      ),
                                      calendarBuilders: CalendarBuilders(
                                        defaultBuilder:
                                            (context, day, focusedDay) {
                                              const labels = [
                                                'Mon',
                                                'Tue',
                                                'Wed',
                                                'Thu',
                                                'Fri',
                                                'Sat',
                                                'Sun',
                                              ];
                                              final label =
                                                  labels[day.weekday - 1];

                                              if (isDark) {
                                                // Dark: text only
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  child: _buildDayPill(
                                                    label,
                                                    day.day,
                                                    false,
                                                    isDark: isDark,
                                                  ),
                                                );
                                              }

                                              // Light: white pill
                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 0,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? kDarkSurface2
                                                      : const Color(0xFFE5F3D9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),

                                                child: _buildDayPill(
                                                  label,
                                                  day.day,
                                                  false,
                                                  isDark: isDark,
                                                ),
                                              );
                                            },
                                        selectedBuilder:
                                            (context, day, focusedDay) {
                                              const labels = [
                                                'Mon',
                                                'Tue',
                                                'Wed',
                                                'Thu',
                                                'Fri',
                                                'Sat',
                                                'Sun',
                                              ];
                                              final label =
                                                  labels[day.weekday - 1];

                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 0,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? kDarkSurface2
                                                      : const Color(0xFFE5F3D9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),

                                                child: _buildDayPill(
                                                  label,
                                                  day.day,
                                                  true,
                                                  isDark: isDark,
                                                ),
                                              );
                                            },
                                      ),
                                      onDaySelected: (selectedDay, focusedDay) {
                                        setState(() {
                                          _selectedDay = selectedDay;
                                        });

                                        final events = _eventsForDay(
                                          selectedDay,
                                        );
                                        if (events.isNotEmpty) {
                                          _navigateToDetails(events.first);
                                        }
                                      },
                                    ),

                                    const SizedBox(height: 20),

                                    // Ready to walk + buttons
                                    Text(
                                      'Ready to walk? 👟',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start a walk now or join others nearby. Your steps, your pace.',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 16),
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
                                    const SizedBox(height: 8),
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

                            const SizedBox(height: 16),

                            // ===== WEEKLY SUMMARY =====
                            Text(
                              'This week',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _WeeklySummaryCard(
                              walks: _weeklyWalkCount,
                              kmSoFar: _weeklyKm,
                              kmGoal: _weeklyGoalKm,
                              streakDays: _streakDays,
                            ),
                            const SizedBox(height: 16),

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

    return Card(
      color: isDark ? kDarkSurface : null,
      elevation: isDark ? 0 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$walks walk${walks == 1 ? '' : 's'} • '
              '${kmSoFar.toStringAsFixed(1)} / ${kmGoal.toStringAsFixed(1)} km',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: isDark ? kDarkSurface2 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? kMintBright : const Color(0xFF14532D),
                ),
              ),
            ),
            const SizedBox(height: 12),
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

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Card(
        color: isDark ? kDarkSurface : null,
        margin: const EdgeInsets.only(right: 8),
        elevation: isDark ? 0 : 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
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
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0.5,
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

    // Make it look like the reference (bigger + centered text)
    const double size = 120;
    const double stroke = 14;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _GradientRingPainter(
              progress: progress,
              strokeWidth: stroke,
              // Track behind the ring
              trackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.10),
              // These create the “fade in/out” feel
              startColor: (isDark ? kMint : const Color(0xFF14532D)).withValues(
                alpha: 0.35,
              ),
              endColor: (isDark ? kMintBright : const Color(0xFF14532D))
                  .withValues(alpha: 1.0),
            ),
          ),

          // Text
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
    final rect = Offset.zero & size;

    // Keep ring inside bounds (avoid clipping)
    final inset = strokeWidth / 2;
    final ringRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final center = ringRect.center;
    final radius = ringRect.width / 2;

    const startAngle = -math.pi / 2; // top
    final sweepAngle = 2 * math.pi * p;

    // Track ring (full circle behind) — use drawCircle so no seam/join
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, trackPaint);

    if (p <= 0) return;

    // Gradient along ONLY the progress arc: very faded start -> solid end
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      tileMode: TileMode.clamp,
      colors: [
        startColor.withValues(alpha: 0.12), // super light at the beginning
        endColor, // darker at the end
      ],
      stops: const [0.0, 1.0],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round; // smooth rounded end

    canvas.drawArc(ringRect, startAngle, sweepAngle, false, progressPaint);

    // Manual round caps (smooth)
    Offset pointOnCircle(double angle) {
      return Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    }

    final capRadius = strokeWidth / 2;

    final startCapPaint = Paint()
      ..color = startColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pointOnCircle(startAngle), capRadius, startCapPaint);

    final endCapPaint = Paint()
      ..color = endColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      pointOnCircle(startAngle + sweepAngle),
      capRadius,
      endCapPaint,
    );
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
