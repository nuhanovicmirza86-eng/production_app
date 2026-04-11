import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/date/date_range_utils.dart' show formatCalendarDay;
import '../models/production_order_model.dart';

/// PDF izvoz usklađen s ekranom: grupe po kupcu, sort po planiranom roku, količine i zalihe.
class ProductionOrdersListPdfExport {
  static final PdfColor _readyRowFill = PdfColor(200 / 255, 230 / 255, 201 / 255);
  static final PdfColor _groupHeaderFill = PdfColor(80 / 255, 80 / 255, 80 / 255);

  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

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

  static String _customerGroupKey(ProductionOrderModel o) {
    final a = (o.customerName ?? '').trim();
    if (a.isNotEmpty) return a;
    final b = (o.sourceCustomerName ?? '').trim();
    if (b.isNotEmpty) return b;
    return 'Bez naziva kupca';
  }

  static DateTime _pnDeadlineSort(ProductionOrderModel o) {
    return o.scheduledEndAt ??
        o.scheduledStartAt ??
        o.releasedAt ??
        o.createdAt;
  }

  static double _pnRemaining(ProductionOrderModel o) {
    if (o.status == 'completed' ||
        o.status == 'closed' ||
        o.status == 'cancelled') {
      return 0;
    }
    final v = o.plannedQty - o.producedGoodQty;
    return v > 0 ? v : 0;
  }

  static bool _pnRowReady(
    ProductionOrderModel o,
    Map<String, double>? stock,
  ) {
    if (stock == null || stock.isEmpty) return false;
    if (o.status == 'cancelled') return false;
    final rem = _pnRemaining(o);
    if (rem <= 0) return false;
    final pid = o.productId.trim();
    if (pid.isEmpty) return false;
    final s = stock[pid] ?? 0;
    return s + 1e-9 >= rem;
  }

  static List<ProductionOrderModel> _sortedOrders(List<ProductionOrderModel> orders) {
    final rows = List<ProductionOrderModel>.from(orders)
      ..sort((a, b) {
        final c = _pnDeadlineSort(a).compareTo(_pnDeadlineSort(b));
        if (c != 0) return c;
        return a.productionOrderCode.compareTo(b.productionOrderCode);
      });
    return rows;
  }

  static Map<String, List<ProductionOrderModel>> _groupByCustomer(
    List<ProductionOrderModel> orders,
  ) {
    final m = <String, List<ProductionOrderModel>>{};
    for (final o in orders) {
      final k = _customerGroupKey(o);
      m.putIfAbsent(k, () => []).add(o);
    }
    return m;
  }

