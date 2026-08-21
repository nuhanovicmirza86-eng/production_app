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

/// M1-I4-C5 / M1-I5-C6 — evidencijski zapisnik (QMS oznaka, bez opisnog podnaslova).
class InProcessQualityCheckRecordPdf {
  InProcessQualityCheckRecordPdf._();

  static const documentTitle =
      'Evidencijski zapisnik — Procesna kontrola kvaliteta';

  static const unlinkedControlledFormMessage =
      EvidencePdfQmsDocumentMarking.unlinkedMessage;

  /// Banner tekst po ishodu (M1-I4-C6).
  static String outcomeBanner(String? rawOutcome) {
    switch ((rawOutcome ?? '').trim()) {
      case 'pass':
        return 'PROLAZI / PROCESNA KONTROLA ZADOVOLJAVA';
      case 'conditional_pass':
        return 'USLOVNO PROLAZI / POTREBNA PROVJERA ILI KOREKCIJA';
      case 'fail':
        return 'NE PROLAZI / PROCESNA KONTROLA NIJE ZADOVOLJILA';
      default:
        return 'ISHOD KONTROLE NIJE DEFINISAN';
    }
  }

  static PdfColor outcomeBannerColor(String? rawOutcome) {
    switch ((rawOutcome ?? '').trim()) {
      case 'pass':
        return PdfColors.green800;
      case 'conditional_pass':
        return PdfColors.orange800;
      case 'fail':
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

  /// M1-I4-D-C — blok kontrole dokumenta (QMS obrazac) ili poruka ako nije povezan/odobren.
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

  static String _outcomeLabel(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'pass':
        return 'Prolazi';
      case 'fail':
        return 'Ne prolazi';
      case 'conditional_pass':
        return 'Uslovno prolazi';
      default:
        return _dash(raw);
    }
  }

  static String _workContextLabel(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'machine':
        return 'Mašina';
      case 'workbench':
        return 'Radni sto';
      default:
        return _dash(raw);
    }
  }

