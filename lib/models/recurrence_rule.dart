/// Types of recurrence patterns
enum RecurrenceType { weekly, monthly }

/// Defines how a walk repeats
class RecurrenceRule {
  final RecurrenceType type;
  final int interval; // Repeat every N weeks/months (default 1)
  final List<int>? weekDays; // 1=Mon, 2=Tue...7=Sun (for weekly)
  final int? monthDay; // 1-31 (for monthly)

  const RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.weekDays,
    this.monthDay,
  });

  /// Create from Firestore document
  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    return RecurrenceRule(
      type: RecurrenceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RecurrenceType.weekly,
      ),
      interval: map['interval'] ?? 1,
      weekDays: (map['weekDays'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      monthDay: map['monthDay'] as int?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'interval': interval,
      if (weekDays != null) 'weekDays': weekDays,
      if (monthDay != null) 'monthDay': monthDay,
    };
  }

  /// Human-readable description
  String getDescription() {
    if (type == RecurrenceType.weekly) {
      if (weekDays == null || weekDays!.isEmpty) {
        return interval == 1 ? 'Weekly' : 'Every $interval weeks';
      }
      final days = weekDays!.map(_dayName).join(', ');
      return interval == 1 ? 'Every $days' : 'Every $interval weeks on $days';
    } else {
      // monthly
      final day = monthDay ?? 1;
      final suffix = _getDaySuffix(day);
      return interval == 1
          ? 'Monthly on the $day$suffix'
          : 'Every $interval months on the $day$suffix';
    }
  }

  String _dayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? interval,
    List<int>? weekDays,
    int? monthDay,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      weekDays: weekDays ?? this.weekDays,
      monthDay: monthDay ?? this.monthDay,
    );
  }
}
