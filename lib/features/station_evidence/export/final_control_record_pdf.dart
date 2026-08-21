import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/pdf/operonix_industrial_letterhead_pdf.dart';
import '../../../core/pdf/operonix_pdf_footer.dart';
import '../../../modules/commercial/orders/export/pdf_company_header.dart';
import '../../../modules/commercial/orders/services/company_print_identity_service.dart';
import '../../catalog_evidence_runtime/utils/operator_evidence_ux_standard.dart';
import '../models/profile_driven_evidence_session.dart';
import 'evidence_pdf_qms_document_marking.dart';

/// M1-I5-B / M1-I5-C6 — Finalna kontrola (QMS oznaka, bez opisnog podnaslova).
class FinalControlRecordPdf {
  FinalControlRecordPdf._();

  static const documentTitle = 'Evidencijski zapisnik — Finalna kontrola';

  static const unlinkedControlledFormMessage =
      EvidencePdfQmsDocumentMarking.unlinkedMessage;

  /// Banner tekst po finalnoj dispoziciji (M1-I5-B).
  static String dispositionBanner(String? rawDisposition) {
    switch ((rawDisposition ?? '').trim()) {
      case 'approved':
        return 'ODOBRENO / FINALNA KONTROLA ZADOVOLJAVA';
      case 'recheck_required':
        return 'POTREBNA PONOVNA KONTROLA';
      case 'rework_required':
        return 'POTREBNA DORADA';
      case 'blocked':
        return 'BLOKIRANO / NIJE ODOBRENO ZA DALJE';
      default:
        return 'FINALNA DISPOZICIJA NIJE DEFINISANA';
    }
  }

  static PdfColor dispositionBannerColor(String? rawDisposition) {
    switch ((rawDisposition ?? '').trim()) {
      case 'approved':
        return PdfColors.green800;
      case 'recheck_required':
        return PdfColors.orange800;
      case 'rework_required':
        return PdfColors.deepOrange800;
      case 'blocked':
        return PdfColors.red800;
      default:
        return PdfColor.fromInt(0xFF0B1F3A);
    }
  }

