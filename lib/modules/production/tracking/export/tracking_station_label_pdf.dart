import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../production_orders/printing/bom_classification_catalog.dart';
import '../config/station_tracking_setup_store.dart';

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
    String labelLayoutKey = kStationLabelLayoutStandard,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');
    final layout = kStationLabelLayoutKeys.contains(labelLayoutKey)
        ? labelLayoutKey
        : kStationLabelLayoutStandard;

    final doc = pw.Document(
      title: 'Etiketa — $phaseTitle',
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontR, bold: fontB),
    );

    pw.Widget pageBody;
    switch (layout) {
      case kStationLabelLayoutCompact:
        pageBody = _compactBody(
          fontR: fontR,
          fontB: fontB,
          phaseTitle: phaseTitle,
          classification: classification,
          qrJson: qrJson,
        );
        break;
      case kStationLabelLayoutMinimal:
        pageBody = _minimalBody(
          fontR: fontR,
          fontB: fontB,
          phaseTitle: phaseTitle,
          classification: classification,
          qrJson: qrJson,
        );
        break;
      default:
        pageBody = _standardBody(
          fontR: fontR,
          fontB: fontB,
          phaseTitle: phaseTitle,
          classification: classification,
          qrJson: qrJson,
        );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: layout == kStationLabelLayoutMinimal
            ? const pw.EdgeInsets.all(18)
            : const pw.EdgeInsets.all(14),
        build: (context) => pageBody,
      ),
    );

    return doc.save();
  }

  static pw.Widget _standardBody({
    required pw.Font fontR,
    required pw.Font fontB,
    required String phaseTitle,
    required String classification,
    required String qrJson,
  }) {
    final clsTitle = bomClassificationTitleBs(classification);
    final logistics = bomClassificationLogisticsLabelBs(classification);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(phaseTitle, style: pw.TextStyle(font: fontB, fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.Text(
          logistics,
          style: pw.TextStyle(
            font: fontB,
            fontSize: 8.5,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Klasifikacija: $clsTitle ($classification)',
          style: pw.TextStyle(
            font: fontR,
            fontSize: 7.5,
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
                style: pw.TextStyle(
                  font: fontR,
                  fontSize: 7.2,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _compactBody({
    required pw.Font fontR,
    required pw.Font fontB,
    required String phaseTitle,
    required String classification,
    required String qrJson,
  }) {
    final clsTitle = bomClassificationTitleBs(classification);
    final logistics = bomClassificationLogisticsLabelBs(classification);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(phaseTitle, style: pw.TextStyle(font: fontB, fontSize: 9.5)),
        pw.SizedBox(height: 2),
        pw.Text(
          logistics,
          style: pw.TextStyle(
            font: fontB,
            fontSize: 7.2,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          '$clsTitle · $classification',
          style: pw.TextStyle(
            font: fontR,
            fontSize: 6.8,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 92,
              height: 92,
              padding: const pw.EdgeInsets.all(3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrJson,
                drawText: false,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(
                'JSON etiketa — skeniraj istim čitačem.',
                style: pw.TextStyle(
                  font: fontR,
                  fontSize: 6.5,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _minimalBody({
    required pw.Font fontR,
    required pw.Font fontB,
    required String phaseTitle,
    required String classification,
    required String qrJson,
  }) {
    final clsTitle = bomClassificationTitleBs(classification);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          phaseTitle,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontB, fontSize: 9),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '$clsTitle ($classification)',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: fontR,
            fontSize: 7,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Container(
            width: 118,
            height: 118,
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
        ),
      ],
    );
  }

  static Future<void> printLabel({
    required String phaseTitle,
    required String qrJson,
    required String classification,
    String labelLayoutKey = kStationLabelLayoutStandard,
  }) async {
    await Printing.layoutPdf(
      name: 'etiketa_pracenje',
      onLayout: (_) => buildPdf(
        qrJson: qrJson,
        phaseTitle: phaseTitle,
        classification: classification,
        labelLayoutKey: labelLayoutKey,
      ),
    );
  }

  /// Gotov PDF (npr. kupčeva etiketa uploadana na proizvod).
  static Future<void> printPrebuiltPdfBytes(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      name: 'etiketa_prilagodjena',
      onLayout: (_) async => pdfBytes,
    );
  }

  /// Slika (PNG/JPG) u jednu A6 stranicu za ispis.
  static Future<void> printRasterImageAsA6Pdf(Uint8List imageBytes) async {
    final image = pw.MemoryImage(imageBytes);
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final doc = pw.Document(
      title: 'Etiketa — prilagođena',
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontR),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(10),
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
    await Printing.layoutPdf(
      name: 'etiketa_prilagodjena',
      onLayout: (_) async => doc.save(),
    );
  }
}
