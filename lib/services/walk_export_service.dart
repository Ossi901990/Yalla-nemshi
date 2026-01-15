import 'package:firebase_auth/firebase_auth.dart';
import '../models/walk_participation.dart';
import 'walk_history_service.dart';
import 'crash_service.dart';

/// Service for exporting walk history to CSV format
class WalkExportService {
  static final WalkExportService _instance = WalkExportService._internal();

  factory WalkExportService() => _instance;

  WalkExportService._internal();

  static WalkExportService get instance => _instance;

  /// Generate CSV content for walk history
  /// Returns CSV string that can be written to file or shared
  Future<String> generateWalkHistoryCSV({String? userId}) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // Get all completed walks
      final walks = await WalkHistoryService.instance
          .getUserWalks(onlyCompleted: true, limit: 1000);

      if (walks.isEmpty) {
        return 'No walk history available';
      }

      // Build CSV header
      final csv = StringBuffer();
      csv.writeln(
        'Walk Date,Walk Duration (minutes),Distance (km),Notes',
      );

      // Add each walk as a row
      for (final walk in walks) {
        final date = walk.joinedAt.toIso8601String().split('T')[0];
        final duration = (walk.actualDuration?.inMinutes ?? 0).toString();
        final distance =
            (walk.actualDistanceKm ?? 0.0).toStringAsFixed(2);
        final notes = walk.notes?.replaceAll(',', ';') ?? '';

        csv.writeln('$date,$duration,$distance,"$notes"');
      }

      // Add summary section
      csv.writeln();
      csv.writeln('SUMMARY');

      double totalDistance = 0;
      int totalMinutes = 0;

      for (final walk in walks) {
        totalDistance += walk.actualDistanceKm ?? 0.0;
        totalMinutes += walk.actualDuration?.inMinutes ?? 0;
      }

      csv.writeln('Total Walks Completed,${walks.length}');
      csv.writeln('Total Distance (km),${totalDistance.toStringAsFixed(2)}');
      csv.writeln('Total Time (hours),${(totalMinutes / 60).toStringAsFixed(2)}');
      csv.writeln(
        'Average Distance per Walk,${(totalDistance / walks.length).toStringAsFixed(2)}',
      );

      return csv.toString();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkExportService.generateWalkHistoryCSV error',
      );
      rethrow;
    }
  }

  /// Generate CSV for monthly/weekly stats
  Future<String> generateStatsCSV({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final walks = await WalkHistoryService.instance
          .getUserWalks(onlyCompleted: true, limit: 1000);

      // Filter by date range if provided
      final filtered = walks.where((w) {
        final walkDate = w.joinedAt;
        if (startDate != null && walkDate.isBefore(startDate)) return false;
        if (endDate != null && walkDate.isAfter(endDate)) return false;
        return true;
      }).toList();

      if (filtered.isEmpty) {
        return 'No walks in the specified date range';
      }

      final csv = StringBuffer();
      csv.writeln('Walking Statistics Report');
      csv.writeln('Generated: ${DateTime.now().toIso8601String()}');
      csv.writeln();

      // Group by month
      final byMonth = <String, List<WalkParticipation>>{};
      for (final walk in filtered) {
        final monthKey =
            '${walk.joinedAt.year}-${walk.joinedAt.month.toString().padLeft(2, '0')}';
        byMonth.putIfAbsent(monthKey, () => []).add(walk);
      }

      csv.writeln('Month,Walks,Total Distance (km),Total Time (hours)');

      for (final entry in byMonth.entries) {
        final month = entry.key;
        final monthWalks = entry.value;
        final distance =
            monthWalks.fold<double>(0, (sum, w) => sum + (w.actualDistanceKm ?? 0.0));
        final minutes =
            monthWalks.fold<int>(0, (sum, w) => sum + (w.actualDuration?.inMinutes ?? 0));

        csv.writeln('$month,${monthWalks.length},${distance.toStringAsFixed(2)},${(minutes / 60).toStringAsFixed(2)}');
      }

      return csv.toString();
    } catch (e) {
      CrashService.recordError(
        e,
        StackTrace.current,
        reason: 'WalkExportService.generateStatsCSV error',
      );
      rethrow;
    }
  }

  /// Get CSV filename with timestamp
  static String getFilename({String type = 'walk_history'}) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${type}_$date.csv';
  }
}
