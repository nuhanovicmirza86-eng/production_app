import 'dart:convert';
import 'dart:io';

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
    await Share.shareXFiles([XFile(path)], text: 'Izvještaj karbonskog otiska (CSV)');
  }

  static Future<void> shareSummaryPdf({
    required CarbonCompanySetup setup,
    required CarbonDashboardSummary summary,
    required CarbonQuotaSettings quotas,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Karbonski otisak — pregled')),
          pw.Text(
            setup.plantKey.trim().isEmpty
                ? '${setup.companyName} • ${setup.reportingYear}'
                : '${setup.companyName} • ${setup.reportingYear} • ${setup.plantKey}',
          ),
          pw.SizedBox(height: 16),
          pw.Text('Ukupno: ${summary.totalTCO2e.toStringAsFixed(3)} tCO2e'),
          pw.Text('Scope 1: ${(summary.scope1Kg / 1000).toStringAsFixed(3)} t'),
          pw.Text('Scope 2: ${(summary.scope2Kg / 1000).toStringAsFixed(3)} t'),
          pw.Text('Scope 3: ${(summary.scope3Kg / 1000).toStringAsFixed(3)} t'),
          pw.SizedBox(height: 12),
          pw.Text(
            'tCO2e / zaposlenog: ${summary.perEmployeeTCO2e.toStringAsFixed(4)}',
          ),
          pw.Text(
            'kgCO2e / jedinici: ${summary.perUnitKgCo2e.toStringAsFixed(4)}',
          ),
          if (setup.revenue > 0)
            pw.Text(
              'tCO2e / 1000 ${setup.currency} prihoda: ${summary.per1000RevenueTCO2e.toStringAsFixed(4)}',
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Kvote: bazna ${quotas.baselineYear} • '
            'cilj iz % ${CarbonCalculationService.targetFromReductionTCO2e(quotas).toStringAsFixed(3)} t • '
            'efektivna kvota ${CarbonCalculationService.effectiveQuotaTCO2e(quotas).toStringAsFixed(3)} t',
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'karbon_${setup.reportingYear}.pdf');
  }
}
