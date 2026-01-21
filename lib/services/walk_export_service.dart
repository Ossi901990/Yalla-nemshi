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
  final Map<String, _WalkMetadata?> _walkMetadataCache = {};

  static const List<String> _exportHeaders = [
    'Walk ID',
    'Title',
    'Start Time',
    'End Time',
    'Duration (minutes)',
    'Planned Distance (km)',
    'Actual Distance (km)',
    'Status',
    'Notes',
    'Host UID',
    'City/Location',
  ];

  final DateFormat _rowDateFormat = DateFormat('y-MM-dd HH:mm');

  /// Generate CSV content for walk history
  /// Returns CSV string that can be written to file or shared
  Future<String> generateWalkHistoryCSV({String? userId}) async {
    try {
      _ensureAuthenticated(userId);

      final dataset = await _buildExportDataset(limit: 1000);
      final rows = dataset.rows;

      final csv = StringBuffer();
      csv.writeln(_exportHeaders.join(','));

      if (rows.isEmpty) {
        final placeholder = <String>[
          'No walks yet',
          ...List.filled(_exportHeaders.length - 1, ''),
        ];
        csv.writeln(placeholder.map(_sanitizeCsvField).join(','));
        return csv.toString();
      }

      for (final row in rows) {
        csv.writeln(_formatCsvRow(row));
      }

      csv.writeln();
      csv.writeln('SUMMARY');
      csv.writeln('Total Walks,${rows.length}');
      csv.writeln(
        'Total Planned Distance (km),${dataset.totals.totalPlannedDistanceKm.toStringAsFixed(2)}',
      );
      csv.writeln(
        'Total Actual Distance (km),${dataset.totals.totalActualDistanceKm.toStringAsFixed(2)}',
      );
      csv.writeln(
        'Total Time (hours),${(dataset.totals.totalDurationMinutes / 60).toStringAsFixed(2)}',
      );
      final averageActual = dataset.totals.averageActualDistanceKm;
      if (averageActual != null) {
        csv.writeln(
          'Average Actual Distance per Walk,${averageActual.toStringAsFixed(2)}',
        );
      }

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
        final distance = monthWalks.fold<double>(
          0,
          (acc, walk) => acc + (walk.actualDistanceKm ?? 0.0),
        );
        final minutes = monthWalks.fold<int>(
          0,
          (acc, walk) => acc + _minutesForWalk(walk),
        );

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
      _ensureAuthenticated(userId);

      final dataset = await _buildExportDataset(limit: 250);

      final doc = PdfBuilder();
      doc.addTitle('Walk Summary');
      doc.addSubtitle(DateFormat.yMMMMd().format(DateTime.now()));

      if (dataset.rows.isEmpty) {
        doc.addEmptyState('No walks recorded yet. Join a walk to see it here.');
        doc.addSummary(totalWalks: 0, totalDistanceKm: 0, totalDurationMinutes: 0);
        return doc.build();
      }

      doc.addSummary(
        totalWalks: dataset.rows.length,
        totalDistanceKm: dataset.totals.totalActualDistanceKm,
        totalDurationMinutes: dataset.totals.totalDurationMinutes,
      );

      doc.addWalkTable(
        headers: _exportHeaders,
        rows: dataset.rows.map(_rowToPdfCells).toList(),
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

  String _formatCsvRow(_WalkExportRow row) {
    final values = [
      row.walkId,
      row.title ?? '',
      _formatIsoDate(row.startTime),
      _formatIsoDate(row.endTime),
      row.durationMinutes?.toString() ?? '',
      _formatCsvDistance(row.plannedDistanceKm),
      _formatCsvDistance(row.actualDistanceKm),
      row.status,
      row.notes ?? '',
      row.hostUid ?? '',
      row.cityOrLocation ?? '',
    ];
    return values.map(_sanitizeCsvField).join(',');
  }

  String _formatIsoDate(DateTime? value) {
    return value?.toUtc().toIso8601String() ?? '';
  }

  String _formatCsvDistance(double? value) {
    return value != null ? value.toStringAsFixed(2) : '';
  }

  List<String> _rowToPdfCells(_WalkExportRow row) {
    return [
      row.walkId,
      row.title ?? '--',
      _formatDisplayDate(row.startTime),
      _formatDisplayDate(row.endTime),
      row.durationMinutes?.toString() ?? '--',
      _formatPdfDistance(row.plannedDistanceKm),
      _formatPdfDistance(row.actualDistanceKm),
      row.status.isNotEmpty ? row.status : '--',
      _formatPdfNotes(row.notes),
      row.hostUid ?? '--',
      row.cityOrLocation ?? '--',
    ];
  }

  String _formatDisplayDate(DateTime? value) {
    if (value == null) return '--';
    return _rowDateFormat.format(value);
  }

  String _formatPdfDistance(double? value) {
    return value != null ? value.toStringAsFixed(2) : '--';
  }

  String _formatPdfNotes(String? notes) {
    if (notes == null || notes.isEmpty) {
      return '--';
    }
      final sanitized = notes.replaceAll('\n', ' ').trim();
    if (sanitized.length <= 80) {
      return sanitized;
    }
    return '${sanitized.substring(0, 77)}...';
  }

  void _ensureAuthenticated(String? userId) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
  }

  Future<_ExportDataset> _buildExportDataset({required int limit}) async {
    final walks = await WalkHistoryService.instance
        .getUserWalks(onlyCompleted: false, limit: limit);

    if (walks.isEmpty) {
      return _ExportDataset.empty();
    }

    final metadataMap = await _batchLoadMetadata(walks.map((w) => w.walkId));
    final totals = _ExportTotals();
    final rows = <_WalkExportRow>[];

    for (final walk in walks) {
      final row = _WalkExportRow.from(walk, metadataMap[walk.walkId]);
      rows.add(row);
      totals.add(row);
    }

    return _ExportDataset(rows: rows, totals: totals);
  }

  Future<Map<String, _WalkMetadata>> _batchLoadMetadata(
    Iterable<String> walkIds,
  ) async {
    final ids = walkIds.toSet();
    if (ids.isEmpty) {
      return <String, _WalkMetadata>{};
    }

    final futures = <String, Future<_WalkMetadata?>>{};
    for (final id in ids) {
      futures[id] = _loadWalkMetadata(id);
    }

    final results = <String, _WalkMetadata>{};
    for (final entry in futures.entries) {
      final metadata = await entry.value;
      if (metadata != null) {
        results[entry.key] = metadata;
      }
    }
    return results;
  }

  Future<_WalkMetadata?> _loadWalkMetadata(String walkId) async {
    if (_walkMetadataCache.containsKey(walkId)) {
      return _walkMetadataCache[walkId];
    }

    try {
      final doc = await _firestore.collection('walks').doc(walkId).get();
      if (!doc.exists) {
        _walkMetadataCache[walkId] = null;
        return null;
      }

      final metadata = _WalkMetadata.fromSnapshot(doc);
      _walkMetadataCache[walkId] = metadata;
      return metadata;
    } catch (e, st) {
      CrashService.recordError(
        e,
        st,
        reason: 'WalkExportService._loadWalkMetadata',
      );
      _walkMetadataCache[walkId] = null;
      return null;
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

class _WalkExportRow {
  const _WalkExportRow({
    required this.walkId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.plannedDistanceKm,
    required this.actualDistanceKm,
    required this.status,
    required this.notes,
    required this.hostUid,
    required this.cityOrLocation,
  });

  final String walkId;
  final String? title;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final double? plannedDistanceKm;
  final double? actualDistanceKm;
  final String status;
  final String? notes;
  final String? hostUid;
  final String? cityOrLocation;

  factory _WalkExportRow.from(
    WalkParticipation walk,
    _WalkMetadata? metadata,
  ) {
    final normalizedStatus = _normalizeStatus(
      walk.status,
      fallback: walk.participationState,
    );

    final metadataTitle = metadata?.title;
    final resolvedTitle =
      (metadataTitle != null && metadataTitle.isNotEmpty)
        ? metadataTitle
        : 'Walk ${walk.walkId}';

    final DateTime startTime = walk.confirmedAt ??
      metadata?.startedAt ??
      metadata?.scheduledStart ??
      walk.joinedAt;

    DateTime? endTime = walk.completedAt ?? metadata?.completedAt;

    int? durationMinutes = walk.actualDurationMinutes ??
        walk.actualDuration?.inMinutes ??
        metadata?.actualDurationMinutes ??
        _diffInMinutes(startTime, endTime);

    if (endTime == null && durationMinutes != null) {
      endTime = startTime.add(Duration(minutes: durationMinutes));
    }

    final plannedDistance = metadata?.plannedDistanceKm;
    final actualDistance = walk.actualDistanceKm ??
        metadata?.actualDistanceKm ??
        plannedDistance;

    final trimmedNotes = walk.notes?.trim();
    final cleanNotes =
        (trimmedNotes != null && trimmedNotes.isNotEmpty) ? trimmedNotes : null;

    final metadataCity = metadata?.city;
    final location = (metadataCity != null && metadataCity.isNotEmpty)
      ? metadataCity
      : metadata?.meetingPlaceName;

    return _WalkExportRow(
      walkId: walk.walkId,
      title: resolvedTitle,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      plannedDistanceKm: plannedDistance,
      actualDistanceKm: actualDistance,
      status: normalizedStatus,
      notes: cleanNotes,
      hostUid: metadata?.hostUid,
      cityOrLocation: location,
    );
  }

  static String _normalizeStatus(String value, {String? fallback}) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final alt = fallback?.trim() ?? '';
    return alt.isNotEmpty ? alt : 'unknown';
  }
}

class _ExportTotals {
  double totalPlannedDistanceKm = 0;
  double totalActualDistanceKm = 0;
  int totalDurationMinutes = 0;
  int _rowsWithActualDistance = 0;

  void add(_WalkExportRow row) {
    if (row.plannedDistanceKm != null) {
      totalPlannedDistanceKm += row.plannedDistanceKm!;
    }
    if (row.actualDistanceKm != null) {
      totalActualDistanceKm += row.actualDistanceKm!;
      _rowsWithActualDistance++;
    }
    if (row.durationMinutes != null) {
      totalDurationMinutes += row.durationMinutes!;
    }
  }

  double? get averageActualDistanceKm =>
      _rowsWithActualDistance == 0
          ? null
          : totalActualDistanceKm / _rowsWithActualDistance;
}

class _ExportDataset {
  _ExportDataset({required this.rows, required this.totals});

  final List<_WalkExportRow> rows;
  final _ExportTotals totals;

    factory _ExportDataset.empty() => _ExportDataset(
      rows: const <_WalkExportRow>[],
        totals: _ExportTotals(),
      );
}

class _WalkMetadata {
  const _WalkMetadata({
    this.title,
    this.plannedDistanceKm,
    this.actualDistanceKm,
    this.hostUid,
    this.city,
    this.meetingPlaceName,
    this.scheduledStart,
    this.startedAt,
    this.completedAt,
    this.actualDurationMinutes,
  });

  final String? title;
  final double? plannedDistanceKm;
  final double? actualDistanceKm;
  final String? hostUid;
  final String? city;
  final String? meetingPlaceName;
  final DateTime? scheduledStart;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? actualDurationMinutes;

  factory _WalkMetadata.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _WalkMetadata(
      title: _readString(data['title']),
      plannedDistanceKm: _readDouble(data['distanceKm']),
      actualDistanceKm: _readDouble(data['actualDistanceKm']),
      hostUid: _readString(data['hostUid']),
      city: _readString(data['city']),
      meetingPlaceName: _readString(data['meetingPlaceName']),
      scheduledStart: _readDateTime(data['dateTime']),
      startedAt: _readDateTime(data['startedAt']),
      completedAt: _readDateTime(data['completedAt']),
      actualDurationMinutes: _readInt(data['actualDurationMinutes']),
    );
  }
}

int? _diffInMinutes(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return null;
  }
  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) {
    return null;
  }
  return minutes;
}

String? _readString(dynamic value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _readDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _readInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}
