import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/operator_evidence_ux_standard.dart';
import 'package:production_app/features/profile_driven_structured_runtime/utils/structured_piece_quantity.dart';

void main() {
  test('Ne prolazi = 0 automatski postavlja Bez greške', () {
    final selections = <String, String?>{'defectReasonCode': 'VIZUELNA_GRESKA'};
    syncInspectionDefectReasonCode(
      enumSelections: selections,
      qtyFail: 0,
    );
    expect(selections['defectReasonCode'], noDefectReasonCode);
    expect(
      inspectionDefectReasonIssue(
        qtyFail: 0,
        defectReasonCode: selections['defectReasonCode'],
      ),
      isNull,
    );
    expect(
      OperatorEvidenceUxStandard.defectReasonLabel(noDefectReasonCode),
      'Bez greške',
    );
  });

  test('Ne prolazi > 0 ne dozvoljava Bez greške', () {
    final selections = <String, String?>{
      'defectReasonCode': noDefectReasonCode,
    };
    syncInspectionDefectReasonCode(
      enumSelections: selections,
      qtyFail: 2,
    );
    expect(selections['defectReasonCode'], isNull);
    expect(
      inspectionDefectReasonIssue(
        qtyFail: 2,
        defectReasonCode: noDefectReasonCode,
      ),
      isNotNull,
    );
    expect(
      inspectionDefectReasonIssue(
        qtyFail: 2,
        defectReasonCode: 'VIZUELNA_GRESKA',
      ),
      isNull,
    );
  });
}
