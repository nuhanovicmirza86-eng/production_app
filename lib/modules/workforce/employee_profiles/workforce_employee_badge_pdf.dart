import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF bedž s QR-om i čitljivim tekstom (isti princip kao etikete praćenja / stanica).
class WorkforceEmployeeBadgePdf {
  WorkforceEmployeeBadgePdf._();

  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _orDash(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  static Future<Uint8List> buildPdfBytes({
    required String qrPayload,
    required String employeeFullName,
    required String companyName,
    required String plantLabel,
    required String jobRole,
    String? catalogCode,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');

    final doc = pw.Document(
      title: 'Bedž radnika',
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontR, bold: fontB),
    );

    final name = _orDash(employeeFullName);
    final comp = _orDash(companyName);
    final plant = _orDash(plantLabel);
    final role = _orDash(jobRole);
    final codeLine = (catalogCode != null && catalogCode.trim().isNotEmpty)
        ? catalogCode.trim()
        : '—';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(14),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Operativni bedž radnika',
              style: pw.TextStyle(font: fontB, fontSize: 10.5),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Skeniraj QR u Operonix Production (Radna snaga / bedž).',
              style: pw.TextStyle(
                font: fontR,
                fontSize: 6.8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 108,
                  height: 108,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.grey600,
                      width: 0.9,
                    ),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrPayload,
                    drawText: false,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv(fontB, fontR, 'Ime i prezime', name),
                      pw.SizedBox(height: 5),
                      _kv(fontB, fontR, 'Kompanija', comp),
                      pw.SizedBox(height: 5),
                      _kv(fontB, fontR, 'Pogon', plant),
                      pw.SizedBox(height: 5),
                      _kv(fontB, fontR, 'Uloga', role),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey400, height: 1),
            pw.SizedBox(height: 6),
            pw.Text(
              'Sistemski kôd: $codeLine',
              style: pw.TextStyle(
                font: fontR,
                fontSize: 7.5,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _kv(
    pw.Font fontB,
    pw.Font fontR,
    String label,
    String value,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fontB,
            fontSize: 7,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: fontR, fontSize: 9),
        ),
      ],
    );
  }

  /// Ispis / dijeljenje kroz dijalog sustava (isto kao etikete na stanicama).
  static Future<void> printBadge({
    required String qrPayload,
    required String employeeFullName,
    required String companyName,
    required String plantLabel,
    required String jobRole,
    String? catalogCode,
    String fileName = 'operonix_bedz_radnik',
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    await Printing.layoutPdf(
      name: safe,
      onLayout: (_) => buildPdfBytes(
        qrPayload: qrPayload,
        employeeFullName: employeeFullName,
        companyName: companyName,
        plantLabel: plantLabel,
        jobRole: jobRole,
        catalogCode: catalogCode,
      ),
    );
  }

  /// Isti PDF kao [printBadge], datoteka kroz [Share] (e-pošta, Upravitelj, …).
  static Future<void> shareBadge({
    required String qrPayload,
    required String employeeFullName,
    required String companyName,
    required String plantLabel,
    required String jobRole,
    String? catalogCode,
    String fileName = 'operonix_bedz_radnik',
  }) async {
    final safeName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final outName = '$safeName.pdf';
    final bytes = await buildPdfBytes(
      qrPayload: qrPayload,
      employeeFullName: employeeFullName,
      companyName: companyName,
      plantLabel: plantLabel,
      jobRole: jobRole,
      catalogCode: catalogCode,
    );
    final label = _orDash(employeeFullName);
    await Printing.sharePdf(
      bytes: bytes,
      filename: outName,
      body: 'Operonix — bedž radnika ($label)',
    );
  }
}
