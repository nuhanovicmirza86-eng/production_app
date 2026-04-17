import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/pdf/operonix_pdf_footer.dart';
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
      'productId',
      'productCode',
      'productLabel',
      'productOutputQty',
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
        a.productId,
        a.productCode,
        a.productLabel,
        a.productOutputQty.toString(),
      ];
      sb.writeln(row.map(_csvEscape).join(';'));
    }

    return sb.toString();
  }

  /// Jedan red po `plantKey`: zbroj tCO2e i udio u ukupnom (iz uključenih aktivnosti).
  static String buildCsvPlantSummary({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    final rollups = CarbonCalculationService.rollupsByPlant(
      activities: activities,
      factorsByKey: factorsByKey,
    );
    var totalKg = 0.0;
    for (final r in rollups) {
      totalKg += r.totalKgCo2e;
    }
    final header = [
      'companyId',
      'companyName',
      'reportingYear',
      'plantKey',
      'totalKgCO2e',
      'totalTCO2e',
      'lineCount',
      'shareOfCompanyPercent',
    ];
    final sb = StringBuffer();
    sb.writeln(header.map(_csvEscape).join(';'));
    for (final r in rollups) {
      final share = totalKg > 0 ? (r.totalKgCo2e / totalKg) * 100.0 : 0.0;
      final row = [
        setup.companyId,
        setup.companyName,
        setup.reportingYear.toString(),
        r.plantKey,
        r.totalKgCo2e.toStringAsFixed(3),
        r.totalTCO2e.toStringAsFixed(6),
        r.lineCount.toString(),
        share.toStringAsFixed(2),
      ];
      sb.writeln(row.map(_csvEscape).join(';'));
    }
    return sb.toString();
  }

  /// Jedan red po `productId` (samo redovi s unesenim productId).
  static String buildCsvProductSummary({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) {
    final rollups = CarbonCalculationService.rollupsByProduct(
      activities: activities,
      factorsByKey: factorsByKey,
    );
    var totalKgProducts = 0.0;
    for (final r in rollups) {
      totalKgProducts += r.totalKgCo2e;
    }
    var totalKgCompany = 0.0;
    for (final a in activities) {
      if (!a.include) continue;
      totalKgCompany += CarbonCalculationService.lineKgCo2e(a, factorsByKey);
    }
    final header = [
      'companyId',
      'companyName',
      'reportingYear',
      'productId',
      'productCode',
      'productLabel',
      'totalProductOutputQty',
      'totalKgCO2e',
      'totalTCO2e',
      'lineCount',
      'shareAmongAttributedProductsPercent',
      'shareOfCompanyTotalPercent',
    ];
    final sb = StringBuffer();
    sb.writeln(header.map(_csvEscape).join(';'));
    for (final r in rollups) {
      final shareAmong = totalKgProducts > 0
          ? (r.totalKgCo2e / totalKgProducts) * 100.0
          : 0.0;
      final shareCompany = totalKgCompany > 0
          ? (r.totalKgCo2e / totalKgCompany) * 100.0
          : 0.0;
      final row = [
        setup.companyId,
        setup.companyName,
        setup.reportingYear.toString(),
        r.productId,
        r.productCode,
        r.productLabel,
        r.totalProductOutputQty.toStringAsFixed(3),
        r.totalKgCo2e.toStringAsFixed(3),
        r.totalTCO2e.toStringAsFixed(6),
        r.lineCount.toString(),
        shareAmong.toStringAsFixed(2),
        shareCompany.toStringAsFixed(2),
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
    List<CarbonPlantRollup>? plantRollups,
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
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              OperonixPdfFooter.multiPageFooter(ctx, fontRegular),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generisano: ${_formatDateTime(generated)}',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
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
          if (plantRollups != null && plantRollups.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              '4. Razrada po pogonima (tCO2e)',
              style: pw.TextStyle(font: fontBold, fontSize: 11),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Zbroj uključenih aktivnosti po polju plantKey. Ukupno kompanije '
              '${summary.totalTCO2e.toStringAsFixed(3)} tCO2e.',
              style: valueStyle(),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Pogon (plantKey)', fontBold, true),
                    _pdfCell('tCO2e', fontBold, true),
                    _pdfCell('Redova', fontBold, true),
                  ],
                ),
                for (final p in plantRollups)
                  pw.TableRow(
                    children: [
                      _pdfCell(
                        p.displayPlant,
                        fontRegular,
                        false,
                      ),
                      _pdfCell(
                        p.totalTCO2e.toStringAsFixed(3),
                        fontRegular,
                        false,
                      ),
                      _pdfCell(
                        '${p.lineCount}',
                        fontRegular,
                        false,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfCell(
    String text,
    pw.Font font,
    bool header, {
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
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
    List<CarbonPlantRollup>? plantRollups,
  }) async {
    final safeName = _safeFileName(setup.companyName, setup.reportingYear);
    await Printing.layoutPdf(
      name: safeName,
      onLayout: (_) => buildSummaryPdfBytes(
        setup: setup,
        summary: summary,
        quotas: quotas,
        plantRollups: plantRollups,
      ),
    );
  }

  static pw.Widget _rollupPdfFooter(
    pw.Context ctx,
    pw.Font fontRegular,
    DateTime generated,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          OperonixPdfFooter.multiPageFooter(ctx, fontRegular),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generisano: ${_formatDateTime(generated)}',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _pdfCompanyIdentityBlock({
    required CarbonCompanySetup setup,
    required pw.Font fontRegular,
    required pw.Font fontBold,
  }) {
    final valueStyle = pw.TextStyle(font: fontRegular, fontSize: 9);
    return [
      pw.Text(
        setup.companyName.isEmpty ? 'Kompanija' : setup.companyName,
        style: pw.TextStyle(font: fontBold, fontSize: 13),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '${setup.reportingYear}. godina · ID: ${setup.companyId}',
        style: valueStyle,
      ),
      pw.Text('Država: ${setup.countryCode} · ${setup.city}', style: valueStyle),
      pw.SizedBox(height: 10),
    ];
  }

  static pw.Table _pdfScopeSummaryTable({
    required CarbonDashboardSummary s,
    required pw.Font fontRegular,
    required pw.Font fontBold,
  }) {
    return pw.Table(
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
          s.totalTCO2e.toStringAsFixed(3),
        ),
        _pdfMetricRow(
          fontRegular,
          'Scope 1',
          '${(s.scope1Kg / 1000).toStringAsFixed(3)} t',
        ),
        _pdfMetricRow(
          fontRegular,
          'Scope 2',
          '${(s.scope2Kg / 1000).toStringAsFixed(3)} t',
        ),
        _pdfMetricRow(
          fontRegular,
          'Scope 3',
          '${(s.scope3Kg / 1000).toStringAsFixed(3)} t',
        ),
      ],
    );
  }

  /// PDF: zbroj po pogonu — tablica scope 1/2/3 po svakom pogonu + ukupno kompanije.
  static Future<Uint8List> buildPlantRollupReportPdfBytes({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) async {
    final fontRegular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');
    final generated = DateTime.now();
    final companySummary = CarbonCalculationService.summarize(
      setup: setup,
      activities: activities,
      factorsByKey: factorsByKey,
    );
    final plants = CarbonCalculationService.rollupsByPlantWithScopes(
      activities: activities,
      factorsByKey: factorsByKey,
    );

    final doc = pw.Document(
      title: 'Zbroj po pogonu ${setup.reportingYear}',
      author: setup.companyName.isEmpty ? 'Production' : setup.companyName,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => _rollupPdfFooter(ctx, fontRegular, generated),
        build: (ctx) => [
          pw.Text(
            'Zbroj emisija po pogonu',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 16,
              color: PdfColors.teal900,
            ),
          ),
          pw.SizedBox(height: 6),
          ..._pdfCompanyIdentityBlock(
            setup: setup,
            fontRegular: fontRegular,
            fontBold: fontBold,
          ),
          pw.Text(
            '1. Ukupno kompanije (sve uključene aktivnosti s emisijom)',
            style: pw.TextStyle(font: fontBold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          _pdfScopeSummaryTable(
            s: companySummary,
            fontRegular: fontRegular,
            fontBold: fontBold,
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            '2. Razrada po pogonu (tCO2e po GHG scopeu)',
            style: pw.TextStyle(font: fontBold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          if (plants.isEmpty)
            pw.Text(
              'Nema podataka za razradu (nema uključenih redova s emisijom).',
              style: pw.TextStyle(font: fontRegular, fontSize: 9),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Pogon', fontBold, true, fontSize: 8),
                    _pdfCell('Sc1 (t)', fontBold, true, fontSize: 8),
                    _pdfCell('Sc2 (t)', fontBold, true, fontSize: 8),
                    _pdfCell('Sc3 (t)', fontBold, true, fontSize: 8),
                    _pdfCell('Ukupno (t)', fontBold, true, fontSize: 8),
                    _pdfCell('Redova', fontBold, true, fontSize: 8),
                  ],
                ),
                for (final p in plants)
                  pw.TableRow(
                    children: [
                      _pdfCell(p.displayPlant, fontRegular, false, fontSize: 8),
                      _pdfCell(
                        (p.scope1Kg / 1000).toStringAsFixed(3),
                        fontRegular,
                        false,
                        fontSize: 8,
                      ),
                      _pdfCell(
                        (p.scope2Kg / 1000).toStringAsFixed(3),
                        fontRegular,
                        false,
                        fontSize: 8,
                      ),
                      _pdfCell(
                        (p.scope3Kg / 1000).toStringAsFixed(3),
                        fontRegular,
                        false,
                        fontSize: 8,
                      ),
                      _pdfCell(
                        p.totalTCO2e.toStringAsFixed(3),
                        fontRegular,
                        false,
                        fontSize: 8,
                      ),
                      _pdfCell(
                        '${p.lineCount}',
                        fontRegular,
                        false,
                        fontSize: 8,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  /// PDF: proizvodi — po pogonima, tablice s scope 1/2/3 (šifra + naziv, bez ID-a).
  static Future<Uint8List> buildProductRollupByPlantReportPdfBytes({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) async {
    final fontRegular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');
    final generated = DateTime.now();
    final companySummary = CarbonCalculationService.summarize(
      setup: setup,
      activities: activities,
      factorsByKey: factorsByKey,
    );
    final attributed = CarbonCalculationService.activitiesAttributedToProducts(
      activities,
    );
    final attributedSummary = CarbonCalculationService.summarize(
      setup: setup,
      activities: attributed,
      factorsByKey: factorsByKey,
    );
    final rows = CarbonCalculationService.rollupsByPlantThenProduct(
      activities: activities,
      factorsByKey: factorsByKey,
    );

    final byPlant = <String, List<CarbonProductPlantRollup>>{};
    for (final r in rows) {
      byPlant.putIfAbsent(r.plantKey, () => []).add(r);
    }
    final plantOrder = byPlant.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty && b.isNotEmpty) return 1;
        if (a.isNotEmpty && b.isEmpty) return -1;
        return a.compareTo(b);
      });

    final doc = pw.Document(
      title: 'Zbroj po proizvodu ${setup.reportingYear}',
      author: setup.companyName.isEmpty ? 'Production' : setup.companyName,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    final body = <pw.Widget>[
      pw.Text(
        'Zbroj emisija po proizvodu (po pogonima)',
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 16,
          color: PdfColors.teal900,
        ),
      ),
      pw.SizedBox(height: 6),
      ..._pdfCompanyIdentityBlock(
        setup: setup,
        fontRegular: fontRegular,
        fontBold: fontBold,
      ),
      pw.Text(
        '1. Ukupno kompanije (sve uključene aktivnosti)',
        style: pw.TextStyle(font: fontBold, fontSize: 11),
      ),
      pw.SizedBox(height: 6),
      _pdfScopeSummaryTable(
        s: companySummary,
        fontRegular: fontRegular,
        fontBold: fontBold,
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        '2. Samo redovi s dodijeljenim proizvodom',
        style: pw.TextStyle(font: fontBold, fontSize: 11),
      ),
      pw.SizedBox(height: 6),
      if (attributed.isEmpty)
        pw.Text(
          'Nema aktivnosti s odabranim proizvodom.',
          style: pw.TextStyle(font: fontRegular, fontSize: 9),
        )
      else ...[
        _pdfScopeSummaryTable(
          s: attributedSummary,
          fontRegular: fontRegular,
          fontBold: fontBold,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          '3. Razrada po pogonu i proizvodu',
          style: pw.TextStyle(font: fontBold, fontSize: 11),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Kolone: emisije u tCO2e po GHG scopeu; „Σ pr.k.” = zbroj opcionalne '
          'proizvedene količine uz red.',
          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
      ],
    ];

    if (attributed.isNotEmpty) {
      for (final pk in plantOrder) {
        final list = byPlant[pk]!;
        final title = list.first.displayPlant;
        body.add(pw.SizedBox(height: 10));
        body.add(
          pw.Text(
            'Pogon: $title',
            style: pw.TextStyle(font: fontBold, fontSize: 10),
          ),
        );
        body.add(pw.SizedBox(height: 4));
        body.add(
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Proizvod', fontBold, true, fontSize: 7),
                  _pdfCell('Šifra', fontBold, true, fontSize: 7),
                  _pdfCell('Sc1', fontBold, true, fontSize: 7),
                  _pdfCell('Sc2', fontBold, true, fontSize: 7),
                  _pdfCell('Sc3', fontBold, true, fontSize: 7),
                  _pdfCell('Ukup.', fontBold, true, fontSize: 7),
                  _pdfCell('n', fontBold, true, fontSize: 7),
                  _pdfCell('Σ pr.k.', fontBold, true, fontSize: 7),
                ],
              ),
              for (final r in list)
                pw.TableRow(
                  children: [
                    _pdfCell(
                      r.displayProductTitle,
                      fontRegular,
                      false,
                      fontSize: 7,
                    ),
                    _pdfCell(
                      r.productCode.trim().isEmpty ? '—' : r.productCode.trim(),
                      fontRegular,
                      false,
                      fontSize: 7,
                    ),
                    _pdfCell(
                      (r.scope1Kg / 1000).toStringAsFixed(2),
                      fontRegular,
                      false,
                      fontSize: 7,
                    ),
                    _pdfCell(
                      (r.scope2Kg / 1000).toStringAsFixed(2),
                      fontRegular,
                      false,
                      fontSize: 7,
                    ),
                    _pdfCell(
                      (r.scope3Kg / 1000).toStringAsFixed(2),
                      fontRegular,
                      false,
                      fontSize: 7,
                    ),
                    _pdfCell(
                      r.totalTCO2e.toStringAsFixed(2),
                      fontRegular,
                      false,
                      fontSize: 7,
                    ),
                    _pdfCell('${r.lineCount}', fontRegular, false, fontSize: 7),
                    _pdfCell(
                      r.totalProductOutputQty > 0
                          ? r.totalProductOutputQty.toStringAsFixed(1)
                          : '—',
                      fontRegular,
                      false,
                      fontSize: 7,
                    ),
                  ],
                ),
            ],
          ),
        );
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => _rollupPdfFooter(ctx, fontRegular, generated),
        build: (ctx) => body,
      ),
    );

    return doc.save();
  }

  static Future<void> previewPlantRollupPdf({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) async {
    final base = 'karbon_po_pogonu_${setup.companyId}_${setup.reportingYear}';
    await Printing.layoutPdf(
      name: '${base}_pregled.pdf',
      onLayout: (_) => buildPlantRollupReportPdfBytes(
        setup: setup,
        activities: activities,
        factorsByKey: factorsByKey,
      ),
    );
  }

  static Future<void> previewProductRollupByPlantPdf({
    required CarbonCompanySetup setup,
    required List<CarbonActivityLine> activities,
    required Map<String, CarbonEmissionFactor> factorsByKey,
  }) async {
    final base = 'karbon_po_proizvodu_${setup.companyId}_${setup.reportingYear}';
    await Printing.layoutPdf(
      name: '${base}_pregled.pdf',
      onLayout: (_) => buildProductRollupByPlantReportPdfBytes(
        setup: setup,
        activities: activities,
        factorsByKey: factorsByKey,
      ),
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
