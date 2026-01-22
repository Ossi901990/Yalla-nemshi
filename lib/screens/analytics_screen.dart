import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_summary.dart';
import '../services/analytics_service.dart';
import '../services/friend_profile_service.dart';
import '../services/friends_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  static const routeName = '/analytics';

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService.instance;
  final FriendsService _friendsService = FriendsService();
  final DateFormat _rangeFormat = DateFormat('MMM d, yyyy');

  AnalyticsPreset _preset = AnalyticsPreset.last7Days;
  late DateTimeRange _range;
  Future<MyAnalyticsSummary>? _mySummaryFuture;
  Future<FriendAnalyticsSummary>? _friendSummaryFuture;
  bool _loadingFriends = true;
  List<FriendOption> _friends = const [];
  String? _selectedFriendId;

  @override
  void initState() {
    super.initState();
    _range = _rangeForPreset(_preset);
    _refreshMySummary();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _friends = const [];
          _loadingFriends = false;
        });
        return;
      }
      final friendIds = await _friendsService.getFriends(uid);
      final options = <FriendOption>[];
      for (final friendId in friendIds) {
        final profile = await FriendProfileService.fetchProfile(friendId);
        final name = profile?.displayName ?? 'Friend';
        options.add(FriendOption(uid: friendId, displayName: name));
      }
      if (!mounted) return;
      setState(() {
        _friends = options;
        _loadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friends = const [];
        _loadingFriends = false;
      });
    }
  }

  void _refreshMySummary() {
    setState(() {
      _mySummaryFuture = _analyticsService.getMyAnalyticsSummary(
        start: _range.start,
        end: _range.end,
      );
    });
    if (_selectedFriendId != null) {
      _refreshFriendSummary(_selectedFriendId!);
    }
  }

  void _refreshFriendSummary(String friendId) {
    setState(() {
      _friendSummaryFuture = _analyticsService.getFriendAnalyticsSummary(
        friendUid: friendId,
        start: _range.start,
        end: _range.end,
      );
    });
  }

  void _onPresetSelected(AnalyticsPreset preset) {
    setState(() {
      _preset = preset;
      _range = _rangeForPreset(preset);
    });
    _refreshMySummary();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() {
      _preset = AnalyticsPreset.custom;
      _range = picked;
    });
    _refreshMySummary();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: FutureBuilder<MyAnalyticsSummary>(
        future: _mySummaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 36, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Something went wrong while loading analytics.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refreshMySummary,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final summary = snapshot.data ??
              const MyAnalyticsSummary(
                totalWalks: 0,
                totalDistanceKm: 0,
                totalMinutes: 0,
                dailyBuckets: [],
                averagePaceMinutesPerKm: null,
                averageSpeedKmh: null,
                maxSpeedKmh: null,
              );

          return RefreshIndicator(
            onRefresh: () async {
              _refreshMySummary();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildDateRangeSection(theme),
                const SizedBox(height: 16),
                _buildMyStatsCard(theme, summary),
                const SizedBox(height: 16),
                _buildCharts(theme, summary),
                const SizedBox(height: 24),
                _buildComparisonSection(theme, summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date range',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AnalyticsPreset.values.map((preset) {
                final label = _presetLabel(preset);
                return ChoiceChip(
                  label: Text(label),
                  selected: _preset == preset,
                  onSelected: (_) {
                    if (preset == AnalyticsPreset.custom) {
                      _pickCustomRange();
                    } else {
                      _onPresetSelected(preset);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_rangeFormat.format(_range.start)} → ${_rangeFormat.format(_range.end)}',
                  style: theme.textTheme.bodyMedium,
                ),
                TextButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Custom range'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStatsCard(ThemeData theme, MyAnalyticsSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My stats',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatTile(
                  label: 'Total walks',
                  value: summary.totalWalks.toString(),
                  icon: Icons.directions_walk,
                ),
                _StatTile(
                  label: 'Distance',
                  value: _formatDistance(summary.totalDistanceKm),
                  icon: Icons.route,
                ),
                _StatTile(
                  label: 'Time',
                  value: _formatMinutes(summary.totalMinutes),
                  icon: Icons.timer,
                ),
                _StatTile(
                  label: 'Avg pace',
                  value: _formatPace(summary.averagePaceMinutesPerKm),
                  icon: Icons.speed,
                ),
                _StatTile(
                  label: 'Avg speed',
                  value: _formatSpeed(summary.averageSpeedKmh),
                  icon: Icons.directions_run,
                ),
                _StatTile(
                  label: 'Max speed',
                  value: _formatSpeed(summary.maxSpeedKmh),
                  icon: Icons.bolt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts(ThemeData theme, MyAnalyticsSummary summary) {
    final buckets = summary.dailyBuckets;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distance over time',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _AnalyticsBarChart(
                  buckets: buckets,
                  valueBuilder: (bucket) => bucket.distanceKm,
                  valueFormatter: _formatDistance,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Walk count per day',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _AnalyticsBarChart(
                  buckets: buckets,
                  valueBuilder: (bucket) => bucket.walkCount.toDouble(),
                  valueFormatter: (value) => value.toStringAsFixed(0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonSection(ThemeData theme, MyAnalyticsSummary mySummary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Social comparison',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_loadingFriends)
              const LinearProgressIndicator()
            else if (_friends.isEmpty)
              Text(
                'Add friends to compare your progress.',
                style: theme.textTheme.bodyMedium,
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedFriendId,
                items: _friends
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.uid,
                        child: Text(option.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFriendId = value;
                  });
                  if (value != null) {
                    _refreshFriendSummary(value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Compare with',
                ),
              ),
            if (_selectedFriendId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FutureBuilder<FriendAnalyticsSummary>(
                  future: _friendSummaryFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Unable to load comparison data right now.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
                      );
                    }
                    final friendSummary = snapshot.data;
                    if (friendSummary == null || !friendSummary.hasData) {
                      return const Text('No shared data for this friend yet.');
                    }
                    return Column(
                      children: [
                        _ComparisonRow(
                          label: 'Distance',
                          myValue: _formatDistance(mySummary.totalDistanceKm),
                          friendValue: _formatDistance(friendSummary.totalDistanceKm),
                        ),
                        _ComparisonRow(
                          label: 'Walks',
                          myValue: mySummary.totalWalks.toString(),
                          friendValue: friendSummary.totalWalks.toString(),
                        ),
                        _ComparisonRow(
                          label: 'Avg pace',
                          myValue: _formatPace(mySummary.averagePaceMinutesPerKm),
                          friendValue: _formatPace(friendSummary.averagePaceMinutesPerKm),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  DateTimeRange _rangeForPreset(AnalyticsPreset preset) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case AnalyticsPreset.last7Days:
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 6)),
          end: _endOfDay(todayStart),
        );
      case AnalyticsPreset.last30Days:
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 29)),
          end: _endOfDay(todayStart),
        );
      case AnalyticsPreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: _endOfDay(todayStart));
      case AnalyticsPreset.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case AnalyticsPreset.custom:
        return DateTimeRange(start: todayStart.subtract(const Duration(days: 6)), end: _endOfDay(todayStart));
    }
  }

  String _presetLabel(AnalyticsPreset preset) {
    switch (preset) {
      case AnalyticsPreset.last7Days:
        return 'Last 7 days';
      case AnalyticsPreset.last30Days:
        return 'Last 30 days';
      case AnalyticsPreset.thisMonth:
        return 'This month';
      case AnalyticsPreset.lastMonth:
        return 'Last month';
      case AnalyticsPreset.custom:
        return 'Custom';
    }
  }

  String _formatDistance(double value) => '${value.toStringAsFixed(1)} km';

  String _formatMinutes(double minutes) {
    if (minutes <= 0) return '0 min';
    final hours = minutes ~/ 60;
    final mins = (minutes % 60).round();
    if (hours <= 0) {
      return '$mins min';
    }
    return '${hours}h ${mins}m';
  }

  String _formatPace(double? pace) {
    if (pace == null || pace.isNaN || pace.isInfinite) return '--';
    return '${pace.toStringAsFixed(1)} min/km';
  }

  String _formatSpeed(double? speed) {
    if (speed == null || speed.isNaN || speed.isInfinite) return '--';
    return '${speed.toStringAsFixed(1)} km/h';
  }

  DateTime _endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsBarChart extends StatelessWidget {
  const _AnalyticsBarChart({
    required this.buckets,
    required this.valueBuilder,
    required this.valueFormatter,
  });

  final List<DailyAnalyticsBucket> buckets;
  final double Function(DailyAnalyticsBucket) valueBuilder;
  final String Function(double) valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const Text('No data yet.');
    }

    final values = buckets.map(valueBuilder).toList();
    final maxValue = values.fold<double>(0, math.max);
    if (maxValue <= 0) {
      return const Text('No data yet.');
    }

    return SizedBox(
      height: 180,
      child: Scrollbar(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: buckets.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final bucket = buckets[index];
            final value = values[index];
            final heightFactor = value / maxValue;
            final showLabel = buckets.length <= 10 || index.isEven;
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  valueFormatter(value),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 24,
                  height: 120 * heightFactor,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                if (showLabel)
                  Text(
                    bucket.label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.myValue,
    required this.friendValue,
  });

  final String label;
  final String myValue;
  final String friendValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _ComparisonValueTile(
                        label: 'You',
                        value: myValue,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ComparisonValueTile(
                        label: 'Friend',
                        value: friendValue,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonValueTile extends StatelessWidget {
  const _ComparisonValueTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

enum AnalyticsPreset {
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom,
}
