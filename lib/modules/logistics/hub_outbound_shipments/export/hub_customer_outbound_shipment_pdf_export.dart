import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/pdf/operonix_pdf_footer.dart';
import '../../../commercial/orders/export/pdf_company_header.dart';
import '../../../commercial/orders/models/document_pdf_settings.dart';
import '../../../commercial/orders/services/company_print_identity_service.dart'
    show CompanyPrintIdentity;
import '../models/hub_customer_outbound_shipment_pdf_data.dart';

/// PDF otpremnice (magacin hub → kupac), uključujući fiskalna polja usklađena s `orders`.
class HubCustomerOutboundShipmentPdfExport {
  HubCustomerOutboundShipmentPdfExport._();

  static Future<pw.Font> _font(String asset) async {
    final b = await rootBundle.load(asset);
    return pw.Font.ttf(b);
  }

  static String _dec2(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceAll('.', ',');
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}.${d.month}.${d.year}';
  }

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

  static Future<Uint8List> buildPdfBytes({
    required HubCustomerOutboundShipmentPdfData data,
    required DocumentPdfSettings settings,
    required Map<String, dynamic> companyData,
    Uint8List? logoBytes,
  }) async {
    final fontR = await _font('assets/fonts/NotoSans-Regular.ttf');
    final fontB = await _font('assets/fonts/NotoSans-Bold.ttf');
    final companyName = _companyName(settings, companyData);
    final fiscalText = data.fiscalBlockText;

    pw.Widget kv(String k, String v) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(
                k,
                style: pw.TextStyle(
                  font: fontB,
                  fontSize: 8,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                v.trim().isEmpty ? '—' : v.trim(),
                style: pw.TextStyle(font: fontR, fontSize: 9),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget cell(String t, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          t,
          textAlign: align,
          style: pw.TextStyle(
            font: bold ? fontB : fontR,
            fontSize: 7.5,
          ),
        ),
      );
    }

    final tableHeader = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey400),
      children: [
        cell('Šifra', bold: true),
        cell('Naziv', bold: true),
        cell('MJ', bold: true),
        cell('Količina', bold: true, align: pw.TextAlign.right),
        cell('Lot / napomena', bold: true),
      ],
    );

    final itemRows = <pw.TableRow>[
      tableHeader,
      for (final it in data.lines)
        pw.TableRow(
          children: [
            cell(it.code),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                it.name,
                style: pw.TextStyle(font: fontR, fontSize: 7.5),
              ),
            ),
            cell(it.unit.isNotEmpty ? it.unit : '—'),
            cell(_dec2(it.quantity), align: pw.TextAlign.right),
            cell((it.lotLabel ?? '').trim().isEmpty ? '—' : it.lotLabel!.trim()),
          ],
        ),
    ];

    final doc = pw.Document(
      title: 'Otpremnica ${data.shipmentCode}',
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
            maxLogoHeight: 56,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'OTPREMNICA (hub → kupac)',
            style: pw.TextStyle(
              font: fontB,
              fontSize: 14,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            data.shipmentCode,
            style: pw.TextStyle(font: fontB, fontSize: 18, color: PdfColors.black),
          ),
          pw.Container(
            height: 3,
            margin: const pw.EdgeInsets.only(top: 6, bottom: 12),
            color: PdfColors.black,
          ),
          kv('Kupac', data.partnerName),
          if ((data.partnerCode ?? '').trim().isNotEmpty)
            kv('Šifra partnera', data.partnerCode!),
          if ((data.orderNumber ?? '').trim().isNotEmpty)
            kv('Broj narudžbe', data.orderNumber!),
          if ((data.orderId ?? '').trim().isNotEmpty)
            kv('ID narudžbe', data.orderId!),
          if ((data.hubWarehouseLabel ?? '').trim().isNotEmpty)
            kv('Magacin (hub)', data.hubWarehouseLabel!),
          kv(
            'Adresa isporuke',
            (data.deliveryAddress ?? '').trim().isEmpty
                ? data.partnerName
                : data.deliveryAddress!,
          ),
          kv(
            'Uvjeti dostave',
            (data.shippingTerms ?? '').trim().isEmpty
                ? '—'
                : data.shippingTerms!,
          ),
          kv(
            'Valuta (referenca)',
            (data.currency ?? '').trim().isEmpty ? '—' : data.currency!.trim(),
          ),
          if ((data.carrierName ?? '').trim().isNotEmpty)
            kv('Prijevoznik', data.carrierName!),
          if ((data.trackingNumber ?? '').trim().isNotEmpty)
            kv('Tracking', data.trackingNumber!),
          if (data.plannedShipDate != null)
            kv('Planirani datum otpreme', _fmtDate(data.plannedShipDate)),
          if (data.actualShipDate != null)
            kv('Stvarni datum otpreme', _fmtDate(data.actualShipDate)),
          if ((data.statusLabel ?? '').trim().isNotEmpty)
            kv('Status dokumenta', data.statusLabel!),
          if (fiscalText.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey500, width: 0.5),
                color: PdfColors.grey200,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Izvoz i fiskalni podaci (usklađeno s narudžbom)',
                    style: pw.TextStyle(
                      font: fontB,
                      fontSize: 9,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    fiscalText,
                    style: pw.TextStyle(font: fontR, fontSize: 8),
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Text(
            'Stavke',
            style: pw.TextStyle(font: fontB, fontSize: 10),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
            columnWidths: {
              0: const pw.FixedColumnWidth(52),
              1: const pw.FlexColumnWidth(2.6),
              2: const pw.FixedColumnWidth(28),
              3: const pw.FixedColumnWidth(52),
              4: const pw.FlexColumnWidth(1.2),
            },
            children: itemRows,
          ),
          if ((data.footerNote ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              data.footerNote!.trim(),
              style: pw.TextStyle(
                font: fontR,
                fontSize: 7,
                color: PdfColors.grey700,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> preview({
    required HubCustomerOutboundShipmentPdfData data,
    required DocumentPdfSettings settings,
    required Map<String, dynamic> companyData,
    Uint8List? logoBytes,
  }) async {
    await Printing.layoutPdf(
      name: 'otpremnica_${data.shipmentCode}',
      onLayout: (_) => buildPdfBytes(
        data: data,
        settings: settings,
        companyData: companyData,
        logoBytes: logoBytes,
      ),
    );
  }
}
