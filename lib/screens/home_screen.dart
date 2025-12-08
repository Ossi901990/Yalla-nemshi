// lib/screens/home_screen.dart 
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/walk_event.dart';
import '../services/notification_service.dart';

import 'create_walk_screen.dart';
import 'event_details_screen.dart';
import 'nearby_walks_screen.dart';
import 'profile_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  /// All events (hosted by user + nearby).
  final List<WalkEvent> _events = [];

  // TODO: Replace with real user name from profile/auth.
  final String _userName = 'Walker';
  DateTime _selectedDay = DateTime.now();

  // --- Step counter (Android, session-based for now) ---
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
  static const double _weeklyGoalKm = 10.0;

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
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
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

void _toggleJoin(WalkEvent event) {
  setState(() {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index == -1) return;

    final current = _events[index];
    final bool wasJoined = current.joined;
    final updated = current.copyWith(joined: !current.joined);

    _events[index] = updated;

    // 🔔 If user just JOINED → schedule reminder
    if (!wasJoined && updated.joined) {
      NotificationService.instance.scheduleWalkReminder(updated);
    }
    // 🔕 If user just LEFT → cancel reminder
    else if (wasJoined && !updated.joined) {
      NotificationService.instance.cancelWalkReminder(updated);
    }
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
          onToggleJoin: _toggleJoin,
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

  // === NEW: notification bottom sheet (no design change to main page) ===
  void _openNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFCFEF9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // Placeholder list – later you can hook real notifications
        final notifications = <String>[
          // 'Your walk "Morning in the park" starts in 45 minutes.',
          // 'New nearby walk: "Sunset steps" tomorrow at 18:00.',
        ];

        if (notifications.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_none,
                    size: 36, color: Colors.grey),
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.notifications, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...notifications.map(
                (msg) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.circle, size: 10, color: Colors.green),
                  title: Text(msg),
                ),
              ),
            ],
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
    onToggleJoin: _toggleJoin,
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
        );
        break;
    }

    return Scaffold(
      // Deep green behind the top bar only – content sits on a card.
       backgroundColor:
          isDark ? 
         const Color(0xFF0B1A13) // match your dark header bottom color
      : const Color(0xFF4F925C), // your light header bottom color
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
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
        // ===== TOP GRADIENT APP BAR (ONLY HEADER) =====
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      Color(0xFF020908), // darker top
                      Color(0xFF0B1A13), // darker bottom
                    ]
                  : const [
                      Color(0xFF294630), // top
                      Color(0xFF4F925C), // bottom
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(0),
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
                  // 🔹 Tappable notifications
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
                              '3', // TODO: real unread count
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
                  // 🔹 Tappable profile avatar
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
      color: isDark
          ? const Color.fromARGB(255, 9, 2, 7)
          : const Color(0xFFF7F9F2),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      image: DecorationImage(
        image: AssetImage(
          isDark
              ? 'assets/images/bg_minimal_dark.png'
              : 'assets/images/bg_minimal_light.png', // change name if needed
        ),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    ),

            // overlay so text stays readable on top of the photo
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.35)
                    : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Big inner card: greeting + calendar + "Your walks"
                          Card(
                            color: isDark
                                ? theme.colorScheme.surface
                                : const Color(0xFFFBFEF8),
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 16, 16, 20),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Greeting
                                  Text(
                                    '${_greetingForTime()}, $_userName 👋',
                                    style: theme
                                        .textTheme.titleLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          const Color(0xFF14532D),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatFullDate(today),
                                    style: theme
                                        .textTheme.bodySmall
                                        ?.copyWith(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Steps pill
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              const Color(0xFFE5F3D9),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  999),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.directions_walk,
                                              size: 16,
                                              color:
                                                  Color(0xFF14532D),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$_sessionSteps steps',
                                              style: theme.textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600,
                                                color:
                                                    const Color(0xFF14532D),
                                              ),
                                            ),
                                          ],
                                        ),
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
                                        style: theme
                                            .textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatFullDate(today),
                                        style: theme
                                            .textTheme.bodySmall
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
                                    firstDay:
                                        DateTime.utc(2020, 1, 1),
                                    lastDay:
                                        DateTime.utc(2030, 12, 31),
                                    focusedDay: _selectedDay,
                                    selectedDayPredicate: (day) =>
                                        isSameDay(
                                            day, _selectedDay),
                                    calendarFormat:
                                        CalendarFormat.week,
                                    headerVisible: false,
                                    daysOfWeekVisible: false,
                                    rowHeight: 60,
                                    eventLoader: (day) =>
                                        _eventsForDay(day),
                                    calendarStyle:
                                        const CalendarStyle(
                                      isTodayHighlighted: false,
                                      outsideDaysVisible: false,
                                    ),
                                    calendarBuilders:
                                        CalendarBuilders(
                                      defaultBuilder: (context,
                                          day, focusedDay) {
                                        const labels = [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun',
                                        ];
                                        final label = labels[
                                            day.weekday - 1];

                                        if (isDark) {
                                          // Dark: text only
                                          return Padding(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
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
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal: 4,
                                            vertical: 0,
                                          ),
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            vertical: 4,
                                            horizontal: 10,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        999),
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
                                          (context,
                                              day, focusedDay) {
                                        const labels = [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun',
                                        ];
                                        final label = labels[
                                            day.weekday - 1];

                                        return Container(
                                          margin:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal: 4,
                                            vertical: 0,
                                          ),
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            vertical: 4,
                                            horizontal: 10,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color: const Color(
                                                0xFFB7E76A),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        999),
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
                                    onDaySelected: (selectedDay,
                                        focusedDay) {
                                      setState(() {
                                        _selectedDay =
                                            selectedDay;
                                      });

                                      final events =
                                          _eventsForDay(
                                              selectedDay);
                                      if (events.isNotEmpty) {
                                        _navigateToDetails(
                                            events.first);
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 20),

                                  // Ready to walk + buttons
                                  Text(
                                    'Ready to walk? 👟',
                                    style: theme
                                        .textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start a walk now or join others nearby. Your steps, your pace.',
                                    style:
                                        theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed:
                                          _openCreateWalk,
                                      style:
                                          FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(
                                                0xFF14532D),
                                        foregroundColor:
                                            Colors.white,
                                      ),
                                      icon: const Icon(Icons
                                          .directions_walk_outlined),
                                      label: const Text(
                                          'Start walk'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() =>
                                                _currentTab =
                                                    1);
                                          },
                                          child: const Text(
                                              'Find nearby walks'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() =>
                                                _currentTab =
                                                    2);
                                          },
                                          child: const Text(
                                              'Profile & stats'),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Your walks inside main card
                                  Text(
                                    'Your walks',
                                    style: theme
                                        .textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_myHostedWalks.isEmpty)
                                    Text(
                                      'No walks yet.\nTap "Start walk" above to create your first one.',
                                      style: theme
                                          .textTheme.bodyMedium
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
                                                  _navigateToDetails(
                                                      e),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ===== WEEKLY SUMMARY =====
                          Text(
                            'This week',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(
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
                          const SizedBox(height: 24),

                          // ===== QUICK STATS =====
                          Text(
                            'Your quick stats',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
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
                                value: _totalKmJoined
                                    .toStringAsFixed(1),
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
    final progress = (kmGoal == 0) ? 0.0 : (kmSoFar / kmGoal).clamp(0.0, 1.0);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$walks walk${walks == 1 ? '' : 's'} • '
              '${kmSoFar.toStringAsFixed(1)} / ${kmGoal.toStringAsFixed(1)} km',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.green.shade100,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              streakDays > 0
                  ? 'Streak: $streakDays day${streakDays == 1 ? '' : 's'} in a row'
                  : 'Start a walk today to begin your streak!',
              style: theme.textTheme.bodySmall,
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
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
