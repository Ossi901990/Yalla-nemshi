// lib/screens/nearby_walks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/walk_event.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/ui_kit.dart';
import '../widgets/ui/floating_nav_bar.dart';
import '../widgets/walk_row.dart';
import 'walks/walks_map_view.dart';

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

  /// Open in map mode (e.g. from Home's "Open the map").
  final bool startOnMap;

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
    this.startOnMap = false,
  });

  @override
  State<NearbyWalksScreen> createState() => _NearbyWalksScreenState();
}

class _NearbyWalksScreenState extends State<NearbyWalksScreen> {
  _DateFilter _dateFilter = _DateFilter.all;
  _DistanceFilter _distanceFilter = _DistanceFilter.all;
  bool _interestedOnly = false;
  late bool _showMap = widget.startOnMap;

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

    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: _buildCompactFilters(context),
          ),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: _showMap
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.page,
                    ),
                    child: WalksMapView(
                      walks: upcoming,
                      onOpen: widget.onTapEvent,
                      onJoin: widget.onToggleJoin,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      AppSpace.xs,
                      AppSpace.page,
                      FloatingNavBar.reservedHeight,
                    ),
                    // +1 for the "load more" footer (or the empty-state card)
                    itemCount: upcoming.isEmpty ? 1 : upcoming.length + 1,
                    itemBuilder: (context, index) {
                      if (upcoming.isEmpty) {
                        return AppCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No walks match',
                                textScaler: AppText.headlineScaler(context),
                                style: AppText.display(
                                  24,
                                  color: p.text,
                                  weight: 750,
                                ),
                              ),
                              const SizedBox(height: AppSpace.sm),
                              Text(
                                'Try another date or distance, or turn off Interested.',
                                style: AppText.body(15, color: p.textMuted),
                              ),
                            ],
                          ),
                        );
                      }
                      if (index == upcoming.length) {
                        return _buildLoadMoreButton(context);
                      }
                      final e = upcoming[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: WalkRow(
                          walk: e,
                          onOpen: () => widget.onTapEvent(e),
                          onJoin: () => widget.onToggleJoin(e),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ===== LOAD MORE BUTTON =====

  Widget _buildLoadMoreButton(BuildContext context) {
    final p = AppPalette.of(context);
    if (!widget.hasMoreWalks && !widget.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Center(
          child: Text(
            "That's every walk nearby",
            style: AppText.body(14, color: p.textMuted),
          ),
        ),
      );
    }
    if (widget.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Center(
        child: OutlinedButton(
          onPressed: widget.onLoadMore,
          style: OutlinedButton.styleFrom(
            foregroundColor: p.text,
            side: BorderSide(color: p.border),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: AppText.body(15, weight: FontWeight.w700),
          ),
          child: const Text('Load more walks'),
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
                  icon: _interestedOnly
                      ? Icons.favorite
                      : Icons.favorite_border,
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
          const SizedBox(width: 8),
          _buildViewToggle(context),
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
    final p = AppPalette.of(context);
    final fg = selected ? AppPalette.ink : p.text;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: icon != null ? 12 : 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? AppPalette.lime : p.surface,
            borderRadius: BorderRadius.circular(AppSpace.radiusPill),
            border: Border.all(color: selected ? AppPalette.lime : p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.body(
                  14,
                  color: fg,
                  weight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// List / Map switch.
  Widget _buildViewToggle(BuildContext context) {
    final p = AppPalette.of(context);
    return Tooltip(
      message: _showMap ? 'Show list' : 'Show map',
      child: Semantics(
        button: true,
        label: _showMap ? 'Show list' : 'Show map',
        child: GestureDetector(
          onTap: () => setState(() => _showMap = !_showMap),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _showMap ? AppPalette.lime : p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _showMap ? AppPalette.lime : p.border),
            ),
            child: Icon(
              _showMap ? Icons.view_list_rounded : Icons.map_rounded,
              size: 20,
              color: _showMap ? AppPalette.ink : p.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    final p = AppPalette.of(context);
    final active = _distanceFilter != _DistanceFilter.all;
    return Tooltip(
      message: 'Distance filter',
      child: GestureDetector(
        onTap: () => _showDistanceFilterSheet(context),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? AppPalette.lime : p.surface,
            shape: BoxShape.circle,
            border: Border.all(color: active ? AppPalette.lime : p.border),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 20,
            color: active ? AppPalette.ink : p.text,
          ),
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
                          setState(
                            () => _distanceFilter = _DistanceFilter.short,
                          );
                          setModalState(() {});
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
                          setModalState(() {});
                        },
                      ),
                      _buildFilterChip(
                        context,
                        label: 'Over 6 km',
                        selected: _distanceFilter == _DistanceFilter.long,
                        onTap: () {
                          setState(
                            () => _distanceFilter = _DistanceFilter.long,
                          );
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
                        backgroundColor: AppPalette.lime,
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
        : (isDark
              ? Colors.white.withAlpha((0.06 * 255).round())
              : Colors.white);

    final border = selected
        ? (isDark
              ? Colors.white.withAlpha((0.18 * 255).round())
              : AppPalette.lime)
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
                  style:
                      Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ) ??
                      TextStyle(
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
