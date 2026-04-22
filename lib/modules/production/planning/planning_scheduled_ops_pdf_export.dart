import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/pdf/operonix_industrial_letterhead_pdf.dart';
import '../../../core/pdf/operonix_pdf_footer.dart';
import 'models/saved_plan_scheduled_row.dart';
import 'planning_ui_formatters.dart';

/// PDF za zakazane operacije: pregled (ispis), dijeljenje datoteke — usklađeno s ostalim PDF izvozima u appu.
class PlanningScheduledOpsPdfExport {
  const PlanningScheduledOpsPdfExport._();

  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static Future<Uint8List> buildPdfBytes({
    required List<SavedPlanScheduledRow> rows,
    required String planCode,
    String? companyPlantLine,
    String? planStatusLabel,
    String? strategyLine,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');
    final logoBytes = await OperonixIndustrialLetterheadPdf.loadLogoBytes();

    final meta = <pw.Widget>[
      pw.Text(
        'Zakazane operacije',
        style: pw.TextStyle(font: fontB, fontSize: 16),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Plan: $planCode',
        style: pw.TextStyle(font: fontR, fontSize: 11),
      ),
      if (companyPlantLine != null && companyPlantLine.trim().isNotEmpty)
        pw.Text(
          companyPlantLine.trim(),
          style: pw.TextStyle(font: fontR, fontSize: 9, color: PdfColors.grey800),
        ),
      if (planStatusLabel != null && planStatusLabel.trim().isNotEmpty)
        pw.Text(
          'Status: ${planStatusLabel.trim()}',
          style: pw.TextStyle(font: fontR, fontSize: 9),
        ),
      if (strategyLine != null && strategyLine.trim().isNotEmpty)
        pw.Text(
          'Strategija motora: ${strategyLine.trim()}',
          style: pw.TextStyle(font: fontR, fontSize: 8, color: PdfColors.grey700),
        ),
      pw.SizedBox(height: 12),
    ];

    pw.TableRow hdr() {
      pw.Widget cell(String t, {bool bold = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            t,
            style: pw.TextStyle(
              font: bold ? fontB : fontR,
              fontSize: 8,
            ),
          ),
        );
      }

      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          cell('R.b.', bold: true),
          cell('Nalog', bold: true),
          cell('Korak', bold: true),
          cell('Operacija', bold: true),
          cell('Stroj', bold: true),
          cell('Početak', bold: true),
          cell('Kraj', bold: true),
          cell('Min', bold: true),
        ],
      );
    }

    pw.TableRow dataRow(SavedPlanScheduledRow r, int i) {
      pw.Widget c(String t) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
            t,
            style: pw.TextStyle(font: fontR, fontSize: 7),
          ),
        );
      }

      return pw.TableRow(
        children: [
          c('${i + 1}'),
          c(r.productionOrderCode),
          c('${r.operationSequence}'),
          c((r.operationLabel == null || r.operationLabel!.isEmpty) ? '—' : r.operationLabel!),
          c(r.resourceDisplayName),
          c(PlanningUiFormatters.formatDateTime(r.plannedStart)),
          c(PlanningUiFormatters.formatDateTime(r.plannedEnd)),
          c('${r.durationMinutes}'),
        ],
      );
    }

    final table = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.25),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FlexColumnWidth(1.1),
        2: const pw.FixedColumnWidth(28),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.3),
        5: const pw.FlexColumnWidth(1.0),
        6: const pw.FlexColumnWidth(1.0),
        7: const pw.FixedColumnWidth(26),
      },
      children: [
        hdr(),
        for (var i = 0; i < rows.length; i++) dataRow(rows[i], i),
      ],
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        footer: (ctx) => OperonixPdfFooter.multiPageFooter(ctx, fontR),
        build: (context) => [
          OperonixIndustrialLetterheadPdf.strip(logoBytes: logoBytes),
          ...meta,
          if (rows.isEmpty)
            pw.Text(
              'Nema operacija u rasporedu.',
              style: pw.TextStyle(font: fontR, fontSize: 10, color: PdfColors.grey700),
            )
          else
            table,
        ],
      ),
    );
    return doc.save();
  }

  /// Pregled u sustavu, ispis i (ovisno o platformi) spremanje.
  static Future<void> openPreview({
    required List<SavedPlanScheduledRow> rows,
    required String planCode,
    String? companyPlantLine,
    String? planStatusLabel,
    String? strategyLine,
  }) async {
    final safe = planCode.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await Printing.layoutPdf(
      name: 'plan_${safe}_operacije',
      onLayout: (PdfPageFormat format) => buildPdfBytes(
        rows: rows,
        planCode: planCode,
        companyPlantLine: companyPlantLine,
        planStatusLabel: planStatusLabel,
        strategyLine: strategyLine,
      ),
    );
  }

  /// Dijeljenje datoteke (e-pošta, upravljač, …).
  static Future<void> sharePdfFile({
    required List<SavedPlanScheduledRow> rows,
    required String planCode,
    String? companyPlantLine,
    String? planStatusLabel,
    String? strategyLine,
  }) async {
    final bytes = await buildPdfBytes(
      rows: rows,
      planCode: planCode,
      companyPlantLine: companyPlantLine,
      planStatusLabel: planStatusLabel,
      strategyLine: strategyLine,
    );
    final safe = planCode.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'plan_${safe}_operacije.pdf';
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      text: 'Plan proizvodnje — $planCode (PDF)',
    );
  }
}
