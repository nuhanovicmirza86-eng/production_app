import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/profile_driven_structured_runtime/utils/structured_piece_quantity.dart';

void main() {
  test('Odbijeno = 0 automatski postavlja Bez greške', () {
    final selections = <String, String?>{'defectReasonCode': 'VIZUELNA_GRESKA'};
    syncPackagingDefectReasonCode(
      enumSelections: selections,
      unitsRejected: 0,
    );
    expect(selections['defectReasonCode'], packagingNoDefectReasonCode);
    expect(packagingDefectReasonIssue(
      unitsRejected: 0,
      defectReasonCode: selections['defectReasonCode'],
    ), isNull);
    expect(
      packagingDefectReasonLabel(packagingNoDefectReasonCode),
      'Bez greške',
    );
  });

  test('Odbijeno > 0 ne dozvoljava Bez greške', () {
    final selections = <String, String?>{
      'defectReasonCode': packagingNoDefectReasonCode,
    };
    syncPackagingDefectReasonCode(
      enumSelections: selections,
      unitsRejected: 2,
    );
    expect(selections['defectReasonCode'], isNull);
    expect(
      packagingDefectReasonIssue(
        unitsRejected: 2,
        defectReasonCode: packagingNoDefectReasonCode,
      ),
      isNotNull,
    );
    expect(
      packagingDefectReasonIssue(
        unitsRejected: 2,
        defectReasonCode: 'VIZUELNA_GRESKA',
      ),
      isNull,
    );
  });
}
