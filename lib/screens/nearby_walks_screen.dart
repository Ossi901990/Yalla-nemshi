// lib/screens/nearby_walks_screen.dart
import 'package:flutter/material.dart';

import '../models/walk_event.dart';
import 'profile_screen.dart';

enum _DateFilter { all, today, thisWeek }
enum _DistanceFilter { all, short, medium, long }

class NearbyWalksScreen extends StatefulWidget {
  final List<WalkEvent> events;
  final void Function(WalkEvent) onToggleJoin;
  final void Function(WalkEvent) onToggleInterested;
  final void Function(WalkEvent) onTapEvent;
  final void Function(WalkEvent) onCancelHosted;

  // ✅ stats for quick profile sheet + full profile screen
  final int walksJoined;
  final int eventsHosted;
  final double totalKm;
  final int interestedCount;
  final double weeklyKm;
  final int weeklyWalks;
  final int streakDays;
  final double weeklyGoalKm;
  final String userName;

  const NearbyWalksScreen({
    super.key,
    required this.events,
    required this.onToggleJoin,
    required this.onToggleInterested,
    required this.onTapEvent,
    required this.onCancelHosted,
    required this.walksJoined,
    required this.eventsHosted,
    required this.totalKm,
    required this.interestedCount,
    required this.weeklyKm,
    required this.weeklyWalks,
    required this.streakDays,
    required this.weeklyGoalKm,
    required this.userName,
  });

  @override
  State<NearbyWalksScreen> createState() => _NearbyWalksScreenState();
}

