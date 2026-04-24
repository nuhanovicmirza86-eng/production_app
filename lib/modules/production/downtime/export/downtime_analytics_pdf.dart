import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../analytics/downtime_analytics_engine.dart';
import '../analytics/downtime_machine_target_row.dart' show DowntimeMachineTargetRow, downtimeMachineTargetOoeLabel;
import '../models/downtime_event_model.dart';

class DowntimeAnalyticsPdf {
  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _fmtD(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static pw.Widget _kv(pw.Font reg, pw.Font bold, String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(k, style: pw.TextStyle(font: bold, fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(v, style: pw.TextStyle(font: reg, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> buildPdfBytes({
    required DowntimeAnalyticsReport report,
    required String companyId,
    required String plantKey,
    String? plantDisplayName,
    List<DowntimeMachineTargetRow>? machineTargetRows,
    int? oeeBudgetMinutes,
  }) async {
    final fontRegular = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _font('assets/fonts/NotoSans-Bold.ttf');

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    final plantLine = plantDisplayName?.trim().isNotEmpty == true
        ? plantDisplayName!.trim()
        : plantKey.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Text(
            'Analitika zastoja',
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Kompanija: $companyId · Pogon: $plantLine',
            style: pw.TextStyle(font: fontRegular, fontSize: 9),
          ),
          pw.Text(
            'Period: ${_fmtD(report.rangeStart)} — ${_fmtD(report.rangeEndExclusive.subtract(const Duration(days: 1)))} · Odbijeni: ${report.includeRejected ? 'da' : 'ne'}',
            style: pw.TextStyle(font: fontRegular, fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Sažetak', style: pw.TextStyle(font: fontBold, fontSize: 11)),
          _kv(fontRegular, fontBold, 'Broj zastoja (doprinos)', '${report.eventsTouchingPeriod}'),
          _kv(fontRegular, fontBold, 'Ukupno min u periodu', '${report.totalMinutesClipped}'),
          _kv(fontRegular, fontBold, 'Gubitak OEE (min)', '${report.minutesOeeLoss}'),
          _kv(fontRegular, fontBold, 'Gubitak OOE (min)', '${report.minutesOoeLoss}'),
          _kv(fontRegular, fontBold, 'Gubitak TEEP (min)', '${report.minutesTeepLoss}'),
          _kv(fontRegular, fontBold, 'Planirano (min)', '${report.plannedMinutes}'),
          _kv(fontRegular, fontBold, 'Neplanirano (min)', '${report.unplannedMinutes}'),
          _kv(
            fontRegular,
            fontBold,
            'MTTR prosjek (min)',
            report.mttrMinutesResolved == null
                ? '—'
                : report.mttrMinutesResolved!.toStringAsFixed(1),
          ),
          if (oeeBudgetMinutes != null && oeeBudgetMinutes > 0)
            _kv(
              fontRegular,
              fontBold,
              'Referentni cilj OEE min',
              '$oeeBudgetMinutes (ostvareno ${report.minutesOeeLoss})',
            ),
          pw.SizedBox(height: 10),
          pw.Text('Statusi', style: pw.TextStyle(font: fontBold, fontSize: 11)),
          ...report.countByStatus.entries.map(
            (e) => _kv(
              fontRegular,
              fontBold,
              DowntimeEventStatus.labelHr(e.key),
              '${e.value}',
            ),
          ),
          if (machineTargetRows != null && machineTargetRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Cilj OOE (stroj) vs OEE gubitak (zastoji)',
              style: pw.TextStyle(font: fontBold, fontSize: 11),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              children: [
                pw.TableRow(
                  children: [
                    _th('Stroj', fontBold),
                    _th('Cilj OOE', fontBold),
                    _th('Radni centar', fontBold),
                    _th('OEE min', fontBold),
                  ],
                ),
                ...machineTargetRows.map(
                  (r) => pw.TableRow(
                    children: [
                      _td(r.machineLabel, fontRegular),
                      _td(downtimeMachineTargetOoeLabel(r.targetOoeFraction), fontRegular),
                      _td(r.workCenterLabel, fontRegular),
                      _td('${r.oeeLossMinutes}', fontRegular),
                    ],
                  ),
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Text(
            'Pareto — kategorije',
            style: pw.TextStyle(font: fontBold, fontSize: 11),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            children: [
              pw.TableRow(
                children: [
                  _th('Kategorija', fontBold),
                  _th('Min', fontBold),
                  _th('%', fontBold),
                  _th('Kum %', fontBold),
                ],
              ),
              ...report.paretoCategories.take(20).map(
                    (r) => pw.TableRow(
                      children: [
                        _td(r.label, fontRegular),
                        _td('${r.minutes}', fontRegular),
                        _td(r.pctOfTotalMinutes.toStringAsFixed(1), fontRegular),
                        _td(r.cumulativePct.toStringAsFixed(1), fontRegular),
                      ],
                    ),
                  ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Radni centri (top)',
            style: pw.TextStyle(font: fontBold, fontSize: 11),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            children: [
              pw.TableRow(
                children: [
                  _th('Centar', fontBold),
                  _th('Min', fontBold),
                  _th('Kom', fontBold),
                  _th('OEE', fontBold),
                ],
              ),
              ...report.byWorkCenter.take(20).map(
                    (g) => pw.TableRow(
                      children: [
                        _td(g.label, fontRegular),
                        _td('${g.minutesClipped}', fontRegular),
                        _td('${g.events}', fontRegular),
                        _td('${g.minutesOee}', fontRegular),
                      ],
                    ),
                  ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Dnevno', style: pw.TextStyle(font: fontBold, fontSize: 11)),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            children: [
              pw.TableRow(
                children: [
                  _th('Datum', fontBold),
                  _th('Zast.', fontBold),
                  _th('Min', fontBold),
                  _th('OEE', fontBold),
                ],
              ),
              ...report.byDay.map(
                (d) => pw.TableRow(
                  children: [
                    _td(_fmtD(d.dayLocal), fontRegular),
                    _td('${d.eventCount}', fontRegular),
                    _td('${d.minutesClipped}', fontRegular),
                    _td('${d.minutesOee}', fontRegular),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _th(String t, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(t, style: pw.TextStyle(font: bold, fontSize: 8)),
    );
  }

  static pw.Widget _td(String t, pw.Font reg) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(t, style: pw.TextStyle(font: reg, fontSize: 8)),
    );
  }

  static Future<void> sharePdf({
    required DowntimeAnalyticsReport report,
    required String companyId,
    required String plantKey,
    String? plantDisplayName,
    List<DowntimeMachineTargetRow>? machineTargetRows,
    int? oeeBudgetMinutes,
  }) async {
    final bytes = await buildPdfBytes(
      report: report,
      companyId: companyId,
      plantKey: plantKey,
      plantDisplayName: plantDisplayName,
      machineTargetRows: machineTargetRows,
      oeeBudgetMinutes: oeeBudgetMinutes,
    );
    final dir = await getTemporaryDirectory();
    final safe = plantKey.trim().isEmpty ? 'plant' : plantKey.trim();
    final path =
        '${dir.path}/zastoji_analitika_${safe}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Analitika zastoja (PDF)',
    );
  }
}
