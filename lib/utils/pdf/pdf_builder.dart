import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/route_snapshot.dart';

class PdfBuilder {
  final pw.Document _document = pw.Document();
  final List<pw.Widget> _content = [];
  final DateFormat _dateFormat = DateFormat.yMMMMd();

  void addTitle(String text) {
    _content.add(
      pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    _content.add(pw.SizedBox(height: 8));
  }

  void addSubtitle(String text) {
    _content.add(
      pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          color: PdfColors.grey600,
        ),
      ),
    );
    _content.add(pw.SizedBox(height: 16));
  }

  void addWalkEntry({
    required String title,
    required DateTime date,
    required double distanceKm,
    required int durationMinutes,
    required String pace,
  }) {
    _content.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _dateFormat.format(date),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _metric('Distance', '${distanceKm.toStringAsFixed(2)} km'),
                _metric('Duration', _formatDuration(durationMinutes)),
                _metric('Pace', pace),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void addSummary({
    required int totalWalks,
    required double totalDistanceKm,
    required int totalDurationMinutes,
  }) {
    final hours = totalDurationMinutes ~/ 60;
    final minutes = totalDurationMinutes % 60;

    _content.add(pw.SizedBox(height: 16));
    _content.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _summaryMetric('Walks', totalWalks.toString()),
            _summaryMetric('Distance', '${totalDistanceKm.toStringAsFixed(1)} km'),
            _summaryMetric('Time', '${hours}h ${minutes}m'),
          ],
        ),
      ),
    );
  }

  void addRouteSnapshot(List<RouteCoordinate> coordinates) {
    if (coordinates.length < 2) return;
    _content.add(pw.SizedBox(height: 24));
    _content.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Latest route snapshot',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            height: 180,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.CustomPaint(
                painter: _RoutePainter(coordinates),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void addEmptyState(String message) {
    _content.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(24),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Nothing to export yet',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              message,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Uint8List build() {
    _document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => _content,
      ),
    );
    return _document.save();
  }

  pw.Widget _metric(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryMetric(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) {
      return '${mins}m';
    }
    return '${hours}h ${mins}m';
  }
}

class _RoutePainter extends pw.CustomPainter {
  _RoutePainter(this.coordinates);

  final List<RouteCoordinate> coordinates;

  @override
  void paint(pw.Context context, pw.Canvas canvas, pw.Rect rect) {
    final latitudes = coordinates.map((c) => c.latitude).toList();
    final longitudes = coordinates.map((c) => c.longitude).toList();

    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLng = longitudes.reduce(math.min);
    final maxLng = longitudes.reduce(math.max);

    final latRange = (maxLat - minLat).abs().clamp(0.000001, double.infinity);
    final lngRange = (maxLng - minLng).abs().clamp(0.000001, double.infinity);

    final padding = 6.0;
    final usableWidth = rect.width - padding * 2;
    final usableHeight = rect.height - padding * 2;

    final path = pw.Path();
    for (var i = 0; i < coordinates.length; i++) {
      final coord = coordinates[i];
      final dx = ((coord.longitude - minLng) / lngRange) * usableWidth + padding;
      final dy = usableHeight -
          ((coord.latitude - minLat) / latRange) * usableHeight +
          padding;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final paint = pw.Paint()
      ..color = PdfColors.blue400
      ..strokeWidth = 2
      ..style = pw.PaintingStyle.stroke;

    canvas.drawPath(path, paint);

    final start = pw.Paint()
      ..color = PdfColors.green
      ..style = pw.PaintingStyle.fill;
    final end = pw.Paint()
      ..color = PdfColors.red
      ..style = pw.PaintingStyle.fill;

    final startCoord = coordinates.first;
    final endCoord = coordinates.last;

    canvas.drawCircle(
      pw.Offset(
        ((startCoord.longitude - minLng) / lngRange) * usableWidth + padding,
        usableHeight -
            ((startCoord.latitude - minLat) / latRange) * usableHeight + padding,
      ),
      3,
      start,
    );

    canvas.drawCircle(
      pw.Offset(
        ((endCoord.longitude - minLng) / lngRange) * usableWidth + padding,
        usableHeight -
            ((endCoord.latitude - minLat) / latRange) * usableHeight + padding,
      ),
      3,
      end,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => false;
}
