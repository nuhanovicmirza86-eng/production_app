import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/carbon_models.dart';
import 'carbon_calculation_service.dart';

class CarbonExportService {
  const CarbonExportService._();

  static String buildCsv({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    final header = [
      'companyId',
      'companyName',
      'reportingYear',
      'plantKey',
      'activityDate',
      'scope',
      'category',
      'activityType',
      'description',
      'quantity',
      'unit',
      'factorKey',
      'factorValue',
      'factorSource',
      'co2eKg',
      'co2eT',
      'evidenceRef',
    ];
    final sb = StringBuffer();
    sb.writeln(header.map(_csvEscape).join(';'));

    for (final a in activities) {
      if (!a.include) continue;
      final f = factorsByKey[a.factorKey];
      final kg = CarbonCalculationService.lineKgCo2e(a, factorsByKey);
      final row = [
        setup.companyId,
        setup.companyName,
        setup.reportingYear.toString(),
        a.plantKey,
        a.activityDate,
        f?.scope ?? '',
        f?.category ?? '',
        a.activityType,
        a.description,
        a.quantity.toString(),
        a.unit,
        a.factorKey,
        f?.factorKgCo2ePerUnit.toString() ?? '',
        f?.sourceName ?? '',
        kg.toStringAsFixed(3),
        (kg / 1000).toStringAsFixed(6),
        a.evidenceRef,
      ];
      sb.writeln(row.map(_csvEscape).join(';'));
    }

    return sb.toString();
  }

  static String _csvEscape(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static Future<void> shareCsv({
    required String fileName,
    required String csvContent,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final f = File(path);
    await f.writeAsString(csvContent, encoding: utf8);
    await Share.shareXFiles([
      XFile(path),
    ], text: 'Izvještaj karbonskog otiska (CSV)');
  }

  static Future<pw.Font> _loadFont(String asset) async {
    final bytes = await rootBundle.load(asset);
    return pw.Font.ttf(bytes);
  }

  static double _safeTargetReductionT(CarbonQuotaSettings q) {
    final t = CarbonCalculationService.targetFromReductionTCO2e(q);
    if (t.isNaN || t.isInfinite) return 0;
    return t < 0 ? 0 : t;
  }

  /// PDF sa Noto fontom (latinica / dijakritici), pregled preko sistema dijela/štampe.
  static Future<Uint8List> buildSummaryPdfBytes({
    required CarbonCompanySetup setup,
    required CarbonDashboardSummary summary,
    required CarbonQuotaSettings quotas,
  }) async {
    final fontRegular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');
    final generated = DateTime.now();

    pw.TextStyle labelStyle() =>
        pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800);

    pw.TextStyle valueStyle() => pw.TextStyle(font: fontRegular, fontSize: 9);

    pw.Widget kv(String label, String value) {
      final v = value.trim().isEmpty ? '—' : value.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 150, child: pw.Text(label, style: labelStyle())),
            pw.Expanded(child: pw.Text(v, style: valueStyle())),
          ],
        ),
      );
    }

    final eff = CarbonCalculationService.effectiveQuotaTCO2e(quotas);
    final targetPct = _safeTargetReductionT(quotas);
    final dev = eff > 0 ? (summary.totalTCO2e - eff) : 0.0;

    final doc = pw.Document(
      title: 'Karbonski otisak ${setup.reportingYear}',
      author: setup.companyName.isEmpty ? 'Production' : setup.companyName,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Generisano: ${_formatDateTime(generated)}',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            'Izvještaj o karbonskom otisku',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 18,
              color: PdfColors.teal900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${setup.companyName} - ${setup.reportingYear}. godina',
            style: pw.TextStyle(font: fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'ID kompanije (sistem): ${setup.companyId}',
            style: valueStyle(),
          ),
          if (setup.plantKey.trim().isNotEmpty)
            pw.Text('Pogon: ${setup.plantKey}', style: valueStyle()),
          pw.SizedBox(height: 16),
          pw.Text(
            '1. Podaci o organizaciji',
            style: pw.TextStyle(font: fontBold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          kv('Država (ISO)', setup.countryCode),
          kv('Grad / lokacija', setup.city),
          kv('Djelatnost', setup.industry),
          kv('Obuhvat perioda', setup.period),
          kv('Valuta (prihod)', setup.currency),
          kv('Broj zaposlenih', setup.employeeCount.toString()),
          kv('Prihod', setup.revenue.toStringAsFixed(2)),
          kv('Proizvedene jedinice', setup.unitsProduced.toStringAsFixed(2)),
          kv('Broj lokacija', setup.locationCount.toString()),
          kv('Granice / napomena', setup.boundaryNotes),
          pw.SizedBox(height: 14),
          pw.Text(
            '2. Sažetak emisija (iz aktivnosti)',
            style: pw.TextStyle(font: fontBold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Pokazatelj', fontBold, true),
                  _pdfCell('Vrijednost', fontBold, true),
                ],
              ),
              _pdfMetricRow(
                fontRegular,
                'Ukupno',
                '${summary.totalTCO2e.toStringAsFixed(3)} tCO2e',
              ),
              _pdfMetricRow(
                fontRegular,
                'Scope 1',
                '${(summary.scope1Kg / 1000).toStringAsFixed(3)} t',
              ),
              _pdfMetricRow(
                fontRegular,
                'Scope 2',
                '${(summary.scope2Kg / 1000).toStringAsFixed(3)} t',
              ),
              _pdfMetricRow(
                fontRegular,
                'Scope 3',
                '${(summary.scope3Kg / 1000).toStringAsFixed(3)} t',
              ),
              _pdfMetricRow(
                fontRegular,
                'tCO2e / zaposlenog',
                setup.employeeCount <= 0
                    ? '—'
                    : summary.perEmployeeTCO2e.toStringAsFixed(4),
              ),
              _pdfMetricRow(
                fontRegular,
                'kgCO2e / jedinici',
                setup.unitsProduced <= 0
                    ? '—'
                    : summary.perUnitKgCo2e.toStringAsFixed(4),
              ),
              if (setup.revenue > 0)
                _pdfMetricRow(
                  fontRegular,
                  'tCO2e / 1000 ${setup.currency} prihoda',
                  summary.per1000RevenueTCO2e.toStringAsFixed(4),
                ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            '3. Kvote i ciljevi',
            style: pw.TextStyle(font: fontBold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          kv('Bazna godina', quotas.baselineYear.toString()),
          kv(
            'Bazne emisije (tCO2e)',
            quotas.baselineEmissionsTCO2e.toStringAsFixed(3),
          ),
          kv(
            'Cilj smanjenja (%)',
            quotas.reductionTargetPercent.toStringAsFixed(2),
          ),
          kv(
            'Cilj iz postotka (tCO2e)',
            quotas.baselineEmissionsTCO2e <= 0 ||
                    quotas.reductionTargetPercent <= 0
                ? '—'
                : targetPct.toStringAsFixed(3),
          ),
          kv(
            'Apsolutna kvota (tCO2e)',
            quotas.absoluteQuotaTCO2e > 0
                ? quotas.absoluteQuotaTCO2e.toStringAsFixed(3)
                : '— (koristi se postotak)',
          ),
          kv(
            'Efektivna kvota (tCO2e)',
            eff <= 0 ? '—' : eff.toStringAsFixed(3),
          ),
          kv(
            'Odstupanje od kvote (+ iznad)',
            eff <= 0 ? '—' : dev.toStringAsFixed(3),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfCell(String text, pw.Font font, bool header) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.TableRow _pdfMetricRow(pw.Font font, String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9)),
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }

  /// Otvara sistemski pregled PDF-a (možeš sačuvati, podijeliti, odštampati).
  static Future<void> previewSummaryPdf({
    required CarbonCompanySetup setup,
    required CarbonDashboardSummary summary,
    required CarbonQuotaSettings quotas,
  }) async {
    final safeName = _safeFileName(setup.companyName, setup.reportingYear);
    await Printing.layoutPdf(
      name: safeName,
      onLayout: (_) =>
          buildSummaryPdfBytes(setup: setup, summary: summary, quotas: quotas),
    );
  }

  static String _safeFileName(String companyName, int year) {
    final base = companyName.trim().isEmpty ? 'karbon' : companyName.trim();
    final cleaned = base
        .replaceAll(RegExp(r'[^\w\s-]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final prefix = cleaned.isEmpty ? 'karbon' : cleaned;
    return '${prefix}_$year.pdf';
  }
}
