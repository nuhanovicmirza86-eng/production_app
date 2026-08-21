import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/station_evidence/export/evidence_pdf_qms_document_marking.dart';

void main() {
  group('M1-I5-C6 EvidencePdfQmsDocumentMarking', () {
    test('unlinked when status not approved', () {
      expect(
        EvidencePdfQmsDocumentMarking.isLinkedApproved(
          status: 'draft',
          code: 'OBR-KV-04',
        ),
        isFalse,
      );
      expect(
        EvidencePdfQmsDocumentMarking.unlinkedMessage,
        'Obrazac nije povezan / nije odobren',
      );
    });

    test('linked when approved with code', () {
      expect(
        EvidencePdfQmsDocumentMarking.isLinkedApproved(
          status: 'approved',
          code: 'OBR-KV-04',
        ),
        isTrue,
      );
    });

    test('statusLabel maps approved to Aktivno', () {
      expect(
        EvidencePdfQmsDocumentMarking.statusLabel('approved'),
        'Aktivno',
      );
    });
  });
}