  static DateTime? _parseDt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is Map) {
      final seconds = raw['seconds'] ?? raw['_seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000).round(),
          isUtc: true,
        ).toLocal();
      }
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim())?.toLocal();
    }
    return null;
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
    final rawOutcome = fv['inspectionOutcome']?.toString();
    final bannerText = outcomeBanner(rawOutcome);
    final bannerColor = outcomeBannerColor(rawOutcome);

    final unitRaw = (s.unit ?? fv['unit']?.toString() ?? '').toString().trim();
    final unitOrNull = unitRaw.isEmpty || unitRaw == '—' ? null : unitRaw;

    final inspector = _dash(
      s.operatorSummary ?? fv['inspectorNameSnapshot']?.toString(),
    );
    final productionOperator = _dash(
      s.packagingOperatorName ??
          fv['productionOperatorNameSnapshot']?.toString(),
    );
    final orderCode = _dash(
      s.productionOrderCode ?? fv['productionOrderCode']?.toString(),
    );
    final productName = _dash(
      s.productName ??
          fv['productNameSnapshot']?.toString() ??
          _firstLineProductField(session.inspectionLines, 'productNameSnapshot'),
    );
    final productCode = _dash(
      s.productCode ??
          fv['productCode']?.toString() ??
          _firstLineProductField(session.inspectionLines, 'productCode'),
    );
    final workContext = _workContextLabel(fv['workContextType']?.toString());
    final machineName = _dash(
      fv['machineNameSnapshot']?.toString() ??
          (workContext == 'Mašina' ? s.workAreaNameSnapshot : null),
    );
    final workbenchName = _dash(fv['workbenchNameSnapshot']?.toString());
    final workLocation = _dash(fv['workLocationNameSnapshot']?.toString());
    final outcome = _outcomeLabel(rawOutcome);
    final operatorComment = _dash(fv['operatorComment']?.toString());
    final inspectionStarted = _formatDateTime(
      _parseDt(fv['inspectionStartedAt']) ?? session.startedAt,
    );
    final inspectionFinished = _formatDateTime(
      _parseDt(fv['inspectionFinishedAt']) ?? session.endedAt,
    );

    final station = (session.stationDisplayName ?? '').trim().isNotEmpty
        ? session.stationDisplayName!.trim()
        : (session.stationSlot != null
            ? 'Stanica ${session.stationSlot}'
            : '—');

    final companyName = _dash(
      (companyData['name'] ?? companyData['companyName'] ?? '').toString(),
    );

    final workplaceLine = workContext == 'Mašina'
        ? (machineName != '—'
            ? 'Mašina: $machineName'
            : (workLocation != '—' ? workLocation : 'Mašina'))
        : workContext == 'Radni sto'
            ? (workbenchName != '—'
                ? 'Radni sto: $workbenchName'
                : (workLocation != '—' ? workLocation : 'Radni sto'))
            : workLocation;

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

    final lines = session.inspectionLines;
    final lineWidgets = <pw.Widget>[];
    if (lines.isEmpty) {
      lineWidgets.add(
        pw.Text(
          'Nema redova kontrolnih tačaka.',
          style: pw.TextStyle(font: fontRegular, fontSize: 8),
        ),
      );
    } else {
      for (var i = 0; i < lines.length; i++) {
        final row = lines[i];
        final checkpoint = _dash(row['checkpointName']?.toString());
        final rowUnit = (row['unit'] ?? unitOrNull)?.toString().trim();
        final inspected = _formatQtyWithUnit(
          row['qtyInspected'] is num
              ? row['qtyInspected'] as num
              : num.tryParse('${row['qtyInspected']}'),
          rowUnit,
        );
        final pass = _formatQty(
          row['qtyPass'] is num
              ? row['qtyPass'] as num
              : num.tryParse('${row['qtyPass']}'),
        );
        final fail = _formatQty(
          row['qtyFail'] is num
              ? row['qtyFail'] as num
              : num.tryParse('${row['qtyFail']}'),
        );
        final reasonCode = (row['defectReasonCode'] ?? '').toString().trim();
        final reason = reasonCode.isEmpty
            ? '—'
            : OperatorEvidenceUxStandard.defectReasonLabel(reasonCode);
        final note = _dash(row['measurementNote']?.toString());
        lineWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${i + 1}. $checkpoint — $inspected · prolazi $pass · '
                  'ne prolazi $fail',
                  style: pw.TextStyle(font: fontBold, fontSize: 8),
                ),
                if (reason != '—' || note != '—')
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, top: 1),
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
                kv('Stanica', station),
                kv('Početak evidencije', _formatDateTime(session.startedAt)),
                kv('Završetak evidencije', _formatDateTime(session.endedAt)),
              ],
            ),
            sectionTitle('Proizvodni kontekst'),
            twoCol(
              [
                kv('Proizvodni nalog', orderCode),
                kv('Proizvod', productName),
                if (productCode != '—') kv('Šifra proizvoda', productCode),
              ],
              [
                kv('Mjesto rada', workContext),
                kv('Lokacija / oprema', workplaceLine),
              ],
            ),
            sectionTitle('Kontrola'),
            twoCol(
              [
                kv('Kontrolor kvaliteta', inspector),
                kv('Proizvodni operater', productionOperator),
                kv('Ishod kontrole', outcome),
              ],
              [
                kv('Početak kontrole', inspectionStarted),
                kv('Kraj kontrole', inspectionFinished),
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
                  'Ukupno prolazi',
                  _formatQtyWithUnit(s.okTotalQty, unitOrNull),
                ),
              ],
              [
                kv(
                  'Ukupno ne prolazi',
                  _formatQtyWithUnit(s.scrapTotalQty, unitOrNull),
                ),
                if (unitOrNull != null) kv('Jedinica', unitOrNull),
              ],
            ),
            sectionTitle('Kontrolne tačke'),
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
            session.fieldValues['productCodeSnapshot'] ??
            session.summaryFields.productName ??
            'zapisnik')
        .toString()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final shortId = session.sessionId.length > 8
        ? session.sessionId.substring(0, 8)
        : session.sessionId;
    if (order.trim().isNotEmpty) {
      return 'procesna_kontrola_${order.trim()}_$product';
    }
    return 'procesna_kontrola_${product}_$shortId';
  }
}
