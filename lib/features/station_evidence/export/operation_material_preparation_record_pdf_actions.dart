import 'package:printing/printing.dart';

import '../../../modules/commercial/orders/services/company_print_identity_service.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import 'operation_material_preparation_record_pdf.dart';

/// M1-I8-D — Pregled / Preuzmi / Print / Pošalji za Pripremu materijala za operaciju.
class OperationMaterialPreparationRecordPdfActions {
  OperationMaterialPreparationRecordPdfActions({
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
    if (detail.processProfileType != 'operation_material_preparation') {
      throw StateError(
        'PDF zapisnik je dostupan samo za Pripremu materijala za operaciju.',
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
    await OperationMaterialPreparationRecordPdf.preview(
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
    final bytes = await OperationMaterialPreparationRecordPdf.buildPdfBytes(
      session: prepared.session,
      companyData: companyData,
      plantDisplayName: plantDisplayName,
      printIdentity: prepared.printIdentity,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${OperationMaterialPreparationRecordPdf.safeFileName(prepared.session)}.pdf',
    );
  }

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
