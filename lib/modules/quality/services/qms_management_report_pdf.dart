import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/operonix_industrial_letterhead_pdf.dart';
import '../../../core/pdf/operonix_pdf_footer.dart';

/// PDF za [getQmsManagementReport] (korak 5 QMS — izvještaj za vodstvo).
class QmsManagementReportPdf {
  QmsManagementReportPdf._();

  static int _i(dynamic x, [int d = 0]) {
    if (x is int) return x;
    return int.tryParse('$x') ?? d;
  }

  static String _s(dynamic x) => (x ?? '').toString().trim();

  static Future<Uint8List> buildPdfBytes({
    required String companyLabel,
    required String companyId,
    required Map<String, dynamic> report,
  }) async {
    final fontRegular =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf').then(
              (b) => pw.Font.ttf(b),
            );
    final fontBold =
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf').then(
              (b) => pw.Font.ttf(b),
            );

    final operonixLogoBytes =
        await OperonixIndustrialLetterheadPdf.loadLogoBytes();

    final generated = DateTime.now();
    final genIso = _s(report['generatedAt']);
    final daysBack = _i(report['daysBack'], 30);

    final summary = report['summary'];
    final trend = report['inspectionTrend'];
    final openNcrs = report['openNcrs'];
    final openCapas = report['openCapas'];
    final topPfmea = report['topPfmeaByRpn'];

    final cp = summary is Map ? _i(summary['controlPlanCount']) : 0;
    final ip = summary is Map ? _i(summary['inspectionPlanCount']) : 0;
    final on = summary is Map ? _i(summary['openNcrCount']) : 0;
    final oc = summary is Map ? _i(summary['openCapaCount']) : 0;

    final ok = trend is Map ? _i(trend['okCount']) : 0;
    final nok = trend is Map ? _i(trend['nokCount']) : 0;
    final tot = trend is Map ? _i(trend['totalInPeriod']) : 0;
    final overdue = _i(report['capaOverdueCount']);

    pw.TextStyle small() => pw.TextStyle(font: fontRegular, fontSize: 8);
    pw.TextStyle h2() => pw.TextStyle(
          font: fontBold,
          fontSize: 11,
          color: PdfColors.teal900,
        );

    final doc = pw.Document(
      title: 'QMS izvještaj za vodstvo',
      author: companyLabel.isEmpty ? 'Operonix' : companyLabel,
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
                'Generisano: ${_formatLocal(generated)}',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          OperonixIndustrialLetterheadPdf.strip(logoBytes: operonixLogoBytes),
          pw.Text(
            'QMS — Izvještaj za vodstvo',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 18,
              color: PdfColors.teal900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            companyLabel.isEmpty ? 'Kompanija' : companyLabel,
            style: pw.TextStyle(font: fontBold, fontSize: 12),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Trend kontrola: zadnjih $daysBack dana (iz sustava kvalitete)',
            style: small(),
          ),
          if (genIso.isNotEmpty)
            pw.Text('Server vrijeme (UTC): $genIso', style: small()),
          pw.SizedBox(height: 14),
          pw.Text('Sažetak', style: h2()),
          pw.SizedBox(height: 6),
          _kv('Kontrolni planovi (broj zapisa)', '$cp', fontBold, fontRegular),
          _kv('Planovi kontrole', '$ip', fontBold, fontRegular),
          _kv('Otvoreni NCR', '$on', fontBold, fontRegular),
          _kv('Otvorene CAPA (ukupno)', '$oc', fontBold, fontRegular),
          _kv('CAPA s prekoračenim rokom (otvorene)', '$overdue', fontBold, fontRegular),
          pw.SizedBox(height: 10),
          pw.Text('Trend kontrola (OK / NOK)', style: h2()),
          pw.SizedBox(height: 6),
          _kv('OK u razdoblju', '$ok', fontBold, fontRegular),
          _kv('NOK u razdoblju', '$nok', fontBold, fontRegular),
          _kv('Ukupno u razdoblju', '$tot', fontBold, fontRegular),
          pw.SizedBox(height: 12),
          pw.Text('Otvoreni NCR (do 15)', style: h2()),
          pw.SizedBox(height: 6),
          if (openNcrs is List && openNcrs.isNotEmpty)
            _tableNcr(openNcrs, fontBold, fontRegular)
          else
            pw.Text('Nema otvorenih NCR.', style: small()),
          pw.SizedBox(height: 12),
          pw.Text('Otvorene CAPA (do 15)', style: h2()),
          pw.SizedBox(height: 6),
          if (openCapas is List && openCapas.isNotEmpty)
            _tableCapa(openCapas, fontBold, fontRegular)
          else
            pw.Text('Nema otvorenih CAPA.', style: small()),
          pw.SizedBox(height: 12),
          pw.Text('Top PFMEA po RPN (do 10)', style: h2()),
          pw.SizedBox(height: 6),
          if (topPfmea is List && topPfmea.isNotEmpty)
            _tablePfmea(topPfmea, fontBold, fontRegular)
          else
            pw.Text('Nema PFMEA redova.', style: small()),
        ],
      ),
    );

    return doc.save();
  }

  static String _formatLocal(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }

  static pw.Widget _kv(
    String label,
    String value,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 200,
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 9)),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableNcr(
    List<dynamic> rows,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(0.7),
        3: const pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Kod', bold, true),
            _cell('Status', bold, true),
            _cell('Sev.', bold, true),
            _cell('Opis', bold, true),
          ],
        ),
        ...rows.map((raw) {
          final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          return pw.TableRow(
            children: [
              _cell(
                _s(m['ncrCode']).isEmpty ? '—' : _s(m['ncrCode']),
                reg,
                false,
              ),
              _cell(_s(m['status']), reg, false),
              _cell(_s(m['severity']), reg, false),
              _cell(_s(m['description']), reg, false),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCapa(
    List<dynamic> rows,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.8),
        1: const pw.FlexColumnWidth(0.7),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(0.6),
        4: const pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Naslov', bold, true),
            _cell('Status', bold, true),
            _cell('Rok', bold, true),
            _cell('Povezani NCR', bold, true),
            _cell('Prekorač.', bold, true),
          ],
        ),
        ...rows.map((raw) {
          final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          final od = m['overdue'] == true;
          return pw.TableRow(
            children: [
              _cell(_s(m['title']), reg, false),
              _cell(_s(m['status']), reg, false),
              _cell(_s(m['dueDate']), reg, false),
              _cell(_s(m['sourceRefId']), reg, false),
              _cell(od ? 'Da' : 'Ne', reg, false),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tablePfmea(
    List<dynamic> rows,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.7),
        1: const pw.FlexColumnWidth(1.0),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(1.9),
        4: const pw.FlexColumnWidth(0.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('RPN', bold, true),
            _cell('Proizvod', bold, true),
            _cell('Korak', bold, true),
            _cell('Način otkazivanja', bold, true),
            _cell('AP', bold, true),
          ],
        ),
        ...rows.map((raw) {
          final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          final pn = _s(m['productName']);
          final pc = _s(m['productCode']);
          final productCell = pn.isNotEmpty
              ? (pc.isNotEmpty ? '$pn · $pc' : pn)
              : (pc.isNotEmpty ? pc : '—');
          return pw.TableRow(
            children: [
              _cell('${_i(m['rpn'])}', reg, false),
              _cell(productCell, reg, false),
              _cell(_s(m['processStep']), reg, false),
              _cell(_s(m['failureMode']), reg, false),
              _cell(_s(m['ap']), reg, false),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(String t, pw.Font f, bool header) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          font: f,
          fontSize: header ? 8 : 7,
          color: header ? PdfColors.black : PdfColors.grey900,
        ),
      ),
    );
  }
}
