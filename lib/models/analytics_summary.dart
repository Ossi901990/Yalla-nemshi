import 'package:intl/intl.dart';

class DailyAnalyticsBucket {
  DailyAnalyticsBucket({
    required this.date,
    this.distanceKm = 0,
    this.minutes = 0,
    this.walkCount = 0,
  });

  final DateTime date;
  final double distanceKm;
  final double minutes;
  final int walkCount;

  double? get averagePaceMinutesPerKm {
    if (distanceKm <= 0 || minutes <= 0) return null;
    return minutes / distanceKm;
  }

  double? get averageSpeedKmh {
    if (minutes <= 0 || distanceKm <= 0) return null;
    final hours = minutes / 60;
    if (hours <= 0) return null;
    return distanceKm / hours;
  }

  String get label => DateFormat('MMM d').format(date);

  DailyAnalyticsBucket copyWith({
    DateTime? date,
    double? distanceKm,
    double? minutes,
    int? walkCount,
  }) {
    return DailyAnalyticsBucket(
      date: date ?? this.date,
      distanceKm: distanceKm ?? this.distanceKm,
      minutes: minutes ?? this.minutes,
      walkCount: walkCount ?? this.walkCount,
    );
  }
}

class MyAnalyticsSummary {
  const MyAnalyticsSummary({
    required this.totalWalks,
    required this.totalDistanceKm,
    required this.totalMinutes,
    required this.dailyBuckets,
    this.averagePaceMinutesPerKm,
    this.averageSpeedKmh,
    this.maxSpeedKmh,
  });

  final int totalWalks;
  final double totalDistanceKm;
  final double totalMinutes;
  final double? averagePaceMinutesPerKm;
  final double? averageSpeedKmh;
  final double? maxSpeedKmh;
  final List<DailyAnalyticsBucket> dailyBuckets;

  bool get hasData => totalWalks > 0 || totalDistanceKm > 0;
}

class FriendAnalyticsSummary {
  const FriendAnalyticsSummary({
    required this.totalWalks,
    required this.totalDistanceKm,
    required this.totalMinutes,
    required this.dailyBuckets,
    this.averagePaceMinutesPerKm,
    this.averageSpeedKmh,
  });

  final int totalWalks;
  final double totalDistanceKm;
  final double totalMinutes;
  final double? averagePaceMinutesPerKm;
  final double? averageSpeedKmh;
  final List<DailyAnalyticsBucket> dailyBuckets;

  bool get hasData => totalWalks > 0 || totalDistanceKm > 0;

  static FriendAnalyticsSummary empty(DateTime start, DateTime end) {
    return FriendAnalyticsSummary(
      totalWalks: 0,
      totalDistanceKm: 0,
      totalMinutes: 0,
      averagePaceMinutesPerKm: null,
      averageSpeedKmh: null,
      dailyBuckets: _emptyBuckets(start, end),
    );
  }

  static List<DailyAnalyticsBucket> _emptyBuckets(DateTime start, DateTime end) {
    final buckets = <DailyAnalyticsBucket>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final limit = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(limit)) {
      buckets.add(DailyAnalyticsBucket(date: cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    return buckets;
  }
}

class FriendOption {
  const FriendOption({required this.uid, required this.displayName});

  final String uid;
  final String displayName;
}
