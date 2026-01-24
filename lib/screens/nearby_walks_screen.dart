// lib/screens/nearby_walks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/walk_event.dart';

// ===== Design tokens (match HomeScreen) =====

// Radius
const double kRadiusCard = 24;
const double kRadiusControl = 16;
const double kRadiusPill = 999;

// ===== Dark Theme (match HomeScreen) palette =====
const kDarkBg = Color(0xFF071B26); // primary background
const kDarkSurface = Color(0xFF0C2430); // cards / sheets
const kDarkSurface2 = Color(0xFF0E242E); // secondary surfaces

const kTextPrimary = Color(0xFFD9F5EA);
const kTextSecondary = Color(0xFF9BB9B1);
const kTextMuted = Color(0xFF6A8580);

// Spacing
const double kSpace1 = 8;
const double kSpace2 = 16;
const double kSpace3 = 24;
const double kSpace4 = 32;

// Cards
const kLightSurface = Color(0xFFFBFEF8);
const double kCardElevationLight = 0.6;
const double kCardElevationDark = 0.0;
const double kCardBorderAlpha = 0.06;

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

  // Pagination
  final bool hasMoreWalks;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

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
    required this.hasMoreWalks,
    required this.isLoadingMore,
    required this.onLoadMore,
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

  // ===== BUILD =====

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final upcoming = <WalkEvent>[];
    for (final event in widget.events) {
      if (event.cancelled) {
        _debugNearbyDrop(event, 'cancelled flag');
        continue;
      }
      if (!event.dateTime.isAfter(now)) {
        _debugNearbyDrop(event, 'past event');
        continue;
      }
      if (!_matchDateFilter(event)) {
        _debugNearbyDrop(event, 'date filter $_dateFilter');
        continue;
      }
      if (!_matchDistanceFilter(event)) {
        _debugNearbyDrop(event, 'distance filter $_distanceFilter');
        continue;
      }
      if (_interestedOnly && !event.interested) {
        _debugNearbyDrop(event, 'interested filter');
        continue;
      }
      upcoming.add(event);
    }
    upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    _logNearbySummary(total: widget.events.length, kept: upcoming.length);

    return Scaffold(
      // ✅ Match HomeScreen background colors
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFFFBFEF8),

      body: Column(
        children: [
          // Header removed for Nearby tab to keep list content flush
          const SizedBox(height: 0),

          // ===== MAIN AREA (background) =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(kRadiusCard),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(kRadiusCard),
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
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    kSpace2,
                    kSpace2,
                    kSpace2,
                    kSpace2,
                  ),
                  child: Card(
                    color: isDark ? kDarkSurface : kLightSurface,
                    elevation: isDark
                        ? kCardElevationDark
                        : kCardElevationLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withAlpha((kCardBorderAlpha * 255).round()),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        kSpace2,
                        kSpace3,
                        kSpace2,
                        kSpace2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby walks',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Find walks happening around you and join with one tap.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCompactFilters(context),
                          const SizedBox(height: 12),
                          Expanded(
                            child: upcoming.isEmpty
                                ? Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Text(
                                        'No walks match your filters.\n'
                                        'Try changing the date or distance filters.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      0,
                                      6,
                                      0,
                                      8,
                                    ),
                                    itemCount: upcoming.length + 1, // +1 for load more button
                                    itemBuilder: (context, index) {
                                      // Show load more button at the end
                                      if (index == upcoming.length) {
                                        return _buildLoadMoreButton(context);
                                      }
                                      
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== LOAD MORE BUTTON =====

  Widget _buildLoadMoreButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Don't show button if no more walks or currently loading
    if (!widget.hasMoreWalks && !widget.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            '✓ All walks loaded',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
      );
    }

    // Show loading indicator while loading
    if (widget.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show "Load More" button
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: widget.onLoadMore,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusControl),
            ),
            side: BorderSide(
              color: isDark 
                  ? Colors.white.withAlpha((0.2 * 255).round())
                  : Colors.black.withAlpha((0.2 * 255).round()),
            ),
          ),
          child: Text(
            'Load more walks',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? kTextSecondary : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // ===== COMPACT HORIZONTAL FILTERS =====

  Widget _buildCompactFilters(BuildContext context) {

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // Date filter chips (horizontal scroll)
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCompactChip(
                  context,
                  label: 'All dates',
                  icon: Icons.calendar_today,
                  selected: _dateFilter == _DateFilter.all,
                  onTap: () {
                    setState(() => _dateFilter = _DateFilter.all);
                  },
                ),
                const SizedBox(width: 8),
                _buildCompactChip(
                  context,
                  label: 'Today',
                  selected: _dateFilter == _DateFilter.today,
                  onTap: () {
                    setState(() => _dateFilter = _DateFilter.today);
                  },
                ),
                const SizedBox(width: 8),
                _buildCompactChip(
                  context,
                  label: 'This week',
                  selected: _dateFilter == _DateFilter.thisWeek,
                  onTap: () {
                    setState(() => _dateFilter = _DateFilter.thisWeek);
                  },
                ),
                const SizedBox(width: 8),
                // Interested toggle
                _buildCompactChip(
                  context,
                  label: 'Interested',
                  icon: _interestedOnly ? Icons.favorite : Icons.favorite_border,
                  selected: _interestedOnly,
                  onTap: () {
                    setState(() => _interestedOnly = !_interestedOnly);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // More filters button (opens bottom sheet)
          _buildFilterButton(context),
        ],
      ),
    );
  }

  Widget _buildCompactChip(
    BuildContext context, {
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = selected
        ? const Color(0xFF1ABFC4)
        : (isDark
              ? Colors.white.withAlpha((0.08 * 255).round())
              : Colors.white);

    final textColor = selected
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF374151));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 12 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: selected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withAlpha((0.15 * 255).round())
                      : Colors.black.withAlpha((0.1 * 255).round()),
                  width: 1,
                ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1ABFC4).withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show badge if distance filter is active
    final hasDistanceFilter = _distanceFilter != _DistanceFilter.all;

    return GestureDetector(
      onTap: () => _showDistanceFilterSheet(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: hasDistanceFilter
              ? const Color(0xFF1ABFC4)
              : (isDark
                    ? Colors.white.withAlpha((0.08 * 255).round())
                    : Colors.white),
          borderRadius: BorderRadius.circular(kRadiusPill),
          border: hasDistanceFilter
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withAlpha((0.15 * 255).round())
                      : Colors.black.withAlpha((0.1 * 255).round()),
                  width: 1,
                ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.tune,
                size: 20,
                color: hasDistanceFilter
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF374151)),
              ),
            ),
            if (hasDistanceFilter)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00D97E),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== DISTANCE FILTER BOTTOM SHEET =====

  void _showDistanceFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? kDarkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(kRadiusCard),
                ),
              ),
              padding: EdgeInsets.fromLTRB(kSpace2, kSpace2, kSpace2, kSpace3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withAlpha((0.2 * 255).round())
                            : Colors.black.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Distance',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Distance options
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        context,
                        label: 'All distances',
                        selected: _distanceFilter == _DistanceFilter.all,
                        onTap: () {
                          setState(() => _distanceFilter = _DistanceFilter.all);
                          setModalState(() {});
                        },
                        showCheck: true,
                      ),
                      _buildFilterChip(
                        context,
                        label: 'Under 3 km',
                        selected: _distanceFilter == _DistanceFilter.short,
                        onTap: () {
                          setState(() => _distanceFilter = _DistanceFilter.short);
                          setModalState(() {});
                        },
                      ),
                      _buildFilterChip(
                        context,
                        label: '3–6 km',
                        selected: _distanceFilter == _DistanceFilter.medium,
                        onTap: () {
                          setState(() => _distanceFilter = _DistanceFilter.medium);
                          setModalState(() {});
                        },
                      ),
                      _buildFilterChip(
                        context,
                        label: 'Over 6 km',
                        selected: _distanceFilter == _DistanceFilter.long,
                        onTap: () {
                          setState(() => _distanceFilter = _DistanceFilter.long);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1ABFC4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kRadiusPill),
                        ),
                      ),
                      child: const Text(
                        'Apply filters',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===== OLD FILTER CARD (KEPT FOR _buildFilterChip) =====

  // ignore: unused_element
  Widget _buildFiltersCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark ? kDarkSurface : kLightSurface,

      elevation: isDark ? kCardElevationDark : kCardElevationLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withAlpha((kCardBorderAlpha * 255).round()),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(kSpace2, 12, kSpace2, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 70,
                    maxWidth: 100,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Date:',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        context,
                        label: 'All',
                        selected: _dateFilter == _DateFilter.all,
                        onTap: () {
                          setState(() => _dateFilter = _DateFilter.all);
                        },
                        showCheck: true,
                      ),
                      _buildFilterChip(
                        context,
                        label: 'Today',
                        selected: _dateFilter == _DateFilter.today,
                        onTap: () {
                          setState(() => _dateFilter = _DateFilter.today);
                        },
                      ),
                      _buildFilterChip(
                        context,
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
            const SizedBox(height: 12),

            // Distance row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 70,
                    maxWidth: 100,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Distance:',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        context,
                        label: 'All',
                        selected: _distanceFilter == _DistanceFilter.all,
                        onTap: () {
                          setState(() => _distanceFilter = _DistanceFilter.all);
                        },
                        showCheck: true,
                      ),
                      _buildFilterChip(
                        context,
                        label: '< 3 km',
                        selected: _distanceFilter == _DistanceFilter.short,
                        onTap: () {
                          setState(
                            () => _distanceFilter = _DistanceFilter.short,
                          );
                        },
                      ),
                      _buildFilterChip(
                        context,
                        label: '3–6 km',
                        selected: _distanceFilter == _DistanceFilter.medium,
                        onTap: () {
                          setState(
                            () => _distanceFilter = _DistanceFilter.medium,
                          );
                        },
                      ),
                      _buildFilterChip(
                        context,
                        label: '> 6 km',
                        selected: _distanceFilter == _DistanceFilter.long,
                        onTap: () {
                          setState(
                            () => _distanceFilter = _DistanceFilter.long,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Checkbox(
                  value: _interestedOnly,
                  onChanged: (val) =>
                      setState(() => _interestedOnly = val ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Interested only',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool showCheck = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = selected
        ? (isDark ? const Color(0xFF123647) : const Color(0xFFCDE9B7))
        : (isDark ? Colors.white.withAlpha((0.06 * 255).round()) : Colors.white);

    final border = selected
        ? (isDark ? Colors.white.withAlpha((0.18 * 255).round()) : const Color(0xFF1ABFC4))
        : (isDark
              ? Colors.white.withAlpha((0.12 * 255).round())
              : Colors.grey.withAlpha((0.30 * 255).round()));

    final textColor = selected
        ? (isDark ? Colors.white : const Color(0xFF1F2933))
        : (isDark ? Colors.white70 : const Color(0xFF374151));

    final iconColor = isDark ? Colors.white : const Color(0xFF1F2933);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCheck && selected) ...[
                Icon(Icons.check, size: 14, color: iconColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ) ?? TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logNearbySummary({required int total, required int kept}) {
    if (!kDebugMode) return;
    final dropped = total - kept;
    debugPrint(
      '📋 NEARBY SUMMARY total=$total kept=$kept dropped=$dropped dateFilter=$_dateFilter distanceFilter=$_distanceFilter interestedOnly=$_interestedOnly',
    );
  }

  void _debugNearbyDrop(WalkEvent event, String reason) {
    if (!kDebugMode) return;
    final identifier = event.id.isNotEmpty ? event.id : event.firestoreId;
    debugPrint(
      '🚫 NEARBY DROP id=$identifier reason=$reason city=${event.city} dateTime=${event.dateTime} distanceKm=${event.distanceKm} visibility=${event.visibility} meeting=${event.meetingPlaceName}',
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
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark ? kDarkSurface : kLightSurface,
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isDark ? kCardElevationDark : kCardElevationLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusControl),
        side: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withAlpha((kCardBorderAlpha * 255).round()),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusControl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2933),
                  ) ?? const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2933),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (event.isRecurring && !event.isRecurringTemplate)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
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
                        if (event.interested) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kSpace1,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha((0.15 * 255).round()),
                                borderRadius: BorderRadius.circular(
                                  kRadiusPill,
                                ),
                              ),
                              child: Text(
                                'Interested',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ) ?? const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(event.dateTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.meetingPlaceName != null
                          ? '${event.gender} • ${event.meetingPlaceName}'
                          : (event.startLat != null && event.startLng != null
                                ? '${event.gender} • Start ${event.startLat!.toStringAsFixed(2)},${event.startLng!.toStringAsFixed(2)}'
                                : '${event.gender} • Meeting point TBA'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // ✅ Action buttons (simple, clean; better dark-mode contrast)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      event.interested
                          ? Icons.star
                          : Icons.star_border_outlined,
                      color: event.interested
                          ? Colors.amber
                          : (isDark ? Colors.white70 : const Color(0xFF374151)),
                      size: 22,
                    ),
                    tooltip: 'Mark as interested',
                    onPressed: () => onToggleInterested(event),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      event.joined
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      color: event.joined
                          ? const Color(0xFF00D97E)
                          : (isDark ? Colors.white70 : const Color(0xFF374151)),
                      size: 22,
                    ),
                    tooltip: event.joined
                      ? (event.status == 'active'
                        ? 'Leave Walk'
                        : 'Cancel Join')
                      : 'Join walk',
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


