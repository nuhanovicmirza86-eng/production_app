import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/station_evidence/export/in_process_quality_check_record_pdf.dart';
import 'package:production_app/features/station_evidence/models/profile_driven_evidence_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M1-I4-C5 builds evidencijski zapisnik PDF bytes', () async {
    final session = ProfileDrivenEvidenceSessionDetail(
      sessionId: 'smokeSessionC5',
      companyId: 'plamingo',
      stationConfigId: 'cfg',
      plantKey: 'BR',
      processProfileType: 'in_process_quality_check',
      status: 'closed',
      stationDisplayName: 'Smoke stanica',
      startedAt: DateTime.utc(2026, 8, 18, 8),
      endedAt: DateTime.utc(2026, 8, 18, 9),
      createdAt: DateTime.utc(2026, 8, 18, 8),
      operatorDisplayName: 'Kontrolor Test',
      operatorEmail: 'kontrolor@example.com',
      createdByDisplayName: 'Admin Test',
      createdByEmail: 'admin@example.com',
      profileSnapshot: const {
        'displayName': 'Procesna kontrola kvaliteta',
        'catalogVersion': 18,
      },
      fieldValues: {
        'productionOrderCode': 'PO-SMOKE-18',
        'productNameSnapshot': 'Čep smoke',
        'productCodeSnapshot': 'CAP-1',
        'workContextType': 'machine',
        'machineNameSnapshot': 'injection machine 1',
        'inspectorNameSnapshot': 'Mirza Nuhanovic',
        'productionOperatorNameSnapshot': 'Edin Isić',
        'inspectionOutcome': 'fail',
        'operatorComment': 'smoke napomena',
        'qmsControlledFormDocumentCode': 'QF-PC-001',
        'qmsControlledFormStatus': null,
        'inspectionStartedAt': '2026-08-18T10:00:00.000Z',
        'inspectionFinishedAt': '2026-08-18T10:15:00.000Z',
      },
      summaryFields: const ProfileDrivenEvidenceSummaryFields(
        productionOrderCode: 'PO-SMOKE-18',
        productName: 'Čep smoke',
        productCode: 'CAP-1',
        quantity: 14,
        okTotalQty: 11,
        scrapTotalQty: 3,
        unit: 'kom',
        operatorSummary: 'Mirza Nuhanovic',
        packagingOperatorName: 'Edin Isić',
      ),
      inspectionLines: const [
        {
          'checkpointName': 'Vizuelna kontrola',
          'qtyInspected': 14,
          'qtyPass': 11,
          'qtyFail': 3,
          'unit': 'kom',
          'defectReasonCode': 'OŠTEĆENJE',
          'measurementNote': 'ogrebotina',
        },
      ],
    );

    final Uint8List bytes = await InProcessQualityCheckRecordPdf.buildPdfBytes(
      session: session,
      companyData: const {
        'companyId': 'plamingo',
        'name': 'Smoke Company',
      },
      plantDisplayName: 'Brizganje (BR)',
    );

    expect(bytes.length, greaterThan(1000));
    expect(
      InProcessQualityCheckRecordPdf.documentTitle,
      'Evidencijski zapisnik — Procesna kontrola kvaliteta',
    );
    expect(
      InProcessQualityCheckRecordPdf.unlinkedControlledFormMessage,
      'Obrazac nije povezan / nije odobren',
    );
    expect(
      InProcessQualityCheckRecordPdf.outcomeBanner('fail'),
      'NE PROLAZI / PROCESNA KONTROLA NIJE ZADOVOLJILA',
    );
    expect(
      InProcessQualityCheckRecordPdf.outcomeBanner('pass'),
      'PROLAZI / PROCESNA KONTROLA ZADOVOLJAVA',
    );
    expect(
      InProcessQualityCheckRecordPdf.outcomeBanner('conditional_pass'),
      'USLOVNO PROLAZI / POTREBNA PROVJERA ILI KOREKCIJA',
    );
    final name = InProcessQualityCheckRecordPdf.safeFileName(session);
    expect(name, contains('procesna_kontrola'));
    expect(name.toLowerCase(), isNot(contains('odobrenje_prvog')));
  });
}
