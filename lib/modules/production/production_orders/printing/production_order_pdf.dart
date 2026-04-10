import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/production_order_model.dart';
import 'bom_classification_catalog.dart';
import 'classification_label_print_qr.dart';
import 'production_order_qr_payload.dart';

class ProductionOrderPdf {
  static PdfColor pdfColorForOrderStatus(String status) {
    switch (status) {
      case 'draft':
        return PdfColors.grey700;
      case 'released':
        return PdfColors.blue;
      case 'in_progress':
        return PdfColors.orange;
      case 'paused':
        return PdfColors.deepOrange;
      case 'completed':
        return PdfColors.green;
      case 'closed':
        return PdfColors.teal;
      case 'cancelled':
        return PdfColors.red;
      default:
        return PdfColors.black;
    }
  }

  static String _statusLabelBs(String status) {
    switch (status) {
      case 'draft':
        return 'Nacrt';
      case 'released':
        return 'Pušten';
      case 'in_progress':
        return 'U toku';
      case 'paused':
        return 'Pauziran';
      case 'completed':
        return 'Završen';
      case 'closed':
        return 'Zatvoren';
      case 'cancelled':
        return 'Otkazan';
      default:
        return status;
    }
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  static Future<pw.Font> _loadFont(String asset) async {
    final bytes = await rootBundle.load(asset);
    return pw.Font.ttf(bytes);
  }

  static Future<Uint8List> buildWorkOrderPdf({
    required ProductionOrderModel order,
    DateTime? printedAt,
  }) async {
    final fontRegular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');

    final qrPayload = buildProductionOrderQrPayload(
      companyId: order.companyId,
      plantKey: order.plantKey,
      productionOrderId: order.id,
      productionOrderCode: order.productionOrderCode,
    );

    final statusColor = pdfColorForOrderStatus(order.status);
    final now = printedAt ?? DateTime.now();

    pw.Widget kv(String label, String value) {
      final v = value.trim().isEmpty ? '—' : value.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 140,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                v,
                style: pw.TextStyle(font: fontRegular, fontSize: 9),
              ),
            ),
          ],
        ),
      );
    }

    final doc = pw.Document(
      title: 'Proizvodni nalog ${order.productionOrderCode}',
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PROIZVODNI NALOG',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 18,
                            color: PdfColors.grey900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          order.productionOrderCode,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: pw.BoxDecoration(
                            color: statusColor,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            _statusLabelBs(order.status),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 112,
                    height: 112,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrPayload,
                      drawText: false,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Obavezni podaci',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 8),
              kv('Šifra proizvoda', order.productCode),
              kv('Naziv proizvoda', order.productName),
              kv('Kupac', order.customerName ?? ''),
              kv(
                'Planirana količina',
                '${_formatQty(order.plannedQty)} ${order.unit}',
              ),
              kv('Planirani početak', _formatDateTime(order.scheduledStartAt)),
              kv('Rok izrade', _formatDateTime(order.scheduledEndAt)),
              kv('Pogon (plantKey)', order.plantKey),
              kv('BOM ID', order.bomId),
              kv('BOM verzija', order.bomVersion),
              kv('Routing ID', order.routingId),
              kv('Routing verzija', order.routingVersion),
              kv('Linija', order.lineId ?? ''),
              kv('Mašina', order.machineId ?? ''),
              if (order.sourceOrderNumber != null &&
                  order.sourceOrderNumber!.trim().isNotEmpty) ...[
                kv('Izvorna narudžba', order.sourceOrderNumber!.trim()),
                kv(
                  'Kupac (narudžba)',
                  order.sourceCustomerName ?? '',
                ),
              ],
              if (order.hasCriticalChanges)
                kv('Napomena', 'Nalog ima kritične izmjene nakon kreiranja.'),
              pw.SizedBox(height: 12),
              pw.Text(
                'Referenca uputstava',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 6),
              kv('Verzija uputstva za rad', '—'),
              kv('Verzija uputstva za pakovanje', '—'),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Text(
                'Ispis: ${_formatDateTime(now)} · QR: po:v1 (id + broj naloga).',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 7.5,
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

  static Future<Uint8List> buildClassificationLabelsPdf({
    required ProductionOrderModel order,
    required List<String> classifications,
    required String operatorName,
    required double packagingQty,
    DateTime? printedAt,
  }) async {
    final fontRegular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');

    final now = printedAt ?? DateTime.now();

    final doc = pw.Document(
      title: 'Etikete PN ${order.productionOrderCode}',
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    pw.Widget labelBlock(String classification) {
      final qtyText = '${_formatQty(packagingQty)} ${order.unit}';
      final qrData = buildClassificationLabelPrintQrJson(
        productionOrderCode: order.productionOrderCode,
        productCode: order.productCode,
        pieceName: order.productName,
        quantityText: qtyText,
        operatorName: operatorName,
        printedAt: now,
        classification: classification,
      );

      final clsTitle = bomClassificationTitleBs(classification);
      final logistics = bomClassificationLogisticsLabelBs(classification);

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 102,
                  height: 102,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    drawText: false,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.SizedBox(
                  width: 102,
                  child: pw.Text(
                    'QR: komad, količ. pakovanja, operater, vrijeme, nalog',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 6.2,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    logistics,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Klasifikacija sastavnice: $clsTitle ($classification)',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8.5),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Nalog: ${order.productionOrderCode}',
                    style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                  ),
                  pw.Text(
                    'Komad: ${order.productName}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8.5),
                  ),
                  pw.Text(
                    'Šifra: ${order.productCode}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Količina u pakovanju: $qtyText',
                    style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                  ),
                  pw.Text(
                    'Plan na nalogu: ${_formatQty(order.plannedQty)} ${order.unit}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 7,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Operater: ${operatorName.trim().isEmpty ? '—' : operatorName.trim()}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8),
                  ),
                  pw.Text(
                    'Ispis: ${_formatDateTime(now)}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Status naloga: ${_statusLabelBs(order.status)}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 7.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Etikete po klasifikaciji sastavnice',
                style: pw.TextStyle(font: fontBold, fontSize: 14),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Nalog ${order.productionOrderCode} · ${_formatDateTime(now)}',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 12),
              ...classifications.map(labelBlock),
              pw.Spacer(),
              pw.Text(
                'QR (v1): qty = količina u pakovanju (proizvod); pn, pcode, piece, op, ts, cls.',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 7.5,
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
}
