// lib/utils/walk_format.dart
//
// Small text helpers shared by the redesigned screens.
import 'package:intl/intl.dart';

class WalkFormat {
  WalkFormat._();

  /// "Tonight · 19:30", "Today · 07:00", "Tomorrow · 07:00",
  /// "Tue 24 Nov · 07:00".
  static String when(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(t.year, t.month, t.day);
    final time = DateFormat('HH:mm').format(t);
    final diff = day.difference(today).inDays;
    if (diff == 0) return '${t.hour >= 17 ? 'Tonight' : 'Today'} · $time';
    if (diff == 1) return 'Tomorrow · $time';
    if (diff == -1) return 'Yesterday · $time';
    return '${DateFormat('EEE d MMM').format(t)} · $time';
  }

  /// "4", "4.5".
  static String km(double km) =>
      km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
}
