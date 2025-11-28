// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/walk_event.dart';
import '../services/notification_service.dart';

import 'create_walk_screen.dart';
import 'event_details_screen.dart';
import 'nearby_walks_screen.dart';
import 'profile_screen.dart';
//test
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  /// All events (hosted by user + nearby).
  final List<WalkEvent> _events = [
    // Example seed data (you can remove or change)
    WalkEvent(
      id: '1',
      title: 'Sunset walk at Corniche',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      distanceKm: 4.5,
      gender: 'Mixed',
      isOwner: true,
      joined: true,
      meetingPlaceName: 'Corniche, Doha',
      description: 'Chill sunset walk along the sea.',
    ),
    WalkEvent(
      id: '2',
      title: 'Morning park loop',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      distanceKm: 3.0,
      gender: 'Women only',
      isOwner: false,
      joined: false,
      meetingPlaceName: 'Al Bidda park',
    ),
  ];

  // --- Derived views & helpers ---

  List<WalkEvent> get _myHostedWalks =>
      _events.where((e) => e.isOwner && !e.cancelled).toList();

  List<WalkEvent> get _nearbyWalks =>
      _events.where((e) => !e.isOwner && !e.cancelled).toList();

  int get _walksJoined =>
      _events.where((e) => e.joined && !e.cancelled).length;

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
        return d.year == day.year &&
            d.month == day.month &&
            d.day == day.day;
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
      return ed.year == d0.year &&
          ed.month == d0.month &&
          ed.day == d0.day;
    }).toList();
  }

  // --- Actions ---

  void _onEventCreated(WalkEvent newEvent) {
    setState(() {
      _events.add(newEvent);
    });
  }

  void _toggleJoin(WalkEvent event) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index == -1) return;
      final current = _events[index];
      _events[index] = current.copyWith(joined: !current.joined);
    });
  }

  void _toggleInterested(WalkEvent event) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index == -1) return;
      final current = _events[index];
      _events[index] =
          current.copyWith(interested: !current.interested);
    });
  }

  void _cancelHostedWalk(WalkEvent event) {
    setState(() {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index == -1) return;
      final current = _events[index];
      _events[index] = current.copyWith(cancelled: true);
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

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    Widget body;

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

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This week',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _WeeklySummaryCard(
                    walks: _weeklyWalkCount,
                    kmSoFar: _weeklyKm,
                    kmGoal: _weeklyGoalKm,
                    streakDays: _streakDays,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome 👋',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find people near you to walk with, create events, and earn badges.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openCreateWalk,
                      icon: const Icon(Icons.add_road),
                      label: const Text('Start a walking event'),
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
                          child: const Text('Find nearby walks'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _currentTab = 2);
                          },
                          child: const Text('Friends'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),


                  const SizedBox(height: 16),
                  Text(
                    'Your quick stats',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 24),
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: DateTime.now(),
                    calendarFormat: CalendarFormat.week,

                    // ✅ Only show dots for joined/hosted walks (not every event in the world)
                    eventLoader: (day) => _eventsForDay(day),

                    onDaySelected: (selectedDay, focusedDay) {
                      final events = _eventsForDay(selectedDay);
                      if (events.isNotEmpty) {
                        _navigateToDetails(events.first);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your walks',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_myHostedWalks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No walks yet.\nGo to the Create tab and add your first walk!',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: _myHostedWalks.length,
              itemBuilder: (context, index) {
                final e = _myHostedWalks[index];
                return _WalkCard(
                  event: e,
                  onTap: () => _navigateToDetails(e),
                );
              },
            ),
        ],
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
    final progress = (kmGoal == 0) ? 0.0 : (kmSoFar / kmGoal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$walks walk${walks == 1 ? '' : 's'} • '
              '${kmSoFar.toStringAsFixed(1)} / ${kmGoal.toStringAsFixed(1)} km',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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

  const _StatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
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

  const _WalkCard({
    required this.event,
    required this.onTap,
  });

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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          event.title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatDateTime(event.dateTime),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
