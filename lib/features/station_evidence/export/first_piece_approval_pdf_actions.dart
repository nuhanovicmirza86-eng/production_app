import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../../../modules/commercial/orders/services/company_print_identity_service.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import 'first_piece_approval_pdf.dart';
import 'first_piece_approval_release_document.dart';

/// UI akcije: Pregled / Preuzmi / Print za M1-I3-G PDF.
class FirstPieceApprovalPdfActions {
  FirstPieceApprovalPdfActions({
    ProfileDrivenEvidenceCallableService? service,
    CompanyPrintIdentityService? identityService,
  }) : _service = service ?? ProfileDrivenEvidenceCallableService(),
       _identityService = identityService ?? CompanyPrintIdentityService();

  final ProfileDrivenEvidenceCallableService _service;
  final CompanyPrintIdentityService _identityService;

  Future<
      ({
        FirstPieceApprovalReleaseDocument document,
        CompanyPrintIdentity? printIdentity,
        Uint8List? productImageBytes,
      })> _prepare({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
  }) async {
    final document = await _service.getFirstPieceApprovalReleaseDocument(
      companyId: companyId,
      sessionId: sessionId,
    );
    CompanyPrintIdentity? printIdentity;
    try {
      printIdentity = await _identityService.load(
        companyId: companyId,
        companyData: companyData,
      );
    } catch (_) {
      printIdentity = null;
    }
    final productImageBytes =
        await FirstPieceApprovalPdf.tryLoadProductImageBytes(document);
    return (
      document: document,
      printIdentity: printIdentity,
      productImageBytes: productImageBytes,
    );
  }

  Future<void> preview({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
  }) async {
    final prepared = await _prepare(
      companyId: companyId,
      sessionId: sessionId,
      companyData: companyData,
    );
    await FirstPieceApprovalPdf.preview(
      document: prepared.document,
      companyData: companyData,
      printIdentity: prepared.printIdentity,
      productImageBytes: prepared.productImageBytes,
    );
  }

  Future<void> print({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
  }) async {
    await preview(
      companyId: companyId,
      sessionId: sessionId,
      companyData: companyData,
    );
  }

  Future<void> downloadOrShare({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> companyData,
  }) async {
    final prepared = await _prepare(
      companyId: companyId,
      sessionId: sessionId,
      companyData: companyData,
    );
    final bytes = await FirstPieceApprovalPdf.buildPdfBytes(
      document: prepared.document,
      companyData: companyData,
      printIdentity: prepared.printIdentity,
      productImageBytes: prepared.productImageBytes,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_fileName(prepared.document)}.pdf',
    );
  }

  static String _fileName(FirstPieceApprovalReleaseDocument document) {
    final code = document.productCode.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final order = (document.productionOrderCode ?? '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return order.isNotEmpty
        ? 'odobrenje_prvog_komada_${order}_$code'
        : 'odobrenje_prvog_komada_$code';
  }
}
