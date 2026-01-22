import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/analytics_summary.dart';
import 'crash_service.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<MyAnalyticsSummary> getMyAnalyticsSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final rangeStart = _startOfDay(start);
    final rangeEnd = _endOfDay(end);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return _emptyMySummary(rangeStart, rangeEnd);
      }

      final startTs = Timestamp.fromDate(rangeStart);
      final endTs = Timestamp.fromDate(rangeEnd);

      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(uid)
          .collection('walks')
          .where('completed', isEqualTo: true)
          .where(
            Filter.or(
              Filter.and(
                Filter('completedAt', isGreaterThanOrEqualTo: startTs),
                Filter('completedAt', isLessThanOrEqualTo: endTs),
              ),
              Filter.and(
                Filter('completedAt', isNull: true),
                Filter('joinedAt', isGreaterThanOrEqualTo: startTs),
                Filter('joinedAt', isLessThanOrEqualTo: endTs),
              ),
            ),
          );

      final snapshot = await query.get();
      final rows = snapshot.docs
          .map(_normalizeUserWalk)
          .whereType<_WalkAnalyticsRow>()
          .toList();

      return _buildMySummary(rows, rangeStart, rangeEnd);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'AnalyticsService.getMyAnalyticsSummary',
      );
      return _emptyMySummary(rangeStart, rangeEnd);
    }
  }

  Future<FriendAnalyticsSummary> getFriendAnalyticsSummary({
    required String friendUid,
    required DateTime start,
    required DateTime end,
  }) async {
    final rangeStart = _startOfDay(start);
    final rangeEnd = _endOfDay(end);
    try {
      final startTs = Timestamp.fromDate(rangeStart);
      final endTs = Timestamp.fromDate(rangeEnd);

      Query<Map<String, dynamic>> query = _firestore
          .collection('friend_profiles')
          .doc(friendUid)
          .collection('walk_summaries')
          .where('category', isEqualTo: 'past')
          .where(
            Filter.or(
              Filter.and(
                Filter('endTime', isGreaterThanOrEqualTo: startTs),
                Filter('endTime', isLessThanOrEqualTo: endTs),
              ),
              Filter.and(
                Filter('endTime', isNull: true),
                Filter('startTime', isGreaterThanOrEqualTo: startTs),
                Filter('startTime', isLessThanOrEqualTo: endTs),
              ),
            ),
          );

      final snapshot = await query.get();
      final rows = snapshot.docs
          .map(_normalizeFriendWalk)
          .whereType<_WalkAnalyticsRow>()
          .toList();

      return _buildFriendSummary(rows, rangeStart, rangeEnd);
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'AnalyticsService.getFriendAnalyticsSummary',
      );
      return FriendAnalyticsSummary.empty(rangeStart, rangeEnd);
    }
  }

  MyAnalyticsSummary _buildMySummary(
    List<_WalkAnalyticsRow> rows,
    DateTime start,
    DateTime end,
  ) {
    if (rows.isEmpty) {
      return _emptyMySummary(start, end);
    }

    final totalDistance = rows.fold<double>(0, (acc, row) => acc + row.distanceKm);
    final totalMinutes = rows.fold<double>(0, (acc, row) => acc + row.minutes);
    final maxSpeed = rows.fold<double?>(null, (current, row) {
      if (row.maxSpeedKmh == null) return current;
      if (current == null) return row.maxSpeedKmh;
      return row.maxSpeedKmh! > current ? row.maxSpeedKmh : current;
    });

    final averagePace = totalDistance <= 0
        ? null
        : (totalMinutes <= 0 ? null : totalMinutes / totalDistance);
    final averageSpeed = totalMinutes <= 0
        ? null
        : (totalDistance <= 0 ? null : totalDistance / (totalMinutes / 60));

    final buckets = _buildBuckets(rows, start, end);

    return MyAnalyticsSummary(
      totalWalks: rows.length,
      totalDistanceKm: double.parse(totalDistance.toStringAsFixed(2)),
      totalMinutes: double.parse(totalMinutes.toStringAsFixed(1)),
      averagePaceMinutesPerKm:
          averagePace == null ? null : double.parse(averagePace.toStringAsFixed(2)),
      averageSpeedKmh:
          averageSpeed == null ? null : double.parse(averageSpeed.toStringAsFixed(2)),
      maxSpeedKmh: maxSpeed == null ? null : double.parse(maxSpeed.toStringAsFixed(2)),
      dailyBuckets: buckets,
    );
  }

  MyAnalyticsSummary _emptyMySummary(DateTime start, DateTime end) {
    return MyAnalyticsSummary(
      totalWalks: 0,
      totalDistanceKm: 0,
      totalMinutes: 0,
      dailyBuckets: _seedBuckets(start, end),
      averagePaceMinutesPerKm: null,
      averageSpeedKmh: null,
      maxSpeedKmh: null,
    );
  }

  FriendAnalyticsSummary _buildFriendSummary(
    List<_WalkAnalyticsRow> rows,
    DateTime start,
    DateTime end,
  ) {
    if (rows.isEmpty) {
      return FriendAnalyticsSummary.empty(start, end);
    }

    final totalDistance = rows.fold<double>(0, (acc, row) => acc + row.distanceKm);
    final totalMinutes = rows.fold<double>(0, (acc, row) => acc + row.minutes);
    final averagePace = totalDistance <= 0
        ? null
        : (totalMinutes <= 0 ? null : totalMinutes / totalDistance);
    final averageSpeed = totalMinutes <= 0
        ? null
        : (totalDistance <= 0 ? null : totalDistance / (totalMinutes / 60));

    final buckets = _buildBuckets(rows, start, end);

    return FriendAnalyticsSummary(
      totalWalks: rows.length,
      totalDistanceKm: double.parse(totalDistance.toStringAsFixed(2)),
      totalMinutes: double.parse(totalMinutes.toStringAsFixed(1)),
      averagePaceMinutesPerKm:
          averagePace == null ? null : double.parse(averagePace.toStringAsFixed(2)),
      averageSpeedKmh:
          averageSpeed == null ? null : double.parse(averageSpeed.toStringAsFixed(2)),
      dailyBuckets: buckets,
    );
  }

  List<DailyAnalyticsBucket> _buildBuckets(
    List<_WalkAnalyticsRow> rows,
    DateTime start,
    DateTime end,
  ) {
    final buckets = {for (final bucket in _seedBuckets(start, end)) _bucketKey(bucket.date): bucket};

    for (final row in rows) {
      final key = _bucketKey(row.occurredAt);
      final existing = buckets[key];
      if (existing == null) continue;
      buckets[key] = existing.copyWith(
        distanceKm: existing.distanceKm + row.distanceKm,
        minutes: existing.minutes + row.minutes,
        walkCount: existing.walkCount + 1,
      );
    }

    return buckets.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<DailyAnalyticsBucket> _seedBuckets(DateTime start, DateTime end) {
    final items = <DailyAnalyticsBucket>[];
    var cursor = _startOfDay(start);
    final limit = _startOfDay(end);
    while (!cursor.isAfter(limit)) {
      items.add(DailyAnalyticsBucket(date: cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    return items;
  }

  _WalkAnalyticsRow? _normalizeUserWalk(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final occurredAt = _readTimestamp(data['completedAt']) ?? _readTimestamp(data['joinedAt']);
    if (occurredAt == null) {
      return null;
    }

    final distance = _readDouble(data['actualDistanceKm']) ??
        _readDouble(data['distanceKm']) ??
        0.0;
    final minutes = _readDurationMinutes(data);
    final averageSpeed = _readDouble(data['averageSpeedKmh']) ?? _readDouble(data['averageSpeed']);
    final maxSpeed = _readDouble(data['maxSpeedKmh']) ?? _readDouble(data['maxSpeed']);

    return _WalkAnalyticsRow(
      occurredAt: occurredAt,
      distanceKm: distance,
      minutes: minutes ?? 0,
      averageSpeedKmh: averageSpeed,
      maxSpeedKmh: maxSpeed,
    );
  }

  _WalkAnalyticsRow? _normalizeFriendWalk(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final occurredAt = _readTimestamp(data['endTime']) ?? _readTimestamp(data['startTime']);
    if (occurredAt == null) {
      return null;
    }

    final distance = _readDouble(data['distanceKm']) ?? 0.0;
    final minutes = _readDouble(data['estimatedDurationMinutes']) ??
        _readDouble(data['actualDurationMinutes']);

    return _WalkAnalyticsRow(
      occurredAt: occurredAt,
      distanceKm: distance,
      minutes: minutes ?? 0,
      averageSpeedKmh: null,
      maxSpeedKmh: null,
    );
  }

  double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double? _readDurationMinutes(Map<String, dynamic> data) {
    final durationMinutes = _readDouble(data['actualDurationMinutes']);
    if (durationMinutes != null) return durationMinutes;

    final durationSeconds = _readDouble(data['actualDuration']);
    if (durationSeconds != null) {
      return durationSeconds / 60;
    }

    final confirmed = _readTimestamp(data['confirmedAt']) ?? _readTimestamp(data['joinedAt']);
    final completed = _readTimestamp(data['completedAt']) ?? _readTimestamp(data['leftAt']);
    if (confirmed != null && completed != null) {
      final minutes = completed.difference(confirmed).inMinutes;
      if (minutes > 0) {
        return minutes.toDouble();
      }
    }
    return null;
  }

  DateTime? _readTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  String _bucketKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}

class _WalkAnalyticsRow {
  const _WalkAnalyticsRow({
    required this.occurredAt,
    required this.distanceKm,
    required this.minutes,
    this.averageSpeedKmh,
    this.maxSpeedKmh,
  });

  final DateTime occurredAt;
  final double distanceKm;
  final double minutes;
  final double? averageSpeedKmh;
  final double? maxSpeedKmh;
}
