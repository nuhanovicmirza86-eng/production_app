import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/profile_driven_structured_runtime/utils/structured_piece_quantity.dart';

void main() {
  test('HOTFIX-29 Škart 0 + Dorada 0 automatski postavlja Bez greške', () {
    final selections = <String, String?>{'defectReason': 'VIZUELNA_GRESKA'};
    syncFinalControlDefectReasonCode(
      enumSelections: selections,
      scrapQty: 0,
      reworkQty: 0,
    );
    expect(selections['defectReason'], finalControlNoDefectReasonCode);
    expect(
      finalControlDefectReasonIssue(
        scrapQty: 0,
        reworkQty: 0,
        defectReason: selections['defectReason'],
      ),
      isNull,
    );
    expect(
      packagingDefectReasonLabel(finalControlNoDefectReasonCode),
      'Bez greške',
    );
  });

  test('HOTFIX-29 Škart > 0 ne dozvoljava Bez greške', () {
    final selections = <String, String?>{
      'defectReason': finalControlNoDefectReasonCode,
    };
    syncFinalControlDefectReasonCode(
      enumSelections: selections,
      scrapQty: 2,
      reworkQty: 0,
    );
    expect(selections['defectReason'], isNull);
    expect(
      finalControlDefectReasonIssue(
        scrapQty: 2,
        reworkQty: 0,
        defectReason: finalControlNoDefectReasonCode,
      ),
      isNotNull,
    );
    expect(
      finalControlDefectReasonIssue(
        scrapQty: 2,
        reworkQty: 0,
        defectReason: 'VIZUELNA_GRESKA',
      ),
      isNull,
    );
  });

  test('HOTFIX-29 Dorada > 0 ne dozvoljava Bez greške', () {
    expect(
      finalControlDefectReasonIssue(
        scrapQty: 0,
        reworkQty: 1,
        defectReason: '',
      ),
      isNotNull,
    );
    expect(
      finalControlDefectReasonIssue(
        scrapQty: 0,
        reworkQty: 1,
        defectReason: 'OŠTEĆENJE',
      ),
      isNull,
    );
  });
}