class _NearbyWalksScreenState extends State<NearbyWalksScreen> {
  _DateFilter _dateFilter = _DateFilter.all;
  _DistanceFilter _distanceFilter = _DistanceFilter.all;
  bool _interestedOnly = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart {
    final t = _today;
    return t.subtract(Duration(days: t.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInCurrentWeek(DateTime dt) {
    final start = _weekStart;
    final end = start.add(const Duration(days: 7));
    return !dt.isBefore(start) && dt.isBefore(end);
  }

  bool _matchDateFilter(WalkEvent e) {
    switch (_dateFilter) {
      case _DateFilter.all:
        return true;
      case _DateFilter.today:
        return _isSameDay(e.dateTime, _today);
      case _DateFilter.thisWeek:
        return _isInCurrentWeek(e.dateTime);
    }
  }

  bool _matchDistanceFilter(WalkEvent e) {
    const shortMax = 3.0;
    const mediumMax = 6.0;

    switch (_distanceFilter) {
      case _DistanceFilter.all:
        return true;
      case _DistanceFilter.short:
        return e.distanceKm < shortMax;
      case _DistanceFilter.medium:
        return e.distanceKm >= shortMax && e.distanceKm < mediumMax;
      case _DistanceFilter.long:
        return e.distanceKm >= mediumMax;
    }
  }

  // ===== SHEETS (same behaviour as Home) =====

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



  void _showProfileQuickSheet() {
    final theme = Theme.of(context);

    final totalWalks = widget.walksJoined + widget.eventsHosted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFBFEF8),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFCDE9B7),
                  child: const Icon(
                    Icons.person,
                    size: 32,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userName.isNotEmpty ? widget.userName : 'Walker',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick look at your progress',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _quickStat(
                      label: 'Walks',
                      value: totalWalks.toString(),
                    ),
                    _quickStat(
                      label: 'Total km',
                      value: widget.totalKm.toStringAsFixed(1),
                    ),
                    _quickStat(
                      label: 'Streak',
                      value: '${widget.streakDays}d',
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF14532D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // close sheet
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            walksJoined: widget.walksJoined,
                            eventsHosted: widget.eventsHosted,
                            totalKm: widget.totalKm,
                            weeklyWalks: widget.weeklyWalks,
                            weeklyKm: widget.weeklyKm,
                            weeklyGoalKm: widget.weeklyGoalKm,
                            streakDays: widget.streakDays,
                            interestedCount: widget.interestedCount,
                          ),
                        ),
                      );
                    },
                    child: const Text('View full profile'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            walksJoined: widget.walksJoined,
                            eventsHosted: widget.eventsHosted,
                            totalKm: widget.totalKm,
                            weeklyWalks: widget.weeklyWalks,
                            weeklyKm: widget.weeklyKm,
                            weeklyGoalKm: widget.weeklyGoalKm,
                            streakDays: widget.streakDays,
                            interestedCount: widget.interestedCount,
                          ),
                        ),
                      );
                    },
                    child: const Text('Edit profile info'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quickStat({required String label, required String value}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  // ===== BUILD =====

  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final upcoming = widget.events
      .where((e) => !e.cancelled && e.dateTime.isAfter(DateTime.now()))
      .where(_matchDateFilter)
      .where(_matchDistanceFilter)
      .where((e) => !_interestedOnly || e.interested)
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  return Scaffold(
    // same idea as HomeScreen
    backgroundColor:
        isDark ? const Color(0xFF0B1A13) : const Color(0xFF4F925C),
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ===== GREEN HEADER BAR (MATCH HOME) =====
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF020908), // darker top
                        Color(0xFF0B1A13), // darker bottom
                      ]
                    : const [
                        Color(0xFF294630), // top
                        Color(0xFF4F925C), // bottom
                      ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo + app name
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

                // Notifications + profile (tappable)
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showNotificationsSheet,
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
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showProfileQuickSheet,
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
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ===== MAIN SHEET WITH BG IMAGE (DARK + LIGHT) =====
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF020908)
                    : const Color(0xFFF7F9F2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                image: isDark
                    ? const DecorationImage(
                        image:
                            AssetImage('assets/images/bg_minimal_dark.png'),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      )
                    : const DecorationImage(
                        image:
                            AssetImage('assets/images/bg_minimal_light.png'),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
              ),
              // same overlay idea as Home so text stays readable
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.35)
                      : Colors.white.withOpacity(0.65),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Nearby walks',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Find walks happening around you and join with one tap.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filters card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildFiltersCard(context),
                    ),
                    const SizedBox(height: 8),

                    // Walk list
                    Expanded(
                      child: upcoming.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text(
                                  'No walks match your filters.\n'
                                  'Try changing the date or distance filters.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 8, 12, 16),
                              itemCount: upcoming.length,
                              itemBuilder: (context, index) {
                                final e = upcoming[index];
                                return _NearbyWalkCard(
                                  event: e,
                                  onToggleJoin: widget.onToggleJoin,
                                  onToggleInterested:
                                      widget.onToggleInterested,
                                  onTap: () => widget.onTapEvent(e),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  // ===== FILTER CARD =====

  Widget _buildFiltersCard(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    elevation: 0,
    // light vs dark card background
    color: isDark
        ? theme.colorScheme.surface.withOpacity(0.9)
        : const Color(0xFFF2F6EA),
    child: Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
            // Date row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date:',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        selected: _dateFilter == _DateFilter.all,
                        onTap: () {
                          setState(() => _dateFilter = _DateFilter.all);
                        },
                        showCheck: true,
                      ),
                      _buildFilterChip(
                        label: 'Today',
                        selected: _dateFilter == _DateFilter.today,
                        onTap: () {
                          setState(() => _dateFilter = _DateFilter.today);
                        },
                      ),
                      _buildFilterChip(
                        label: 'This week',
                        selected: _dateFilter == _DateFilter.thisWeek,
                        onTap: () {
                          setState(() => _dateFilter = _DateFilter.thisWeek);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Distance row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distance:',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        selected: _distanceFilter == _DistanceFilter.all,
                        onTap: () {
                          setState(() => _distanceFilter = _DistanceFilter.all);
                        },
                        showCheck: true,
                      ),
                      _buildFilterChip(
                        label: '< 3 km',
                        selected: _distanceFilter == _DistanceFilter.short,
                        onTap: () {
                          setState(
                              () => _distanceFilter = _DistanceFilter.short);
                        },
                      ),
                      _buildFilterChip(
                        label: '3–6 km',
                        selected: _distanceFilter == _DistanceFilter.medium,
                        onTap: () {
                          setState(
                              () => _distanceFilter = _DistanceFilter.medium);
                        },
                      ),
                      _buildFilterChip(
                        label: '> 6 km',
                        selected: _distanceFilter == _DistanceFilter.long,
                        onTap: () {
                          setState(() => _distanceFilter = _DistanceFilter.long);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Interested only
            Row(
              children: [
                Checkbox(
                  value: _interestedOnly,
                  onChanged: (val) {
                    setState(() => _interestedOnly = val ?? false);
                  },
                  visualDensity: VisualDensity.compact,
                ),
                const Text('Interested only'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool showCheck = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFCDE9B7) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF4F925C)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCheck && selected) ...[
              const Icon(
                Icons.check,
                size: 14,
                color: Color(0xFF1F2933),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? const Color(0xFF1F2933)
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== NEARBY WALK CARD =====

class _NearbyWalkCard extends StatelessWidget {
  final WalkEvent event;
  final void Function(WalkEvent) onToggleJoin;
  final void Function(WalkEvent) onToggleInterested;
  final VoidCallback onTap;

  const _NearbyWalkCard({
    required this.event,
    required this.onToggleJoin,
    required this.onToggleInterested,
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              // Small avatar / distance bubble
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE5F3D9),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${event.distanceKm.toStringAsFixed(1)}\nkm',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2933),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (event.interested)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Interested',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(event.dateTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.gender} • '
                      '${event.meetingPlaceName ?? 'Meeting point TBA'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // Icons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      event.interested
                          ? Icons.star
                          : Icons.star_border_outlined,
                      color: event.interested ? Colors.amber : null,
                      size: 20,
                    ),
                    tooltip: 'Mark as interested',
                    onPressed: () => onToggleInterested(event),
                  ),
                  IconButton(
                    icon: Icon(
                      event.joined
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      color: event.joined ? Colors.green : null,
                      size: 20,
                    ),
                    tooltip: event.joined ? 'Leave walk' : 'Join walk',
                    onPressed: () => onToggleJoin(event),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
