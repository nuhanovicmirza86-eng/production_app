import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/production_operator_tracking_entry.dart';

typedef DefectDisplayNames = Map<String, String>;

/// PDF dnevnog lista unosa iz praćenja (pripremna / kontrole).
class ProductionOperatorTrackingDayPdfExport {
  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _time(DateTime? t) {
    if (t == null) return '—';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String _phaseTitle(String phase) {
    switch (phase) {
      case ProductionOperatorTrackingEntry.phasePreparation:
        return 'Pripremna';
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prva kontrola';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Završna kontrola';
      default:
        return phase;
    }
  }

  static String _dash(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  static List<ProductionOperatorTrackingEntry> _chronological(
    List<ProductionOperatorTrackingEntry> rows,
  ) {
    final out = List<ProductionOperatorTrackingEntry>.from(rows);
    out.sort((a, b) {
      final ta = a.createdAt;
      final tb = b.createdAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      final c = ta.compareTo(tb);
      if (c != 0) return c;
      return a.itemCode.compareTo(b.itemCode);
    });
    return out;
  }

  static Future<Uint8List> buildPdf({
    required List<ProductionOperatorTrackingEntry> entries,
    required String workDate,
    required String phase,
    String? companyLine,
    String? plantLine,
    DefectDisplayNames defectDisplayNames = const {},
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');
    final now = DateTime.now();
    final phaseHuman = _phaseTitle(phase);
    final rows = _chronological(entries);

    pw.Widget cell(
      String t, {
      bool header = false,
      pw.TextAlign align = pw.TextAlign.left,
      int maxLines = 4,
      double fontSize = 6,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        alignment: align == pw.TextAlign.right
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          t,
          textAlign: align,
          maxLines: maxLines,
          style: pw.TextStyle(
            font: header ? fontB : fontR,
            fontSize: header ? 6.5 : fontSize,
          ),
        ),
      );
    }

    pw.TableRow headerRow() {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          cell('Vrijeme', header: true),
          cell('Šifra', header: true),
          cell('Naziv', header: true),
          cell('Dobro', header: true, align: pw.TextAlign.right),
          cell('Škart', header: true),
          cell('Ukup.', header: true, align: pw.TextAlign.right),
          cell('MJ', header: true),
          cell('PN', header: true),
          cell('Nar.', header: true),
          cell('Napomena', header: true),
          cell('Operater', header: true),
        ],
      );
    }

    final scrapNames = defectDisplayNames;

    pw.TableRow dataRow(ProductionOperatorTrackingEntry e) {
      final scrapTxt = e.scrapBreakdownSummaryForDisplay(scrapNames);
      return pw.TableRow(
        children: [
          cell(_time(e.createdAt)),
          cell(e.itemCode, maxLines: 2),
          cell(e.itemName, maxLines: 3),
          cell(_fmtQty(e.effectiveGoodQty), align: pw.TextAlign.right),
          cell(
            scrapTxt.isEmpty ? '—' : scrapTxt,
            maxLines: 3,
          ),
          cell(_fmtQty(e.quantity), align: pw.TextAlign.right),
          cell(e.unit.isEmpty ? '—' : e.unit),
          cell(_dash(e.productionOrderId), maxLines: 2),
          cell(_dash(e.commercialOrderId), maxLines: 2),
          cell(_dash(e.notes), maxLines: 3),
          cell(_dash(e.createdByEmail), maxLines: 2, fontSize: 5.5),
        ],
      );
    }

    final headerBlock = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Dnevni list praćenja — $phaseHuman',
          style: pw.TextStyle(font: fontB, fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Radni datum: $workDate',
          style: pw.TextStyle(font: fontR, fontSize: 9),
        ),
        if (companyLine != null && companyLine.trim().isNotEmpty)
          pw.Text(
            companyLine.trim(),
            style: pw.TextStyle(font: fontR, fontSize: 8),
          ),
        if (plantLine != null && plantLine.trim().isNotEmpty)
          pw.Text(
            plantLine.trim(),
            style: pw.TextStyle(font: fontR, fontSize: 8),
          ),
        pw.Text(
          'Generirano: ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}. '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          style: pw.TextStyle(font: fontR, fontSize: 7, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Ukupno redaka: ${rows.length}',
          style: pw.TextStyle(font: fontB, fontSize: 8),
        ),
        pw.SizedBox(height: 12),
      ],
    );

    final table = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.35),
      columnWidths: {
        0: const pw.FixedColumnWidth(34),
        1: const pw.FixedColumnWidth(48),
        2: const pw.FlexColumnWidth(2.0),
        3: const pw.FixedColumnWidth(34),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FixedColumnWidth(34),
        6: const pw.FixedColumnWidth(22),
        7: const pw.FixedColumnWidth(40),
        8: const pw.FixedColumnWidth(40),
        9: const pw.FlexColumnWidth(0.9),
        10: const pw.FixedColumnWidth(68),
      },
      children: [
        headerRow(),
        for (final e in rows) dataRow(e),
      ],
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [headerBlock, table],
      ),
    );
    return doc.save();
  }

  static Future<void> preview({
    required List<ProductionOperatorTrackingEntry> entries,
    required String workDate,
    required String phase,
    String? companyLine,
    String? plantLine,
    DefectDisplayNames defectDisplayNames = const {},
  }) async {
    await Printing.layoutPdf(
      name: 'pracenje_proizvodnje_dnevni_list',
      onLayout: (_) => buildPdf(
        entries: entries,
        workDate: workDate,
        phase: phase,
        companyLine: companyLine,
        plantLine: plantLine,
        defectDisplayNames: defectDisplayNames,
      ),
    );
  }
}
