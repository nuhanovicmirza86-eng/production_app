import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/line_clearance_verification.dart';
import 'package:production_app/features/profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_profile_field.dart';

void main() {
  test('HOTFIX-27 products only for Promjena proizvoda', () {
    expect(isLineClearanceProductChangeover('after_downtime'), isFalse);
    expect(
      isLineClearanceProductChangeover('product_changeover_clean'),
      isTrue,
    );
    final previous = ProductionStationProfileField.fromMap({
      'key': 'previousProductId',
      'label': 'Prethodni proizvod',
      'type': 'entity_search_select',
      'visibleWhen': {
        'field': 'clearanceType',
        'equals': 'product_changeover_clean',
      },
    });
    expect(
      previous.isVisibleGiven(
        fieldValues: const {'clearanceType': 'after_downtime'},
        enumSelections: const {},
      ),
      isFalse,
    );
    expect(
      previous.isVisibleGiven(
        fieldValues: const {},
        enumSelections: const {'clearanceType': 'product_changeover_clean'},
      ),
      isTrue,
    );
  });

  test('HOTFIX-27 verifier fields stay out of operator header', () {
    final field = ProductionStationProfileField.fromMap({
      'key': 'siteConditionChecked',
      'label': 'Stanje provjereno na terenu',
      'type': 'boolean',
      'operatorEditable': false,
      'verifierEditable': true,
    });
    expect(field.isOperatorEditable, isFalse);
    expect(field.isVerifierEditable, isTrue);
  });

  test('HOTFIX-27 place label uses business code and names, never raw id', () {
    final label = lineClearanceVerifiedPlaceLabel(
      fieldValues: const {
        'workCenterNameSnapshot': 'Glavna linija',
        'machineNameSnapshot': 'injection machine 1',
      },
      workCenter: StructuredEntitySelection(
        fieldKey: 'workCenterId',
        entityId: 'abcdefghijklmnopqrst',
        displayLabel: 'RC-001 — Glavna linija',
        raw: {
          'code': 'RC-001',
          'displayName': 'Glavna linija',
        },
      ),
      machine: StructuredEntitySelection(
        fieldKey: 'machineId',
        entityId: 'xyzabcdefghijklmnopqrst',
        displayLabel: 'injection machine 1',
        raw: {'displayName': 'injection machine 1'},
      ),
    );
    expect(label, 'RC-001 — Glavna linija / injection machine 1');
    expect(label.contains('abcdefghijklmnopqrst'), isFalse);
    expect(label.contains('PLANT_'), isFalse);
  });

  test('HOTFIX-27 finish requires site check and ready-for-work', () {
    expect(
      lineClearanceSiteVerificationFinishMessage(const {}),
      'Potvrdite da je stanje provjereno na terenu.',
    );
    expect(
      lineClearanceSiteVerificationFinishMessage(const {
        'siteConditionChecked': true,
      }),
      'Odaberite je li linija / mašina spremna za rad.',
    );
    expect(
      lineClearanceSiteVerificationFinishMessage(const {
        'siteConditionChecked': true,
        'readyForWork': false,
      }),
      contains('potrebnu korekciju'),
    );
    expect(
      lineClearanceSiteVerificationFinishMessage(const {
        'siteConditionChecked': true,
        'readyForWork': false,
        'readinessCorrection': 'Ostaci na alatu',
      }),
      isNull,
    );
    expect(
      lineClearanceSiteVerificationFinishMessage(const {
        'siteConditionChecked': true,
        'readyForWork': true,
      }),
      isNull,
    );
  });

  test('HOTFIX-27 DA/NE never shows true/false', () {
    expect(formatEvidenceYesNo(true), 'DA');
    expect(formatEvidenceYesNo(false), 'NE');
    expect(formatEvidenceYesNoOrDash(null), '—');
  });
}
