import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/date/date_range_utils.dart' show formatCalendarDay;
import '../models/order_model.dart';
import '../order_status_ui.dart';

class OrdersListPdfExport {
  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _refDate(OrderModel o) {
    final d = o.orderDate ?? o.createdAt;
    if (d == null) return '—';
    return formatCalendarDay(d);
  }

  static Future<Uint8List> buildPdf({
    required List<OrderModel> orders,
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

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          cell('Broj', header: true),
          cell('Partner', header: true),
          cell('Tip', header: true),
          cell('Status', header: true),
          cell('Datum', header: true),
          cell('Kreirano', header: true),
          cell('Kol.', header: true),
        ],
      ),
      ...orders.map((o) {
        final qty = o.totalQty == o.totalQty.roundToDouble()
            ? o.totalQty.toInt().toString()
            : o.totalQty.toStringAsFixed(2);
        final created = o.createdAt == null
            ? '—'
            : formatCalendarDay(o.createdAt);
        return pw.TableRow(
          children: [
            cell(o.orderNumber),
            cell(o.partnerName),
            cell(o.orderType == OrderType.customer ? 'Kupac' : 'Dobavljač'),
            cell(orderStatusLabel(o.status)),
            cell(_refDate(o)),
            cell(created),
            cell(qty),
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
                style: pw.TextStyle(font: fontR, fontSize: 8, color: PdfColors.blue800),
              ),
            )
          else
            pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(1.3),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(1.1),
              6: const pw.FlexColumnWidth(0.7),
            },
            children: rows,
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> preview({
    required List<OrderModel> orders,
    required String reportTitle,
    String? companyLine,
    String? filterDescription,
  }) async {
    await Printing.layoutPdf(
      name: 'narudzbe_pregled',
      onLayout: (_) => buildPdf(
        orders: orders,
        reportTitle: reportTitle,
        companyLine: companyLine,
        filterDescription: filterDescription,
      ),
    );
  }
}
