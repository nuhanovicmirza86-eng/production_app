import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/pdf/operonix_industrial_letterhead_pdf.dart';
import '../../../core/pdf/operonix_pdf_footer.dart';
import '../../../modules/commercial/orders/export/pdf_company_header.dart';
import '../../../modules/commercial/orders/services/company_print_identity_service.dart';
import 'evidence_pdf_qms_document_marking.dart';
import 'first_piece_approval_release_document.dart';

/// M1-I3-G / M1-I5-C6 — PDF „Odobrenje prvog komada“ (QMS oznaka, bez FAI podnaslova).
class FirstPieceApprovalPdf {
  FirstPieceApprovalPdf._();

  static PdfColor _bannerColor(String disposition) {
    switch (disposition) {
      case 'approved':
        return PdfColors.green800;
      case 'rejected':
        return PdfColors.red800;
      case 'approved_with_deviation':
        return PdfColors.orange800;
      default:
        return PdfColor.fromInt(0xFF0B1F3A);
    }
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }

  static String _formatQty(double? value) {
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  static String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'closed':
        return 'Zatvoreno';
      case 'open':
      case 'active':
        return 'Otvoreno';
      default:
        return status;
    }
  }

  static Future<pw.Font> _loadFont(String asset) async {
    final bytes = await rootBundle.load(asset);
    return pw.Font.ttf(bytes);
  }

  /// Soft-fail: učitaj sliku proizvoda ako postoji URL.
  static Future<Uint8List?> tryLoadProductImageBytes(
    FirstPieceApprovalReleaseDocument doc,
  ) async {
    final url = (doc.productImageUrl ?? '').trim();
    if (url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
          );
      if (res.statusCode >= 200 && res.statusCode < 300 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List> buildPdfBytes({
    required FirstPieceApprovalReleaseDocument document,
    required Map<String, dynamic> companyData,
    CompanyPrintIdentity? printIdentity,
    Uint8List? productImageBytes,
    DateTime? printedAt,
  }) async {
    final fontRegular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');
    final operonixLogoBytes =
        await OperonixIndustrialLetterheadPdf.loadLogoBytes();
    final now = printedAt ?? DateTime.now();
    final bannerColor = _bannerColor(document.disposition);

    pw.Widget kv(String label, String value) {
      final v = value.trim().isEmpty ? '—' : value.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 150,
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

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 11,
            color: PdfColor.fromInt(0xFF0B1F3A),
          ),
        ),
      );
    }

    final orderLine = (document.productionOrderCode ?? '').trim();
    final lot = (document.pieceSerialOrLot ?? '').trim();
    final note = (document.dispositionNote ?? '').trim();
    final measure = (document.measurementSummary ?? '').trim();

    final doc = pw.Document(
      title: document.documentTitle,
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => OperonixPdfFooter.multiPageFooter(ctx, fontRegular),
        build: (ctx) {
          return [
            if (printIdentity != null) ...[
              PdfCompanyHeader.buildLetterhead(
                fontR: fontRegular,
                fontB: fontBold,
                data: printIdentity.toLetterheadData(companyData),
                logoBytes: printIdentity.logoBytes,
                maxLogoHeight: 52,
              ),
              pw.SizedBox(height: 10),
            ] else
              OperonixIndustrialLetterheadPdf.strip(logoBytes: operonixLogoBytes),
            pw.Text(
              document.documentTitle,
              style: pw.TextStyle(font: fontBold, fontSize: 16),
            ),
            ...EvidencePdfQmsDocumentMarking.underTitle(
              fieldValues: {
                'qmsControlledFormDocumentCode':
                    document.qmsControlledFormDocumentCode,
                'qmsControlledFormRevision':
                    document.qmsControlledFormRevision,
                'qmsControlledFormStatus': document.qmsControlledFormStatus,
                'qmsControlledFormTitle': document.qmsControlledFormTitle,
              },
              fontRegular: fontRegular,
              fontBold: fontBold,
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: bannerColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Center(
                child: pw.Text(
                  document.releaseBanner,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 14,
                    color: PdfColors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            sectionTitle('Kontekst'),
            kv('Kompanija', document.companyName),
            kv('Pogon', document.plantDisplayName),
            kv('Proces', document.processDisplayName),
            if (orderLine.isNotEmpty) kv('Proizvodni nalog', orderLine),
            sectionTitle('Proizvod'),
            kv('Šifra proizvoda', document.productCode),
            kv('Naziv proizvoda', document.productName),
            kv('Mašina / radno mjesto', document.machineName),
            if (productImageBytes != null && productImageBytes.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  height: 90,
                  child: pw.Image(
                    pw.MemoryImage(productImageBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
            ],
            if (lot.isNotEmpty) kv('Serija / lot', lot),
            kv('Komada za kontrolu', _formatQty(document.qtySubmitted)),
            sectionTitle('Kontrola i dispozicija'),
            if (measure.isNotEmpty) kv('Sažetak mjerenja', measure),
            kv('Dispozicija', document.dispositionLabel),
            if (note.isNotEmpty) kv('Napomena dispozicije', note),
            kv('Kontrolor kvaliteta', document.inspectorName),
            kv('Početak kontrole', _formatDateTime(document.inspectionStartedAt)),
            kv('Kraj kontrole', _formatDateTime(document.inspectionFinishedAt)),
            kv(
              'Vrijeme završavanja evidencije',
              _formatDateTime(document.endedAt),
            ),
            sectionTitle('Audit'),
            kv('Status evidencije', _statusLabel(document.status)),
            kv(
              'Sesiju otvorio',
              (document.createdByDisplayName ?? '').trim().isEmpty
                  ? '—'
                  : document.createdByDisplayName!,
            ),
            if ((document.createdByEmail ?? '').trim().isNotEmpty)
              kv('E-mail (otvaranje)', document.createdByEmail!),
            kv('Kreirano', _formatDateTime(document.createdAt)),
            kv('Ispisano', _formatDateTime(now)),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<void> preview({
    required FirstPieceApprovalReleaseDocument document,
    required Map<String, dynamic> companyData,
    CompanyPrintIdentity? printIdentity,
    Uint8List? productImageBytes,
  }) async {
    await Printing.layoutPdf(
      name: _safeFileName(document),
      onLayout: (_) => buildPdfBytes(
        document: document,
        companyData: companyData,
        printIdentity: printIdentity,
        productImageBytes: productImageBytes,
      ),
    );
  }

  static String _safeFileName(FirstPieceApprovalReleaseDocument document) {
    final code = document.productCode.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final order = (document.productionOrderCode ?? '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final base = order.isNotEmpty
        ? 'odobrenje_prvog_komada_${order}_$code'
        : 'odobrenje_prvog_komada_$code';
    return base;
  }
}
