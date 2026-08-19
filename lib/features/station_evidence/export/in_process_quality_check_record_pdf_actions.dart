import 'package:printing/printing.dart';

import '../../../modules/commercial/orders/services/company_print_identity_service.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import 'in_process_quality_check_record_pdf.dart';

/// M1-I4-C5 — Pregled / Preuzmi / Print / Pošalji za evidencijski zapisnik.
class InProcessQualityCheckRecordPdfActions {
  InProcessQualityCheckRecordPdfActions({
    ProfileDrivenEvidenceCallableService? service,
    CompanyPrintIdentityService? identityService,
  }) : _service = service ?? ProfileDrivenEvidenceCallableService(),
       _identityService = identityService ?? CompanyPrintIdentityService();

  final ProfileDrivenEvidenceCallableService _service;
  final CompanyPrintIdentityService _identityService;

  Future<
      ({
        ProfileDrivenEvidenceSessionDetail session,
        CompanyPrintIdentity? printIdentity,
      })> _prepare({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
    ProfileDrivenEvidenceSessionDetail? session,
  }) async {
    final detail = session ??
        await _service.getProfileDrivenEvidenceSession(
          companyId: companyId,
          sessionId: sessionId,
        );
    if (detail.processProfileType != 'in_process_quality_check') {
      throw StateError(
        'PDF zapisnik je dostupan samo za Procesnu kontrolu kvaliteta.',
      );
    }
    if (detail.status.trim().toLowerCase() != 'closed') {
      throw StateError(
        'PDF zapisnik je dostupan tek nakon završetka evidencije.',
      );
    }
    CompanyPrintIdentity? printIdentity;
    try {
      printIdentity = await _identityService.load(
        companyId: companyId,
        companyData: companyData,
      );
    } catch (_) {
      printIdentity = null;
    }
    return (session: detail, printIdentity: printIdentity);
  }

  Future<void> preview({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
    required String plantDisplayName,
    ProfileDrivenEvidenceSessionDetail? session,
  }) async {
    final prepared = await _prepare(
      companyId: companyId,
      sessionId: sessionId,
      companyData: companyData,
      session: session,
    );
    await InProcessQualityCheckRecordPdf.preview(
      session: prepared.session,
      companyData: companyData,
      plantDisplayName: plantDisplayName,
      printIdentity: prepared.printIdentity,
    );
  }

  Future<void> print({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
    required String plantDisplayName,
    ProfileDrivenEvidenceSessionDetail? session,
  }) async {
    await preview(
      companyId: companyId,
      sessionId: sessionId,
      companyData: companyData,
      plantDisplayName: plantDisplayName,
      session: session,
    );
  }

  Future<void> downloadOrShare({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
    required String plantDisplayName,
    ProfileDrivenEvidenceSessionDetail? session,
  }) async {
    final prepared = await _prepare(
      companyId: companyId,
      sessionId: sessionId,
      companyData: companyData,
      session: session,
    );
    final bytes = await InProcessQualityCheckRecordPdf.buildPdfBytes(
      session: prepared.session,
      companyData: companyData,
      plantDisplayName: plantDisplayName,
      printIdentity: prepared.printIdentity,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${InProcessQualityCheckRecordPdf.safeFileName(prepared.session)}.pdf',
    );
  }

  /// Isto dijeljenje datoteke kao Preuzmi — eksplicitna „Pošalji PDF” akcija.
  Future<void> share({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
    required String plantDisplayName,
    ProfileDrivenEvidenceSessionDetail? session,
  }) =>
      downloadOrShare(
        companyId: companyId,
        sessionId: sessionId,
        companyData: companyData,
        plantDisplayName: plantDisplayName,
        session: session,
      );
}
