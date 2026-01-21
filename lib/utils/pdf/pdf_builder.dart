import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/route_snapshot.dart';

class PdfBuilder {
  final pw.Document _document = pw.Document();
  final List<pw.Widget> _content = [];

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

  void addWalkTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      return;
    }
    _content.add(pw.SizedBox(height: 12));
    _content.add(
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
        cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.3),
          outside: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
        cellAlignment: pw.Alignment.centerLeft,
        columnWidths: const {
          0: pw.FlexColumnWidth(1.4),
          1: pw.FlexColumnWidth(2.4),
          2: pw.FlexColumnWidth(2.1),
          3: pw.FlexColumnWidth(2.1),
          4: pw.FlexColumnWidth(1.1),
          5: pw.FlexColumnWidth(1.4),
          6: pw.FlexColumnWidth(1.4),
          7: pw.FlexColumnWidth(1.3),
          8: pw.FlexColumnWidth(2.6),
          9: pw.FlexColumnWidth(1.6),
          10: pw.FlexColumnWidth(1.8),
        },
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
              child: pw.Text(
                'Route: ${coordinates.length} checkpoints',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
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

  Future<Uint8List> build() async {
    _document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => _content,
      ),
    );
    return await _document.save();
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
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

}
