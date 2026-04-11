import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/date/date_range_utils.dart' show formatCalendarDay;
import '../models/production_order_model.dart';

class ProductionOrdersListPdfExport {
  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _statusBs(String status) {
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

  static Future<Uint8List> buildPdf({
    required List<ProductionOrderModel> orders,
    required String reportTitle,
    String? companyLine,
    String? filterDescription,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');
    final now = DateTime.now();

    pw.Widget cell(String t, {bool header = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            font: header ? fontB : fontR,
            fontSize: header ? 8 : 7,
          ),
        ),
      );
    }

    String fmtQty(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          cell('Kod', header: true),
          cell('Status', header: true),
          cell('Proizvod', header: true),
          cell('Šifra', header: true),
          cell('Plan', header: true),
          cell('Good', header: true),
          cell('Pogon', header: true),
          cell('Kreirano', header: true),
        ],
      ),
      ...orders.map((o) {
        return pw.TableRow(
          children: [
            cell(o.productionOrderCode),
            cell(_statusBs(o.status)),
            cell(o.productName),
            cell(o.productCode),
            cell('${fmtQty(o.plannedQty)} ${o.unit}'),
            cell('${fmtQty(o.producedGoodQty)} ${o.unit}'),
            cell(o.plantKey),
            cell(formatCalendarDay(o.createdAt)),
          ],
        );
      }),
    ];

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            reportTitle,
            style: pw.TextStyle(font: fontB, fontSize: 14),
          ),
          if (companyLine != null && companyLine.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
              child: pw.Text(companyLine.trim(), style: pw.TextStyle(font: fontR, fontSize: 9)),
            ),
          pw.Text(
            'Generisano: ${formatCalendarDay(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            style: pw.TextStyle(font: fontR, fontSize: 8, color: PdfColors.grey700),
          ),
          if (filterDescription != null && filterDescription.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
              child: pw.Text(
                filterDescription.trim(),
                style: pw.TextStyle(font: fontR, fontSize: 8, color: PdfColors.teal800),
              ),
            )
          else
            pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(2.0),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(0.9),
              5: const pw.FlexColumnWidth(0.9),
              6: const pw.FlexColumnWidth(0.7),
              7: const pw.FlexColumnWidth(1.0),
            },
            children: rows,
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> preview({
    required List<ProductionOrderModel> orders,
    required String reportTitle,
    String? companyLine,
    String? filterDescription,
  }) async {
    await Printing.layoutPdf(
      name: 'proizvodni_nalozi_pregled',
      onLayout: (_) => buildPdf(
        orders: orders,
        reportTitle: reportTitle,
        companyLine: companyLine,
        filterDescription: filterDescription,
      ),
    );
  }
}
