import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/station_evidence/export/evidence_pdf_qms_document_marking.dart';
import 'package:production_app/features/station_evidence/widgets/qms_controlled_form_help.dart';

void main() {
  group('QMS-M2 EvidencePdfQmsDocumentMarking', () {
    test('unlinked when status not approved', () {
      expect(
        EvidencePdfQmsDocumentMarking.isLinkedApproved(
          status: 'draft',
          code: 'BR_OB_0001',
        ),
        isFalse,
      );
      expect(
        EvidencePdfQmsDocumentMarking.unlinkedMessage,
        'Obrazac nije povezan / nije odobren',
      );
    });

    test('statusLabel maps approved to Odobreno', () {
      expect(
        EvidencePdfQmsDocumentMarking.statusLabel('approved'),
        'Odobreno',
      );
    });

    test('approval audit gap when approved without name', () {
      expect(
        EvidencePdfQmsDocumentMarking.hasApprovalAuditGap(
          status: 'approved',
          approvedByName: '',
          approvedAtIso: '2026-08-25T10:17:00.000Z',
        ),
        isTrue,
      );
      expect(
        EvidencePdfQmsDocumentMarking.approvedByDisplay(
          status: 'approved',
          approvedByName: '',
        ),
        EvidencePdfQmsDocumentMarking.approvalAuditGapMessage,
      );
      expect(
        EvidencePdfQmsDocumentMarking.approvalAuditGapMessage,
        'nedostaje audit odobrenja',
      );
    });

    test('no gap when name and date present', () {
      expect(
        EvidencePdfQmsDocumentMarking.hasApprovalAuditGap(
          status: 'approved',
          approvedByName: 'Mirza Nuhanovic',
          approvedAtIso: '2026-08-25T10:17:00.000Z',
        ),
        isFalse,
      );
    });

    test('UI assess maps gap and unlinked', () {
      expect(
        QmsControlledFormHelp.assess({
          'qmsControlledFormStatus': 'approved',
          'qmsControlledFormDocumentCode': 'BR_OB_0001',
          'qmsControlledFormApprovedAt': '2026-08-25T10:17:00.000Z',
        }),
        QmsMarkingUiState.approvalAuditGap,
      );
      expect(
        QmsControlledFormHelp.assess({
          'qmsControlledFormStatus': 'draft',
          'qmsControlledFormDocumentCode': 'BR_OB_0001',
        }),
        QmsMarkingUiState.unlinked,
      );
    });
  });
}
