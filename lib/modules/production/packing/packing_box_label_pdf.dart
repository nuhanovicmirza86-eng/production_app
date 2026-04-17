import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'packing_box_qr.dart';
import 'services/packing_box_service.dart';

/// Etiketa zatvorene kutije Stanica 1: QR + tablica stavki.
class PackingBoxLabelPdf {
  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static Future<Uint8List> buildPdf({
    required String qrJson,
    required String boxIdShort,
    required List<PackingBoxLine> lines,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');

    final doc = pw.Document(
      title: 'Kutija $boxIdShort',
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontR, bold: fontB),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(12),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Kutija — Stanica 1 (priprema)',
                style: pw.TextStyle(font: fontB, fontSize: 11),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'ID: $boxIdShort',
                style: pw.TextStyle(
                  font: fontR,
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 96,
                    height: 96,
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
                      borderRadius: pw.BorderRadius.circular(6),
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
                      'Logistika: skeniraj QR za prijem u magacin.',
                      style: pw.TextStyle(
                        font: fontR,
                        fontSize: 7,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Stavke',
                style: pw.TextStyle(font: fontB, fontSize: 9),
              ),
              pw.SizedBox(height: 4),
              ...lines.take(8).map(
                (l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(
                    '${l.productCode} · ${_fmtQty(l.qtyGood)} ${l.unit} · ${l.productName}',
                    style: pw.TextStyle(font: fontR, fontSize: 7),
                    maxLines: 2,
                  ),
                ),
              ),
              if (lines.length > 8)
                pw.Text(
                  '+ ${lines.length - 8} stavki (detalji u sustavu)',
                  style: pw.TextStyle(
                    font: fontR,
                    fontSize: 6.5,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static Future<void> printLabel({
    required String boxId,
    required String companyId,
    required String plantKey,
    required String stationKey,
    required String classification,
    required List<PackingBoxLine> lines,
  }) async {
    final qr = buildPackingBoxQrJson(
      boxId: boxId,
      companyId: companyId,
      plantKey: plantKey,
      stationKey: stationKey,
      classification: classification,
    );
    final short = boxId.length > 8 ? boxId.substring(boxId.length - 8) : boxId;
    await Printing.layoutPdf(
      name: 'kutija_$short',
      onLayout: (_) => buildPdf(
        qrJson: qr,
        boxIdShort: short,
        lines: lines,
      ),
    );
  }
}
