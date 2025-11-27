// lib/screens/nearby_walks_screen.dart
import 'package:flutter/material.dart';

import '../models/walk_event.dart';

enum _DateFilter { all, today, thisWeek }
enum _DistanceFilter { all, short, medium, long }

class NearbyWalksScreen extends StatefulWidget {
  final List<WalkEvent> events;
  final void Function(WalkEvent) onToggleJoin;
  final void Function(WalkEvent) onToggleInterested;
  final void Function(WalkEvent) onTapEvent;
  final void Function(WalkEvent) onCancelHosted;

  const NearbyWalksScreen({
    super.key,
    required this.events,
    required this.onToggleJoin,
    required this.onToggleInterested,
    required this.onTapEvent,
    required this.onCancelHosted,
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
    if (_dateFilter == _DateFilter.all) return true;

    if (_dateFilter == _DateFilter.today) {
      return _isSameDay(e.dateTime, _today);
    }

    if (_dateFilter == _DateFilter.thisWeek) {
      return _isInCurrentWeek(e.dateTime);
    }

    return true;
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

  @override
  Widget build(BuildContext context) {
    final upcoming = widget.events
        .where((e) => !e.cancelled && e.dateTime.isAfter(DateTime.now()))
        .where(_matchDateFilter)
        .where(_matchDistanceFilter)
        .where((e) => !_interestedOnly || e.interested)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby walks'),
      ),
      body: Column(
        children: [
          _buildFilters(context),
          const Divider(height: 1),
          Expanded(
            child: upcoming.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No walks match your filters.\nTry changing the date or distance filters.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: upcoming.length,
                    itemBuilder: (context, index) {
                      final e = upcoming[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(e.title)),
                              if (e.interested)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
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
                          subtitle: Text(_buildSubtitle(e)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Interested icon
                              IconButton(
                                icon: Icon(
                                  e.interested
                                      ? Icons.star
                                      : Icons.star_border_outlined,
                                  color: e.interested ? Colors.amber : null,
                                ),
                                tooltip: 'Mark as interested',
                                onPressed: () =>
                                    widget.onToggleInterested(e),
                              ),
                              // Join icon
                              IconButton(
                                icon: Icon(
                                  e.joined
                                      ? Icons.check_circle
                                      : Icons.add_circle_outline,
                                  color: e.joined ? Colors.green : null,
                                ),
                                tooltip:
                                    e.joined ? 'Leave walk' : 'Join walk',
                                onPressed: () => widget.onToggleJoin(e),
                              ),
                            ],
                          ),
                          onTap: () => widget.onTapEvent(e),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Date:',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('All'),
                selected: _dateFilter == _DateFilter.all,
                onSelected: (_) {
                  setState(() => _dateFilter = _DateFilter.all);
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Today'),
                selected: _dateFilter == _DateFilter.today,
                onSelected: (_) {
                  setState(() => _dateFilter = _DateFilter.today);
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('This week'),
                selected: _dateFilter == _DateFilter.thisWeek,
                onSelected: (_) {
                  setState(() => _dateFilter = _DateFilter.thisWeek);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Distance:',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('All'),
                selected: _distanceFilter == _DistanceFilter.all,
                onSelected: (_) {
                  setState(() => _distanceFilter = _DistanceFilter.all);
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('< 3 km'),
                selected: _distanceFilter == _DistanceFilter.short,
                onSelected: (_) {
                  setState(() => _distanceFilter = _DistanceFilter.short);
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('3–6 km'),
                selected: _distanceFilter == _DistanceFilter.medium,
                onSelected: (_) {
                  setState(() => _distanceFilter = _DistanceFilter.medium);
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('> 6 km'),
                selected: _distanceFilter == _DistanceFilter.long,
                onSelected: (_) {
                  setState(() => _distanceFilter = _DistanceFilter.long);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: _interestedOnly,
                onChanged: (val) {
                  setState(() => _interestedOnly = val ?? false);
                },
              ),
              const Text('Interested only'),
            ],
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(WalkEvent e) {
    final dt = e.dateTime;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');

    final dateStr = '$dd/$mm/$yyyy • $hh:$min';
    final details =
        '${e.distanceKm.toStringAsFixed(1)} km • ${e.gender}${e.meetingPlaceName != null ? ' • ${e.meetingPlaceName}' : ''}';

    return '$dateStr\n$details';
  }
}
