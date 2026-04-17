import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/pdf/operonix_pdf_footer.dart';
import 'pdf_company_header.dart';
import '../../partners/models/partner_models.dart';
import '../models/document_pdf_settings.dart';
import '../models/order_model.dart';
import '../services/company_print_identity_service.dart';

/// PDF narudžbenice za dobavljača (A4, zaglavlje prema postavkama kompanije).
class SupplierOrderPdfExport {
  SupplierOrderPdfExport._();

  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  /// Logo za PDF: isti tok kao [CompanyPrintIdentityService] (web → Callable).
  static Future<Uint8List?> loadLogoBytes({
    required String companyId,
    required DocumentPdfSettings settings,
    required Map<String, dynamic> companyData,
  }) async {
    return CompanyPrintIdentityService.loadLogoBytesForPdf(
      companyId: companyId,
      settings: settings,
      companyData: companyData,
    );
  }

  static String _dec2(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceAll('.', ',');
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}.${d.month}.${d.year}';
  }

  static String _supplierBlock(SupplierModel? s, String fallbackName) {
    if (s == null) {
      return fallbackName.trim().isEmpty ? '—' : fallbackName.trim();
    }
    final name = s.legalName.trim().isNotEmpty ? s.legalName : s.name;
    final lines = <String>[name];
    final addr = (s.address ?? '').trim();
    if (addr.isNotEmpty) lines.add(addr);
    final cityLine = [
      (s.city ?? '').trim(),
      (s.country ?? '').trim(),
    ].where((e) => e.isNotEmpty).join(', ');
    if (cityLine.isNotEmpty) lines.add(cityLine);
    return lines.join('\n');
  }

  static String _carrierBlock(OrderModel order, SupplierModel? s) {
    final da = (order.deliveryAddress ?? '').trim();
    if (da.isNotEmpty) return da;
    return _supplierBlock(s, order.partnerName);
  }

  /// Službeni kurs KM po 1 EUR (CB BiH).
  static const double _kmPerEur = 1.95583;

  static String _companyName(
    DocumentPdfSettings settings,
    Map<String, dynamic> companyData,
  ) {
    final a = settings.companyLegalName.trim();
    if (a.isNotEmpty) return a;
    return (companyData['companyName'] ?? companyData['name'] ?? '')
        .toString()
        .trim();
  }

  /// Dobavljač iz BiH → prikaz u KM; inače EUR.
  static bool _isBiHSupplier(SupplierModel? s) {
    if (s == null) return false;
    bool c(String? t) {
      final x = (t ?? '').toLowerCase().trim();
      if (x.isEmpty) return false;
      if (x == 'ba' || x == 'bih' || x == 'b&h') return true;
      if (x == 'bosna i hercegovina' || x == 'bosnia and herzegovina') {
        return true;
      }
      if (x.contains('bosna') && x.contains('hercegovina')) return true;
      if (x.contains('bosnia') && x.contains('herzegovina')) return true;
      return false;
    }

    if (c(s.country)) return true;
    final hay = '${s.city ?? ''} ${s.address ?? ''} ${s.legalName}'.toLowerCase();
    if (hay.contains('bosna i hercegovina') ||
        hay.contains('bosnia and herzegovina')) {
      return true;
    }
    return false;
  }

  static String _orderCurrencyNorm(OrderModel o) {
    final c = (o.currency ?? '').trim().toUpperCase();
    if (c.isEmpty) return 'EUR';
    if (c == '€') return 'EUR';
    if (c == 'BAM') return 'KM';
    return c;
  }

  static bool _storageIsKm(OrderModel o) {
    final c = _orderCurrencyNorm(o);
    return c == 'KM' || c == 'BAM';
  }

  static bool _storageIsEur(OrderModel o) {
    final c = _orderCurrencyNorm(o);
    return c == 'EUR';
  }

  /// Iznos iz baze (prema narudžbi) u valutu za PDF.
  static double _toDisplayAmount(double storageAmount, OrderModel o, bool biH) {
    if (biH) {
      if (_storageIsKm(o)) return storageAmount;
      return storageAmount * _kmPerEur;
    }
    if (_storageIsEur(o)) return storageAmount;
    if (_storageIsKm(o)) return storageAmount / _kmPerEur;
    return storageAmount;
  }

  static String _displayCurrencySymbol(bool biH) => biH ? 'KM' : 'EUR';

  static Future<Uint8List> buildPdfBytes({
    required OrderModel order,
    required DocumentPdfSettings settings,
    required Map<String, dynamic> companyData,
    SupplierModel? supplier,
    Uint8List? logoBytes,
    required String responsiblePersonLabel,
  }) async {
    if (order.orderType != OrderType.supplier) {
      throw ArgumentError('Očekuje se narudžba dobavljača (supplier_order).');
    }

    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');

    final companyName = _companyName(settings, companyData);
    final biH = _isBiHSupplier(supplier);
    final cur = _displayCurrencySymbol(biH);

    final vatDefault = settings.defaultVatPercent.toDouble();

    double lineNet(OrderItemModel it) {
      final disc = it.discountPercent.clamp(0.0, 100.0);
      final p = it.unitPrice;
      final q = it.qty;
      return q * p * (1.0 - disc / 100.0);
    }

    double lineVatRate(OrderItemModel it) {
      if (it.vatPercent != null) return it.vatPercent!;
      return vatDefault;
    }

    double lineVatAmount(OrderItemModel it) {
      return lineNet(it) * (lineVatRate(it) / 100.0);
    }

    double lineGross(OrderItemModel it) => lineNet(it) + lineVatAmount(it);

    var sumNet = 0.0;
    var sumVat = 0.0;
    for (final it in order.items) {
      sumNet += lineNet(it);
      sumVat += lineVatAmount(it);
    }
    final sumGross = sumNet + sumVat;
    final sumNetD = _toDisplayAmount(sumNet, order, biH);
    final sumVatD = _toDisplayAmount(sumVat, order, biH);
    final sumGrossD = _toDisplayAmount(sumGross, order, biH);
    final supplierTaxId = (supplier?.taxId ?? '').trim();

    final supplierText = _supplierBlock(supplier, order.partnerName);
    final carrierText = _carrierBlock(order, supplier);

    pw.Widget partnerBox(String title, String body) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500, width: 0.7),
            color: PdfColors.white,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontB,
                  fontSize: 9,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                body,
                style: pw.TextStyle(font: fontR, fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }

    pw.Widget cell(
      String t, {
      bool bold = false,
      PdfColor? color,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          t,
          textAlign: align,
          style: pw.TextStyle(
            font: bold ? fontB : fontR,
            fontSize: 7.5,
            color: color ?? PdfColors.black,
          ),
        ),
      );
    }

    final tableHeader = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey400),
      children: [
        cell('Šifra', bold: true),
        cell('Naziv', bold: true),
        cell('Količina', bold: true, align: pw.TextAlign.right),
        cell('MJ', bold: true),
        cell('Cijena', bold: true, align: pw.TextAlign.right),
        cell('R. %', bold: true, align: pw.TextAlign.right),
        cell('PDV %', bold: true, align: pw.TextAlign.right),
        cell('Vrijednost', bold: true, align: pw.TextAlign.right),
      ],
    );

    final itemRows = <pw.TableRow>[
      tableHeader,
      for (final it in order.items) ...[
        pw.TableRow(
          children: [
            cell(it.productCode),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                it.productName,
                style: pw.TextStyle(font: fontR, fontSize: 7.5),
              ),
            ),
            cell(_dec2(it.qty), align: pw.TextAlign.right),
            cell(it.unit.isNotEmpty ? it.unit : '—'),
            cell(
              _dec2(_toDisplayAmount(it.unitPrice, order, biH)),
              align: pw.TextAlign.right,
            ),
            cell(
              _dec2(it.discountPercent.clamp(0, 100)),
              align: pw.TextAlign.right,
            ),
            cell(_dec2(lineVatRate(it)), align: pw.TextAlign.right),
            cell(
              '${_dec2(_toDisplayAmount(lineGross(it), order, biH))} $cur',
              align: pw.TextAlign.right,
            ),
          ],
        ),
      ],
    ];

    final doc = pw.Document(
      title: 'Narudžba ${order.orderNumber}',
      author: companyName.isEmpty ? 'Operonix' : companyName,
      theme: pw.ThemeData.withFont(base: fontR, bold: fontB),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => OperonixPdfFooter.multiPageFooter(ctx, fontR),
        build: (context) => [
          PdfCompanyHeader.buildLetterhead(
            fontR: fontR,
            fontB: fontB,
            data: CompanyPrintIdentity(
              settings: settings,
              logoBytes: logoBytes,
            ).toLetterheadData(companyData),
            logoBytes: logoBytes,
            maxLogoHeight: 64,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              partnerBox('Dobavljač', supplierText),
              pw.SizedBox(width: 12),
              partnerBox('Prijevoznik / isporuka', carrierText),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Narudžba ${order.orderNumber}',
            style: pw.TextStyle(font: fontB, fontSize: 16, color: PdfColors.black),
          ),
          pw.Container(
            height: 4,
            margin: const pw.EdgeInsets.only(top: 4, bottom: 10),
            color: PdfColors.black,
          ),
          pw.Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _kvPdf('Datum', _fmtDate(order.orderDate), fontR, fontB),
              _kvPdf(
                'Rok isporuke',
                _fmtDate(order.requestedDeliveryDate),
                fontR,
                fontB,
              ),
              _kvPdf(
                'Dostava',
                (order.shippingTerms ?? '').trim().isEmpty
                    ? '—'
                    : order.shippingTerms!.trim(),
                fontR,
                fontB,
              ),
              _kvPdf('Odgovorna osoba', responsiblePersonLabel, fontR, fontB),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
            columnWidths: {
              0: const pw.FixedColumnWidth(52),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FixedColumnWidth(44),
              3: const pw.FixedColumnWidth(28),
              4: const pw.FixedColumnWidth(48),
              5: const pw.FixedColumnWidth(36),
              6: const pw.FixedColumnWidth(40),
              7: const pw.FixedColumnWidth(56),
            },
            children: itemRows,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PDV broj dobavljača',
                      style: pw.TextStyle(
                        font: fontB,
                        fontSize: 8,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      supplierTaxId.isEmpty ? '—' : supplierTaxId,
                      style: pw.TextStyle(font: fontR, fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(
                width: 200,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _totalLine(
                      fontR,
                      fontB,
                      'Osnovica (bez PDV)',
                      '${_dec2(sumNetD)} $cur',
                    ),
                    _totalLine(
                      fontR,
                      fontB,
                      'PDV ukupno',
                      '${_dec2(sumVatD)} $cur',
                    ),
                    pw.Divider(thickness: 0.7, color: PdfColors.grey600),
                    _totalLine(
                      fontR,
                      fontB,
                      'Za platiti',
                      '${_dec2(sumGrossD)} $cur',
                      emphasize: true,
                    ),
                    if (biH && _storageIsEur(order))
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Text(
                          'Iznosi u KM preračunati po kursu 1 EUR = 1,95583 KM.',
                          style: pw.TextStyle(
                            font: fontR,
                            fontSize: 6,
                            color: PdfColors.grey700,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    if (!biH && _storageIsKm(order))
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Text(
                          'Iznosi u EUR preračunati po kursu 1 EUR = 1,95583 KM.',
                          style: pw.TextStyle(
                            font: fontR,
                            fontSize: 6,
                            color: PdfColors.grey700,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _kvPdf(
    String k,
    String v,
    pw.Font fontR,
    pw.Font fontB,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          k,
          style: pw.TextStyle(
            font: fontB,
            fontSize: 7.5,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(v, style: pw.TextStyle(font: fontR, fontSize: 9)),
      ],
    );
  }

  static pw.Widget _totalLine(
    pw.Font fontR,
    pw.Font fontB,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: emphasize ? fontB : fontR,
              fontSize: emphasize ? 10 : 9,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: emphasize ? fontB : fontR,
              fontSize: emphasize ? 10 : 9,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> preview({
    required OrderModel order,
    required DocumentPdfSettings settings,
    required Map<String, dynamic> companyData,
    SupplierModel? supplier,
    Uint8List? logoBytes,
    required String responsiblePersonLabel,
  }) async {
    await Printing.layoutPdf(
      name: 'narudzba_${order.orderNumber}',
      onLayout: (_) => buildPdfBytes(
        order: order,
        settings: settings,
        companyData: companyData,
        supplier: supplier,
        logoBytes: logoBytes,
        responsiblePersonLabel: responsiblePersonLabel,
      ),
    );
  }
}
