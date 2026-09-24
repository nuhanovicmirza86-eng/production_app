import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/pdf/operonix_industrial_letterhead_pdf.dart';
import '../../../core/pdf/operonix_pdf_footer.dart';
import '../../../modules/commercial/orders/export/pdf_company_header.dart';
import '../../../modules/commercial/orders/services/company_print_identity_service.dart';
import '../../catalog_evidence_runtime/utils/omp_material_lot_source_display.dart';
import '../../catalog_evidence_runtime/utils/operator_evidence_ux_standard.dart';
import '../../../modules/production/bom/bom_item_traceability.dart';
import '../models/profile_driven_evidence_session.dart';
import 'evidence_pdf_qms_document_marking.dart';

/// M1-I8-D — PDF zapisnik: Priprema materijala za operaciju (QMS oznaka).
class OperationMaterialPreparationRecordPdf {
  OperationMaterialPreparationRecordPdf._();

  static const documentTitle =
      'Evidencijski zapisnik — Priprema materijala za operaciju';

  static const unlinkedControlledFormMessage =
      EvidencePdfQmsDocumentMarking.unlinkedMessage;

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

  static String operationPhaseLabel(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'pripremna':
        return 'Pripremna';
      case 'priprema_proizvodnje':
        return 'Priprema proizvodnje';
      case 'pakovanje':
        return 'Pakovanje';
      case 'montaza':
        return 'Montaža';
      case 'obrada':
        return 'Obrada';
      case 'kontrola':
        return 'Kontrola';
      case 'zavrsna_kontrola':
        return 'Finalna kontrola';
      case 'etiketiranje':
        return 'Etiketiranje';
      case 'zavrsna_obrada':
        return 'Završna obrada';
      case 'ostalo':
        return 'Ostalo';
      default:
        return _dash(raw);
    }
  }

  static String preparationPurposeLabel(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'for_operation':
        return 'Za operaciju';
      case 'for_machine':
        return 'Za mašinu';
      case 'for_workbench':
        return 'Za radni sto';
      case 'for_rework':
        return 'Za doradu';
      case 'material_replacement':
        return 'Za zamjenu materijala';
      case 'mid_production_topup':
        return 'Za dopunu tokom proizvodnje';
      default:
        return _dash(raw);
    }
  }

  static String _controlledFormStatusLabel(String? raw) {
    return EvidencePdfQmsDocumentMarking.statusLabel(raw);
  }

  static String _workLocationDisplay(Map<String, dynamic> fv) {
    final loc = (fv['workLocationNameSnapshot'] ?? '').toString().trim();
    if (loc.isNotEmpty) return loc;
    final type = (fv['workContextType'] ?? '').toString().trim();
    if (type == 'machine') {
      final code = (fv['machineCodeSnapshot'] ?? '').toString().trim();
      final name = (fv['machineNameSnapshot'] ?? '').toString().trim();
      if (code.isNotEmpty && name.isNotEmpty) return 'Mašina: $code / $name';
      if (name.isNotEmpty) return 'Mašina: $name';
      if (code.isNotEmpty) return 'Mašina: $code';
      return 'Mašina';
    }
    if (type == 'workbench') {
      final code = (fv['workbenchCodeSnapshot'] ?? '').toString().trim();
      final name = (fv['workbenchNameSnapshot'] ?? '').toString().trim();
      if (code.isNotEmpty && name.isNotEmpty) {
        return 'Radni sto: $code / $name';
      }
      if (name.isNotEmpty) return 'Radni sto: $name';
      if (code.isNotEmpty) return 'Radni sto: $code';
      return 'Radni sto';
    }
    return '—';
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
    final linked = EvidencePdfQmsDocumentMarking.isLinkedApproved(
      status: status,
      code: code,
      title: title,
    );

    if (!linked) {
      return const [];
    }

    return EvidencePdfQmsDocumentMarking.documentControlBlock(
      fieldValues: fv,
      fontRegular: fontRegular,
      fontBold: fontBold,
      sectionTitle: sectionTitle,
      twoCol: twoCol,
      kv: kv,
    );
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

    final unitRaw = (fv['unit'] ?? s.unit ?? '').toString().trim();
    final unitOrNull = unitRaw.isEmpty || unitRaw == '—' ? null : unitRaw;

    final preparedQty = fv['preparedQuantity'] is num
        ? fv['preparedQuantity'] as num
        : num.tryParse('${fv['preparedQuantity']}');

    final preparedAtRaw = fv['preparedAt'];
    DateTime? preparedAt;
    if (preparedAtRaw is DateTime) {
      preparedAt = preparedAtRaw;
    } else if (preparedAtRaw != null) {
      preparedAt = DateTime.tryParse(preparedAtRaw.toString());
    }

    final orderCode = _dash(
      s.productionOrderCode ?? fv['productionOrderCode']?.toString(),
    );
    final productName = _dash(
      s.productName ?? fv['productNameSnapshot']?.toString(),
    );
    final productCode = _dash(
      s.productCode ?? fv['productCode']?.toString(),
    );
    final materialName = _dash(
      fv['materialNameSnapshot']?.toString() ??
          fv['materialCodeSnapshot']?.toString(),
    );
    final materialCode = _dash(fv['materialCodeSnapshot']?.toString());
    final materialLot = _dash(fv['materialLot']?.toString());
    final lotRequired = ompLotIsRequired(fv);
    final kindLabel = bomItemKindLabelBs(
      (fv[ompBomItemKindSnapshot] ?? '').toString(),
    );
    final modeLabel = bomTraceabilityModeLabelBs(
      (fv[ompTraceabilityModeSnapshot] ?? '').toString(),
    );
    // M1-I11-B — uvijek prikaži izvor kad postoji lot (fallback = ručni / nepotvrđen).
    final lotSourceLabel = ompMaterialLotSourceDisplayLabel(fv);
    final warehouseSnap = _dash(fv['warehouseNameSnapshot']?.toString());
    final lotStatusSnap = _dash(fv['inventoryLotStatusSnapshot']?.toString());
    final lotQtySnap = fv['lotAvailableQtySnapshot'] is num
        ? fv['lotAvailableQtySnapshot'] as num
        : num.tryParse('${fv['lotAvailableQtySnapshot']}');
    final lotUnitSnap = (fv['lotUnitSnapshot'] ?? '').toString().trim();
    final batchSnap = _dash(fv['batchNumberSnapshot']?.toString());
    final phase = operationPhaseLabel(fv['operationPhaseKey']?.toString());
    final purpose =
        preparationPurposeLabel(fv['preparationPurpose']?.toString());
    final workLocation = _dash(_workLocationDisplay(fv));
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

    final operatorSession = _dash(session.operatorDisplayName);
    final openedBy = _dash(session.createdByDisplayName);

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
                if (productCode != '—') kv('Šifra proizvoda', productCode),
              ],
              [
                kv('Faza operacije', phase),
                kv('Mjesto rada', workLocation),
                kv('Svrha pripreme', purpose),
              ],
            ),
            sectionTitle('Materijal'),
            twoCol(
              [
                kv('Materijal', materialName),
                if (materialCode != '—' && materialCode != materialName)
                  kv('Šifra materijala', materialCode),
                kv('Vrsta stavke', kindLabel),
                kv('Način sljedivosti', modeLabel),
                if (!lotRequired)
                  kv('Lot / šarža', ompLotNotRequiredBanner)
                else ...[
                  kv('Lot / šarža', materialLot),
                  if (lotSourceLabel != null && materialLot != '—')
                    kv('Izvor lota', lotSourceLabel),
                  if (batchSnap != '—') kv('Šarža', batchSnap),
                ],
              ],
              [
                if (lotRequired && warehouseSnap != '—')
                  kv('Skladište', warehouseSnap),
                if (lotRequired && lotStatusSnap != '—')
                  kv('Status lota', lotStatusSnap),
                if (lotRequired && lotQtySnap != null)
                  kv(
                    'Dostupna količina (WMS)',
                    _formatQtyWithUnit(
                      lotQtySnap,
                      lotUnitSnap.isEmpty ? null : lotUnitSnap,
                    ),
                  ),
                kv(
                  'Pripremljena količina',
                  _formatQtyWithUnit(preparedQty, unitOrNull),
                ),
                kv('Vrijeme pripreme', _formatDateTime(preparedAt)),
                kv('Komentar', operatorComment),
              ],
            ),
            sectionTitle('Predaja i verifikacija'),
            twoCol(
              [
                kv('Operater', operatorSession),
                kv('Kreirano', _formatDateTime(session.createdAt)),
              ],
              [
                kv('Sesiju otvorio', openedBy),
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
    final material = (session.fieldValues['materialCodeSnapshot'] ??
            session.fieldValues['materialNameSnapshot'] ??
            'materijal')
        .toString()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final shortId = session.sessionId.length > 8
        ? session.sessionId.substring(0, 8)
        : session.sessionId;
    if (order.trim().isNotEmpty) {
      return 'priprema_materijala_operacija_${order.trim()}_$material';
    }
    return 'priprema_materijala_operacija_${material}_$shortId';
  }
}