  static String? _firstLineProductField(
    List<Map<String, dynamic>> lines,
    String key,
  ) {
    for (final row in lines) {
      final v = (row[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  static String _dash(String? value) {
    final t = (value ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  static String _formatDateTime(DateTime? dt) => formatEvidenceDateTime(dt);

  static String _formatQty(num? value) {
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  static String _formatQtyWithUnit(num? value, String? unit) {
    final qty = _formatQty(value);
    if (qty == '—') return '—';
    final u = (unit ?? '').trim();
    return u.isEmpty ? qty : '$qty $u';
  }

  static String _controlledFormStatusLabel(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'approved':
        return 'Aktivno';
      case 'draft':
        return 'Nacrt';
      case 'obsolete':
        return 'Van upotrebe';
      default:
        return _dash(raw);
    }
  }

  static List<pw.Widget> _documentControlBlock({
    required Map<String, dynamic> fv,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Widget Function(String) sectionTitle,
    required pw.Widget Function(List<pw.Widget>, List<pw.Widget>) twoCol,
    required pw.Widget Function(String, String) kv,
  }) {
    final status = (fv['qmsControlledFormStatus'] ?? '').toString().trim();
    final code = (fv['qmsControlledFormDocumentCode'] ?? '').toString().trim();
    final title = (fv['qmsControlledFormTitle'] ?? '').toString().trim();
    final linked = status.toLowerCase() == 'approved' &&
        (code.isNotEmpty || title.isNotEmpty);

    if (!linked) {
      // Poruka već ispod naslova (EvidencePdfQmsDocumentMarking.underTitle).
      return const [];
    }

    final rev = fv['qmsControlledFormRevision'];
    final revLabel = rev == null ? '—' : rev.toString();
    return [
      sectionTitle('Kontrola dokumenta'),
      twoCol(
        [
          kv('Oznaka obrasca', _dash(code)),
          kv('Revizija', revLabel),
          kv('Status', _controlledFormStatusLabel(status)),
        ],
        [
          kv('Tip dokumenta', 'Obrazac / zapis kvaliteta'),
          kv(
            'Vlasnik',
            _dash(fv['qmsControlledFormOwnerDepartment']?.toString()),
          ),
          kv(
            'Retention',
            _dash(fv['qmsControlledFormRetentionCategory']?.toString()),
          ),
        ],
      ),
      if (title.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
        ),
    ];
  }

  static String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'closed':
        return 'Završeno';
      case 'open':
      case 'active':
        return 'Otvoreno';
      default:
        return _dash(status);
    }
  }

  static String _dispositionLabel(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'approved':
        return 'Odobreno';
      case 'recheck_required':
        return 'Potrebna ponovna kontrola';
      case 'rework_required':
        return 'Potrebna dorada';
      case 'blocked':
        return 'Blokirano / nije odobreno za dalje';
      default:
        return _dash(raw);
    }
  }

  static Future<pw.Font> _loadFont(String asset) async {
    final bytes = await rootBundle.load(asset);
    return pw.Font.ttf(bytes);
  }

  static Future<Uint8List> buildPdfBytes({
    required ProfileDrivenEvidenceSessionDetail session,
    required Map<String, dynamic> companyData,
    required String plantDisplayName,
    CompanyPrintIdentity? printIdentity,
    DateTime? printedAt,
  }) async {
    final fontRegular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');
    final operonixLogoBytes =
        await OperonixIndustrialLetterheadPdf.loadLogoBytes();
    final now = printedAt ?? DateTime.now();
    final fv = session.fieldValues;
    final s = session.summaryFields;
    final rawDisposition = fv['finalDisposition']?.toString();
    final bannerText = dispositionBanner(rawDisposition);
    final bannerColor = dispositionBannerColor(rawDisposition);

    final unitRaw = (s.unit ?? fv['unit']?.toString() ?? '').toString().trim();
    final unitOrNull = unitRaw.isEmpty || unitRaw == '—' ? null : unitRaw;

    final controller = _dash(
      s.operatorSummary ?? fv['controllerNameSnapshot']?.toString(),
    );
    final orderCode = _dash(
      s.productionOrderCode ?? fv['productionOrderCode']?.toString(),
    );
    final productName = _dash(
      s.productName ??
          fv['productNameSnapshot']?.toString() ??
          _firstLineProductField(session.controlledItems, 'productNameSnapshot'),
    );
    final productCode = _dash(
      s.productCode ??
          fv['productCode']?.toString() ??
          _firstLineProductField(session.controlledItems, 'productCode'),
    );
    final disposition = _dispositionLabel(rawDisposition);
    final operatorComment = _dash(fv['operatorComment']?.toString());

    final station = (session.stationDisplayName ?? '').trim().isNotEmpty
        ? session.stationDisplayName!.trim()
        : (session.stationSlot != null
            ? 'Stanica ${session.stationSlot}'
            : '—');

    final companyName = _dash(
      (companyData['name'] ?? companyData['companyName'] ?? '').toString(),
    );

    pw.Widget kv(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 128,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(font: fontRegular, fontSize: 8),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 9.5,
            color: PdfColor.fromInt(0xFF0B1F3A),
          ),
        ),
      );
    }

    pw.Widget twoCol(List<pw.Widget> left, List<pw.Widget> right) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(children: left)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Column(children: right)),
        ],
      );
    }

    final lines = session.controlledItems;
    final lineWidgets = <pw.Widget>[];
    if (lines.isEmpty) {
      lineWidgets.add(
        pw.Text(
          'Nema kontrolisanih komada.',
          style: pw.TextStyle(font: fontRegular, fontSize: 8),
        ),
      );
    } else {
      for (var i = 0; i < lines.length; i++) {
        final row = lines[i];
        final rowProduct = _dash(
          row['productNameSnapshot']?.toString() ?? row['productCode']?.toString(),
        );
        final rowCode = _dash(row['productCode']?.toString());
        final rowUnit = (row['unit'] ?? unitOrNull)?.toString().trim();
        final inspected = _formatQtyWithUnit(
          row['inspectedQty'] is num
              ? row['inspectedQty'] as num
              : num.tryParse('${row['inspectedQty']}'),
          rowUnit,
        );
        final good = _formatQty(
          row['goodQty'] is num
              ? row['goodQty'] as num
              : num.tryParse('${row['goodQty']}'),
        );
        final scrap = _formatQty(
          row['scrapQty'] is num
              ? row['scrapQty'] as num
              : num.tryParse('${row['scrapQty']}'),
        );
        final rework = _formatQty(
          row['reworkQty'] is num
              ? row['reworkQty'] as num
              : num.tryParse('${row['reworkQty']}'),
        );
        final reason = _dash(row['defectReason']?.toString());
        final note = _dash(row['comment']?.toString());
        lineWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${i + 1}. $rowProduct'
                    '${rowCode != '—' && rowProduct != rowCode ? ' ($rowCode)' : ''}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Kontrolisano: $inspected · OK: $good · Škart: $scrap · Dorada: $rework',
                    style: pw.TextStyle(font: fontRegular, fontSize: 7.5),
                  ),
                  if (reason != '—' || note != '—')
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1),
                      child: pw.Text(
                        [
                          if (reason != '—') 'Razlog: $reason',
                          if (note != '—') 'Napomena: $note',
                        ].join(' · '),
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 7.5,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final operatorSession = _dash(
      session.operatorDisplayName ?? session.operatorEmail,
    );
    final openedBy = _dash(
      session.createdByDisplayName ?? session.createdByEmail,
    );
    final opEmail = (session.operatorEmail ?? '').trim();
    final openedEmail = (session.createdByEmail ?? '').trim();

    final doc = pw.Document(
      title: documentTitle,
      author: 'Operonix Production',
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        footer: (ctx) => OperonixPdfFooter.multiPageFooter(ctx, fontRegular),
        build: (ctx) {
          return [
            if (printIdentity != null) ...[
              PdfCompanyHeader.buildLetterhead(
                fontR: fontRegular,
                fontB: fontBold,
                data: printIdentity.toLetterheadData(companyData),
                logoBytes: printIdentity.logoBytes,
                maxLogoHeight: 40,
              ),
              pw.SizedBox(height: 6),
            ] else
              OperonixIndustrialLetterheadPdf.strip(
                logoBytes: operonixLogoBytes,
              ),
            pw.Text(
              documentTitle,
              style: pw.TextStyle(font: fontBold, fontSize: 13),
            ),
            ...EvidencePdfQmsDocumentMarking.underTitle(
              fieldValues: fv,
              fontRegular: fontRegular,
              fontBold: fontBold,
              fontSize: 8,
            ),
            pw.SizedBox(height: 6),
            ..._documentControlBlock(
              fv: fv,
              fontRegular: fontRegular,
              fontBold: fontBold,
              sectionTitle: sectionTitle,
              twoCol: twoCol,
              kv: kv,
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 10,
              ),
              decoration: pw.BoxDecoration(
                color: bannerColor,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Center(
                child: pw.Text(
                  bannerText,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: PdfColors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            sectionTitle('Osnovni podaci'),
            twoCol(
              [
                kv('Kompanija', companyName),
                kv('Pogon', _dash(plantDisplayName)),
                kv('Status', _statusLabel(session.status)),
                if (session.catalogVersion != null)
                  kv('Verzija kataloga', '${session.catalogVersion}'),
              ],
              [
                kv('Profil', _dash(session.profileDisplayName)),
                kv('Evidencija', station),
                kv('Početak evidencije', _formatDateTime(session.startedAt)),
                kv('Završetak evidencije', _formatDateTime(session.endedAt)),
              ],
            ),
            sectionTitle('Proizvodni kontekst'),
            twoCol(
              [
                kv('Proizvodni nalog', orderCode),
                kv('Proizvod', productName),
              ],
              [
                if (productCode != '—') kv('Šifra proizvoda', productCode),
              ],
            ),
            sectionTitle('Kontrola'),
            twoCol(
              [
                kv('Kontrolor', controller),
                kv('Finalna dispozicija', disposition),
              ],
              [
                kv('Komentar', operatorComment),
              ],
            ),
            sectionTitle('Kontrolisane količine'),
            twoCol(
              [
                kv(
                  'Ukupno kontrolisano',
                  _formatQtyWithUnit(s.quantity, unitOrNull),
                ),
                kv(
                  'Ukupno OK',
                  _formatQtyWithUnit(s.okTotalQty, unitOrNull),
                ),
              ],
              [
                kv(
                  'Ukupno škart',
                  _formatQtyWithUnit(s.scrapTotalQty, unitOrNull),
                ),
                kv(
                  'Ukupno dorada',
                  _formatQtyWithUnit(s.reworkAgainTotalQty, unitOrNull),
                ),
              ],
            ),
            sectionTitle('Kontrolisani komadi'),
            ...lineWidgets,
            sectionTitle('Operator audit'),
            twoCol(
              [
                kv('Operater (sesija)', operatorSession),
                if (opEmail.isNotEmpty) kv('E-mail operatera', opEmail),
                kv('Kreirano', _formatDateTime(session.createdAt)),
              ],
              [
                kv('Sesiju otvorio', openedBy),
                if (openedEmail.isNotEmpty && openedEmail != opEmail)
                  kv('E-mail (otvaranje)', openedEmail),
                kv('Ispisano', _formatDateTime(now)),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<void> preview({
    required ProfileDrivenEvidenceSessionDetail session,
    required Map<String, dynamic> companyData,
    required String plantDisplayName,
    CompanyPrintIdentity? printIdentity,
  }) async {
    await Printing.layoutPdf(
      name: safeFileName(session),
      onLayout: (_) => buildPdfBytes(
        session: session,
        companyData: companyData,
        plantDisplayName: plantDisplayName,
        printIdentity: printIdentity,
      ),
    );
  }

  static String safeFileName(ProfileDrivenEvidenceSessionDetail session) {
    final order = (session.summaryFields.productionOrderCode ??
            session.fieldValues['productionOrderCode'] ??
            '')
        .toString()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final product = (session.summaryFields.productCode ??
            session.fieldValues['productCode'] ??
            session.summaryFields.productName ??
            'zapisnik')
        .toString()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final shortId = session.sessionId.length > 8
        ? session.sessionId.substring(0, 8)
        : session.sessionId;
    if (order.trim().isNotEmpty) {
      return 'finalna_kontrola_${order.trim()}_$product';
    }
    return 'finalna_kontrola_${product}_$shortId';
  }
}
