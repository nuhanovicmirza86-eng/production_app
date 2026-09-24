import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/station_evidence/export/operation_material_preparation_record_pdf.dart';
import 'package:production_app/features/station_evidence/models/profile_driven_evidence_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M1-I8-D builds operation material preparation PDF bytes', () async {
    final session = ProfileDrivenEvidenceSessionDetail(
      sessionId: 'smokeSessionI8D',
      companyId: 'plamingo',
      stationConfigId: 'cfg',
      plantKey: 'PLANT_2',
      processProfileType: 'operation_material_preparation',
      status: 'closed',
      stationDisplayName: 'Priprema materijala za operaciju smoke',
      startedAt: DateTime.utc(2026, 8, 25, 8),
      endedAt: DateTime.utc(2026, 8, 25, 9),
      createdAt: DateTime.utc(2026, 8, 25, 8),
      operatorDisplayName: 'Operater Test',
      operatorEmail: 'operater@example.com',
      createdByDisplayName: 'Admin Test',
      createdByEmail: 'admin@example.com',
      profileSnapshot: const {
        'displayName': 'Priprema materijala za operaciju',
        'catalogVersion': 25,
      },
      fieldValues: {
        'productionOrderCode': 'PO-SMOKE-OMP',
        'productNameSnapshot': 'Proizvod smoke',
        'productCode': 'PRD-1',
        'operationPhaseKey': 'obrada',
        'workContextType': 'machine',
        'workLocationNameSnapshot': 'Mašina: injection machine 1',
        'materialNameSnapshot': 'Komponenta A',
        'materialCodeSnapshot': 'MAT-A',
        'materialLot': 'LOT-I8D-001',
        // Bez materialLotSource — PDF mora i dalje označiti ručni izvor.
        'preparationPurpose': 'for_operation',
        'preparedQuantity': 7.5,
        'unit': 'kg',
        'preparedAt': '2026-08-25T08:30:00.000Z',
        'operatorComment': 'smoke napomena',
        'qmsControlledFormDocumentCode': 'QF-OMP-001',
        'qmsControlledFormRevision': 1,
        'qmsControlledFormStatus': 'approved',
        'qmsControlledFormTitle': 'Priprema materijala za operaciju',
      },
      summaryFields: const ProfileDrivenEvidenceSummaryFields(
        productionOrderCode: 'PO-SMOKE-OMP',
        productName: 'Proizvod smoke',
        productCode: 'PRD-1',
        quantity: 7.5,
        unit: 'kg',
        operatorSummary: 'Operater Test',
      ),
    );

    final Uint8List bytes =
        await OperationMaterialPreparationRecordPdf.buildPdfBytes(
      session: session,
      companyData: const {
        'companyId': 'plamingo',
        'name': 'Smoke Company',
      },
      plantDisplayName: 'PLANT_2',
    );

    expect(bytes.length, greaterThan(1000));
    expect(
      OperationMaterialPreparationRecordPdf.documentTitle,
      'Evidencijski zapisnik — Priprema materijala za operaciju',
    );
    expect(
      OperationMaterialPreparationRecordPdf.operationPhaseLabel('obrada'),
      'Obrada',
    );
    expect(
      OperationMaterialPreparationRecordPdf.preparationPurposeLabel(
        'for_operation',
      ),
      'Za operaciju',
    );
    expect(
      OperationMaterialPreparationRecordPdf.unlinkedControlledFormMessage,
      'Obrazac nije povezan / nije odobren',
    );
    expect(
      OperationMaterialPreparationRecordPdf.safeFileName(session),
      contains('priprema_materijala_operacija'),
    );
  });
}