  static Future<Uint8List> buildPdf({
    required List<ProductionOrderModel> orders,
    required String reportTitle,
    String? companyLine,
    String? filterDescription,
    Map<String, double>? stockByProductId,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');
    final now = DateTime.now();

    pw.Widget cell(
      String t, {
      bool header = false,
      pw.TextAlign align = pw.TextAlign.left,
      int maxLines = 3,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        alignment: align == pw.TextAlign.right
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          t,
          textAlign: align,
          maxLines: maxLines,
          style: pw.TextStyle(
            font: header ? fontB : fontR,
            fontSize: header ? 7 : 6,
          ),
        ),
      );
    }

    pw.TableRow headerRow() {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          cell('Broj PN', header: true),
          cell('Kreirano', header: true),
          cell('Narudžba', header: true),
          cell('Rok (plan)', header: true),
          cell('Status', header: true),
          cell('Šifra', header: true),
          cell('Naziv', header: true),
          cell('MJ', header: true),
          cell('Plan', header: true, align: pw.TextAlign.right),
          cell('Dobro', header: true, align: pw.TextAlign.right),
          cell('Ostalo', header: true, align: pw.TextAlign.right),
          cell('Pogon', header: true),
          cell('Stanje', header: true, align: pw.TextAlign.right),
        ],
      );
    }

    pw.TableRow dataRow(ProductionOrderModel o) {
      final ready = _pnRowReady(o, stockByProductId);
      final rowFill = ready ? _readyRowFill : null;
      final pid = o.productId.trim();
      final stockText = (stockByProductId == null || pid.isEmpty)
          ? '—'
          : _fmtQty(stockByProductId[pid] ?? 0);
      final rok = o.scheduledEndAt ?? o.scheduledStartAt;
      final rokStr = rok == null
          ? '—'
          : '${rok.day.toString().padLeft(2, '0')}.${rok.month.toString().padLeft(2, '0')}.${rok.year}';
      final src = (o.sourceOrderNumber ?? '').trim().isEmpty
          ? '—'
          : o.sourceOrderNumber!;
      final unit = o.unit.trim().isEmpty ? '—' : o.unit;

      return pw.TableRow(
        decoration: rowFill != null ? pw.BoxDecoration(color: rowFill) : null,
        children: [
          cell(o.productionOrderCode),
          cell(formatCalendarDay(o.createdAt)),
          cell(src),
          cell(rokStr),
          cell(_statusBs(o.status)),
          cell(o.productCode),
          cell(o.productName),
          cell(unit),
          cell(_fmtQty(o.plannedQty), align: pw.TextAlign.right),
          cell(_fmtQty(o.producedGoodQty), align: pw.TextAlign.right),
          cell(_fmtQty(_pnRemaining(o)), align: pw.TextAlign.right),
          cell(o.plantKey),
          cell(stockText, align: pw.TextAlign.right),
        ],
      );
    }

    final grouped = _groupByCustomer(orders);
    final keys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final blocks = <pw.Widget>[
      pw.Text(
        reportTitle,
        style: pw.TextStyle(font: fontB, fontSize: 14),
      ),
      if (companyLine != null && companyLine.trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
          child: pw.Text(
            companyLine.trim(),
            style: pw.TextStyle(font: fontR, fontSize: 9),
          ),
        ),
      pw.Text(
        'Generisano: ${formatCalendarDay(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        style: pw.TextStyle(
          font: fontR,
          fontSize: 8,
          color: PdfColors.grey700,
        ),
      ),
      if (filterDescription != null && filterDescription.trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
          child: pw.Text(
            filterDescription.trim(),
            style: pw.TextStyle(
              font: fontR,
              fontSize: 8,
              color: PdfColors.teal800,
            ),
          ),
        ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
        child: pw.Text(
          stockByProductId != null && stockByProductId.isNotEmpty
              ? 'Grupisano po kupcu; redovi sortirani po planiranom roku. '
                  'Zelena pozadina: zaliha pokriva ostatak plana (plan − dobro).'
              : 'Grupisano po kupcu; redovi sortirani po planiranom roku. '
                  'Stanje: — ako zalihe nisu proslijeđene iz aplikacije.',
          style: pw.TextStyle(font: fontR, fontSize: 7, color: PdfColors.grey800),
        ),
      ),
    ];

    for (final customer in keys) {
      final list = _sortedOrders(grouped[customer]!);

      blocks.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(color: _groupHeaderFill),
          child: pw.Text(
            customer,
            style: pw.TextStyle(
              font: fontB,
              fontSize: 9,
              color: PdfColors.white,
            ),
          ),
        ),
      );

      blocks.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.35),
          columnWidths: {
            0: const pw.FixedColumnWidth(56),
            1: const pw.FixedColumnWidth(46),
            2: const pw.FixedColumnWidth(48),
            3: const pw.FixedColumnWidth(46),
            4: const pw.FixedColumnWidth(48),
            5: const pw.FixedColumnWidth(48),
            6: const pw.FlexColumnWidth(2.0),
            7: const pw.FixedColumnWidth(24),
            8: const pw.FixedColumnWidth(36),
            9: const pw.FixedColumnWidth(36),
            10: const pw.FixedColumnWidth(36),
            11: const pw.FixedColumnWidth(40),
            12: const pw.FixedColumnWidth(38),
          },
          children: [
            headerRow(),
            for (final o in list) dataRow(o),
          ],
        ),
      );
      blocks.add(pw.SizedBox(height: 14));
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => blocks,
      ),
    );
    return doc.save();
  }

  static Future<void> preview({
    required List<ProductionOrderModel> orders,
    required String reportTitle,
    String? companyLine,
    String? filterDescription,
    Map<String, double>? stockByProductId,
  }) async {
    await Printing.layoutPdf(
      name: 'proizvodni_nalozi_pregled_detaljno',
      onLayout: (_) => buildPdf(
        orders: orders,
        reportTitle: reportTitle,
        companyLine: companyLine,
        filterDescription: filterDescription,
        stockByProductId: stockByProductId,
      ),
    );
  }
}
