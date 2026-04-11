import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/date/date_range_utils.dart' show formatCalendarDay;
import '../models/order_model.dart';
import '../order_status_ui.dart';

/// PDF izvoz usklađen s ekranom: grupe po partneru, redovi po stavci, sort po roku isporuke.
class OrdersListPdfExport {
  static final PdfColor _readyRowFill = PdfColor(200 / 255, 230 / 255, 201 / 255);
  static final PdfColor _groupHeaderFill = PdfColor(80 / 255, 80 / 255, 80 / 255);

  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _formatDay(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  static DateTime _deadlineSortKey(OrderModel o, OrderItemModel? it) {
    final lineDue = it?.dueDate;
    if (lineDue != null) return lineDue;
    return o.requestedDeliveryDate ??
        o.orderDate ??
        o.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String? _partnerRef(OrderModel o) {
    switch (o.orderType) {
      case OrderType.customer:
        final r = o.customerReference?.trim();
        return (r == null || r.isEmpty) ? null : r;
      case OrderType.supplier:
        final r = o.supplierReference?.trim();
        return (r == null || r.isEmpty) ? null : r;
    }
  }

  static double _remainingQty(OrderModel o, OrderItemModel? it) {
    if (it == null) return 0;
    if (it.openQty > 0) return it.openQty;
    if (o.orderType == OrderType.customer) {
      final v = it.qty - it.deliveredQty;
      return v > 0 ? v : 0;
    }
    final v = it.qty - it.receivedQty;
    return v > 0 ? v : 0;
  }

  static double _fulfilledQty(OrderModel o, OrderItemModel? it) {
    if (it == null) return 0;
    return o.orderType == OrderType.customer ? it.deliveredQty : it.receivedQty;
  }

  static bool _rowReady(
    OrderModel o,
    OrderItemModel? it,
    Map<String, double>? stock,
  ) {
    if (stock == null || stock.isEmpty) return false;
    if (it == null) return false;
    if (o.status == OrderStatus.cancelled) return false;
    final rem = _remainingQty(o, it);
    if (rem <= 0) return false;
    final pid = it.productId.trim();
    if (pid.isEmpty) return false;
    final s = stock[pid] ?? 0;
    return s + 1e-9 >= rem;
  }

  static List<({OrderModel o, OrderItemModel? it})> _sortedLines(
    List<OrderModel> orders,
  ) {
    final lines = <({OrderModel o, OrderItemModel? it})>[];
    for (final o in orders) {
      if (o.items.isEmpty) {
        lines.add((o: o, it: null));
      } else {
        for (final it in o.items) {
          lines.add((o: o, it: it));
        }
      }
    }
    lines.sort((a, b) {
      final c =
          _deadlineSortKey(a.o, a.it).compareTo(_deadlineSortKey(b.o, b.it));
      if (c != 0) return c;
      final n = a.o.orderNumber.compareTo(b.o.orderNumber);
      if (n != 0) return n;
      return (a.it?.productCode ?? '').compareTo(b.it?.productCode ?? '');
    });
    return lines;
  }

  static Map<String, List<OrderModel>> _groupByPartner(List<OrderModel> orders) {
    final m = <String, List<OrderModel>>{};
    for (final o in orders) {
      final k = o.partnerName.trim().isEmpty
          ? 'Nepoznat partner'
          : o.partnerName.trim();
      m.putIfAbsent(k, () => []).add(o);
    }
    return m;
  }

  static Future<Uint8List> buildPdf({
    required List<OrderModel> orders,
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
          cell('Broj nar.', header: true),
          cell('Datum nar.', header: true),
          cell('Ref.', header: true),
          cell('Rok isp.', header: true),
          cell('Tip', header: true),
          cell('Status', header: true),
          cell('Šifra', header: true),
          cell('Naziv', header: true),
          cell('MJ', header: true),
          cell('Naruč.', header: true, align: pw.TextAlign.right),
          cell('Isp./Prim.', header: true, align: pw.TextAlign.right),
          cell('Ostalo', header: true, align: pw.TextAlign.right),
          cell('Stanje', header: true, align: pw.TextAlign.right),
        ],
      );
    }

    pw.TableRow dataRow(
      OrderModel o,
      OrderItemModel? it,
    ) {
      final ready = _rowReady(o, it, stockByProductId);
      final rowFill = ready ? _readyRowFill : null;
      final ref = _partnerRef(o);
      final rok = _formatDay(
        it?.dueDate ?? o.requestedDeliveryDate ?? o.confirmedDeliveryDate,
      );
      final pid = (it?.productId ?? '').trim();
      final stockText = (stockByProductId == null || pid.isEmpty)
          ? '—'
          : _fmtQty(stockByProductId[pid] ?? 0);

      final nar = it == null ? '—' : _fmtQty(it.qty);
      final isp = it == null ? '—' : _fmtQty(_fulfilledQty(o, it));
      final ost = it == null ? '—' : _fmtQty(_remainingQty(o, it));

      return pw.TableRow(
        decoration: rowFill != null ? pw.BoxDecoration(color: rowFill) : null,
        children: [
          cell(o.orderNumber),
          cell(_formatDay(o.orderDate ?? o.createdAt)),
          cell(ref ?? '—'),
          cell(rok),
          cell(o.orderType == OrderType.customer ? 'Kupac' : 'Dobavljač'),
          cell(orderStatusLabel(o.status)),
          cell(it?.productCode ?? '—'),
          cell(it?.productName ?? 'Nema učitanih stavki'),
          cell(() {
            final u = (it?.unit ?? '').trim();
            return u.isEmpty ? '—' : u;
          }()),
          cell(nar, align: pw.TextAlign.right),
          cell(isp, align: pw.TextAlign.right),
          cell(ost, align: pw.TextAlign.right),
          cell(stockText, align: pw.TextAlign.right),
        ],
      );
    }

    final grouped = _groupByPartner(orders);
    final partnerKeys = grouped.keys.toList()
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
              color: PdfColors.blue800,
            ),
          ),
        ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
        child: pw.Text(
          stockByProductId != null && stockByProductId.isNotEmpty
              ? 'Grupisano po partneru; redovi sortirani po roku isporuke. '
                  'Zelena pozadina: zaliha pokriva ostatak (ako su zalihe učitane u aplikaciji pri izvozu).'
              : 'Grupisano po partneru; redovi sortirani po roku isporuke. '
                  'Kolona Stanje: — ako zalihe nisu proslijeđene iz aplikacije.',
          style: pw.TextStyle(font: fontR, fontSize: 7, color: PdfColors.grey800),
        ),
      ),
    ];

    for (final partner in partnerKeys) {
      final partnerOrders = grouped[partner]!;
      final lines = _sortedLines(partnerOrders);

      blocks.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(color: _groupHeaderFill),
          child: pw.Text(
            partner,
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
            0: const pw.FixedColumnWidth(52),
            1: const pw.FixedColumnWidth(46),
            2: const pw.FixedColumnWidth(44),
            3: const pw.FixedColumnWidth(46),
            4: const pw.FixedColumnWidth(36),
            5: const pw.FixedColumnWidth(52),
            6: const pw.FixedColumnWidth(48),
            7: const pw.FlexColumnWidth(2.2),
            8: const pw.FixedColumnWidth(22),
            9: const pw.FixedColumnWidth(38),
            10: const pw.FixedColumnWidth(40),
            11: const pw.FixedColumnWidth(34),
            12: const pw.FixedColumnWidth(38),
          },
          children: [
            headerRow(),
            for (final line in lines) dataRow(line.o, line.it),
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
    required List<OrderModel> orders,
    required String reportTitle,
    String? companyLine,
    String? filterDescription,
    Map<String, double>? stockByProductId,
  }) async {
    await Printing.layoutPdf(
      name: 'narudzbe_pregled_detaljno',
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
