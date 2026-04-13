import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../production_orders/printing/bom_classification_catalog.dart';

/// Jedna etiketa s QR-om (isti JSON kao [classification_label_print_qr]) za operativne stanice.
class TrackingStationLabelPdf {
  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static Future<Uint8List> buildPdf({
    required String qrJson,
    required String phaseTitle,
    required String classification,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');
    final clsTitle = bomClassificationTitleBs(classification);
    final logistics = bomClassificationLogisticsLabelBs(classification);

    final doc = pw.Document(
      title: 'Etiketa — $phaseTitle',
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontR, bold: fontB),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(14),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                phaseTitle,
                style: pw.TextStyle(font: fontB, fontSize: 11),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                logistics,
                style: pw.TextStyle(font: fontB, fontSize: 8.5, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Klasifikacija: $clsTitle ($classification)',
                style: pw.TextStyle(font: fontR, fontSize: 7.5, color: PdfColors.grey700),
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
                      border: pw.Border.all(color: PdfColors.grey600, width: 0.9),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrJson,
                      drawText: false,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      'Skeniraj istim QR čitačem kao za pripremnu etiketu (JSON na naljepnici).',
                      style: pw.TextStyle(font: fontR, fontSize: 7.2, color: PdfColors.grey700),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static Future<void> printLabel({
    required String phaseTitle,
    required String qrJson,
    required String classification,
  }) async {
    await Printing.layoutPdf(
      name: 'etiketa_pracenje',
      onLayout: (_) => buildPdf(
        qrJson: qrJson,
        phaseTitle: phaseTitle,
        classification: classification,
      ),
    );
  }
}
