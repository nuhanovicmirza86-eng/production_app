import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/station_evidence/export/final_control_record_pdf.dart';
import 'package:production_app/features/station_evidence/models/profile_driven_evidence_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M1-I5-B builds Finalna kontrola PDF bytes', () async {
    final session = ProfileDrivenEvidenceSessionDetail(
      sessionId: 'smokeSessionI5B',
      companyId: 'plamingo',
      stationConfigId: 'cfg',
      plantKey: 'BR',
      processProfileType: 'final_control',
      status: 'closed',
      stationDisplayName: 'Finalna kontrola smoke',
      startedAt: DateTime.utc(2026, 8, 19, 8),
      endedAt: DateTime.utc(2026, 8, 19, 9),
      createdAt: DateTime.utc(2026, 8, 19, 8),
      operatorDisplayName: 'Kontrolor Test',
      operatorEmail: 'kontrolor@example.com',
      createdByDisplayName: 'Admin Test',
      createdByEmail: 'admin@example.com',
      profileSnapshot: const {
        'displayName': 'Finalna kontrola',
        'catalogVersion': 21,
      },
      fieldValues: {
        'productionOrderCode': 'PO-SMOKE-FC',
        'productNameSnapshot': 'Čep final',
        'productCode': 'CAP-F',
        'controllerNameSnapshot': 'Mirza Nuhanovic',
        'finalDisposition': 'approved',
        'operatorComment': 'smoke napomena',
        'qmsControlledFormDocumentCode': 'QF-FC-001',
        'qmsControlledFormStatus': null,
      },
      summaryFields: const ProfileDrivenEvidenceSummaryFields(
        productionOrderCode: 'PO-SMOKE-FC',
        productName: 'Čep final',
        productCode: 'CAP-F',
        quantity: 20,
        okTotalQty: 18,
        scrapTotalQty: 1,
        reworkAgainTotalQty: 1,
        unit: 'kom',
        operatorSummary: 'Mirza Nuhanovic',
        resultStatus: 'Odobreno',
      ),
      controlledItems: const [
        {
          'productNameSnapshot': 'Čep final',
          'productCode': 'CAP-F',
          'inspectedQty': 20,
          'goodQty': 18,
          'scrapQty': 1,
          'reworkQty': 1,
          'unit': 'kom',
          'defectReason': 'OŠTEĆENJE',
          'comment': 'ogrebotina',
        },
      ],
    );

    final Uint8List bytes = await FinalControlRecordPdf.buildPdfBytes(
      session: session,
      companyData: const {
        'companyId': 'plamingo',
        'name': 'Smoke Company',
      },
      plantDisplayName: 'Brizganje (BR)',
    );

    expect(bytes.length, greaterThan(1000));
    expect(
      FinalControlRecordPdf.documentTitle,
      'Evidencijski zapisnik — Finalna kontrola',
    );
    expect(
      FinalControlRecordPdf.dispositionBanner('approved'),
      'ODOBRENO / FINALNA KONTROLA ZADOVOLJAVA',
    );
    expect(
      FinalControlRecordPdf.dispositionBanner('recheck_required'),
      'POTREBNA PONOVNA KONTROLA',
    );
    expect(
      FinalControlRecordPdf.dispositionBanner('rework_required'),
      'POTREBNA DORADA',
    );
    expect(
      FinalControlRecordPdf.dispositionBanner('blocked'),
      'BLOKIRANO / NIJE ODOBRENO ZA DALJE',
    );
    expect(
      FinalControlRecordPdf.unlinkedControlledFormMessage,
      'Obrazac nije povezan / nije odobren',
    );
  });
}
