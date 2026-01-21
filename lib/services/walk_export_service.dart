import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/route_snapshot.dart';
import '../models/walk_participation.dart';
import '../utils/pdf/pdf_builder.dart';
import 'file_saver.dart';
import 'walk_history_service.dart';
import 'crash_service.dart';

/// Service for exporting walk history to CSV format
class WalkExportService {
  static final WalkExportService _instance = WalkExportService._internal();

  factory WalkExportService() => _instance;

  WalkExportService._internal();

  static WalkExportService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _walkTitleCache = {};

  /// Generate CSV content for walk history
  /// Returns CSV string that can be written to file or shared
  Future<String> generateWalkHistoryCSV({String? userId}) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // Get all completed walks
      final walks = await WalkHistoryService.instance
          .getUserWalks(onlyCompleted: true, limit: 1000);

      // Build CSV header
      final csv = StringBuffer();
      csv.writeln(
        'Walk ID,Title,Walk Date,Walk Duration (minutes),Distance (km),Status,Notes',
      );

      if (walks.isEmpty) {
        csv.writeln('No walks yet,,,,,,');
        return csv.toString();
      }

      // Add each walk as a row
      for (final walk in walks) {
        final title = await _resolveWalkTitle(walk.walkId);
        final date = walk.joinedAt.toIso8601String().split('T')[0];
        final duration = _minutesForWalk(walk).toString();
        final distance =
            (walk.actualDistanceKm ?? 0.0).toStringAsFixed(2);
        final status = walk.status.isNotEmpty ? walk.status : '--';
        final notes = _sanitizeCsvField(walk.notes ?? '');

        csv.writeln(
          '${walk.walkId},${_sanitizeCsvField(title)},$date,$duration,$distance,$status,$notes',
        );
      }

      // Add summary section
      csv.writeln();
      csv.writeln('SUMMARY');

      double totalDistance = 0;
      int totalMinutes = 0;

      for (final walk in walks) {
        totalDistance += walk.actualDistanceKm ?? 0.0;
        totalMinutes += _minutesForWalk(walk);
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
          monthWalks.fold<int>(0, (sum, w) => sum + _minutesForWalk(w));

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
  static String getFilename({String type = 'walk_history', String extension = 'csv'}) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${type}_$date.$extension';
  }

  Future<Uint8List> generateWalkSummaryPdf({String? userId}) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final walks = await WalkHistoryService.instance
          .getUserWalks(onlyCompleted: true, limit: 250);

      final doc = PdfBuilder();
      doc.addTitle('Walk Summary');
      doc.addSubtitle(DateFormat.yMMMMd().format(DateTime.now()));

      if (walks.isEmpty) {
        doc.addEmptyState('No completed walks yet. Join a walk to see it here.');
        doc.addSummary(totalWalks: 0, totalDistanceKm: 0, totalDurationMinutes: 0);
        return doc.build();
      }

      double totalDistance = 0;
      int totalMinutes = 0;

      for (final walk in walks) {
        totalDistance += walk.actualDistanceKm ?? 0.0;
        totalMinutes += _minutesForWalk(walk);

        doc.addWalkEntry(
          title: walk.notes?.isNotEmpty == true
              ? walk.notes!
              : 'Walk on ${DateFormat.MMMd().format(walk.joinedAt)}',
          date: walk.joinedAt,
          distanceKm: walk.actualDistanceKm ?? 0.0,
          durationMinutes: _minutesForWalk(walk),
          pace: _formatPace(
            durationMinutes: _minutesForWalk(walk),
            distanceKm: walk.actualDistanceKm,
          ),
        );
      }

      doc.addSummary(
        totalWalks: walks.length,
        totalDistanceKm: totalDistance,
        totalDurationMinutes: totalMinutes,
      );

      final RouteSnapshot? snapshot =
          await WalkHistoryService.instance.getLatestRouteSnapshot();
      if (snapshot != null) {
        doc.addRouteSnapshot(snapshot.coordinates);
      }

      return doc.build();
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'WalkExportService.generateWalkSummaryPdf');
      rethrow;
    }
  }

  String _formatPace({int? durationMinutes, double? distanceKm}) {
    if (durationMinutes == null || durationMinutes == 0) return '--';
    if (distanceKm == null || distanceKm <= 0) return '--';
    final paceMinutes = durationMinutes / distanceKm;
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} / km';
  }

  Future<void> exportHistoryCsv() async {
    final csv = await generateWalkHistoryCSV();
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await FileSaver.saveBytes(bytes, getFilename(), 'text/csv');
  }

  Future<void> exportWalkSummaryPdf() async {
    final pdf = await generateWalkSummaryPdf();
    await FileSaver.saveBytes(
      pdf,
      getFilename(type: 'walk_summary', extension: 'pdf'),
      'application/pdf',
    );
  }

  int _minutesForWalk(WalkParticipation walk) {
    return walk.actualDurationMinutes ?? walk.actualDuration?.inMinutes ?? 0;
  }

  Future<String> _resolveWalkTitle(String walkId) async {
    if (_walkTitleCache.containsKey(walkId)) {
      return _walkTitleCache[walkId]!;
    }

    try {
      final doc = await _firestore.collection('walks').doc(walkId).get();
      final title = (doc.data()?['title'] as String?)?.trim();
      final resolved = (title == null || title.isEmpty)
          ? 'Walk $walkId'
          : title;
      _walkTitleCache[walkId] = resolved;
      return resolved;
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'WalkExportService._resolveWalkTitle',
      );
      final fallback = 'Walk $walkId';
      _walkTitleCache[walkId] = fallback;
      return fallback;
    }
  }

  String _sanitizeCsvField(String value) {
    final cleaned = value
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('"', '""');
    return '"$cleaned"';
  }
}
