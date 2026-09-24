import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/line_clearance_line_name.dart';
import 'package:production_app/features/profile_driven_structured_runtime/models/structured_entity_search_result.dart';

void main() {
  test('HOTFIX-23 hides line name when work center is selected', () {
    expect(
      isLineClearanceLineNameFallbackVisible(
        workCenterId: 'wc-1',
        fieldValues: const {},
      ),
      isFalse,
    );
    expect(
      isLineClearanceLineNameFallbackVisible(
        fieldValues: const {'workCenterId': 'wc-1'},
      ),
      isFalse,
    );
  });

  test('HOTFIX-23 shows line name only as fallback without work center', () {
    expect(
      isLineClearanceLineNameFallbackVisible(
        workCenterId: '',
        fieldValues: const {},
      ),
      isTrue,
    );
  });

  test('HOTFIX-23 uses human work center name, not code or raw id', () {
    expect(
      lineClearanceLineNameFromWorkCenter(
        raw: const {'displayName': 'Glavna linija', 'code': 'RC-001'},
        displayLabel: 'RC-001 — Glavna linija',
      ),
      'Glavna linija',
    );
    expect(
      lineClearanceLineNameFromWorkCenter(
        displayLabel: 'RC-001 — Glavna linija',
      ),
      'Glavna linija',
    );
    expect(
      lineClearanceLineNameFromWorkCenter(
        raw: const {'displayName': 'AbCdEfGhIjKlMnOpQrSt'},
        displayLabel: 'AbCdEfGhIjKlMnOpQrSt',
      ),
      '',
    );
  });

  test('HOTFIX-23 fills line name from selected work center', () {
    final values = <String, dynamic>{'workCenterId': 'wc-1'};
    applyLineClearanceLineNameFromWorkCenter(
      fieldValues: values,
      workCenter: const StructuredEntitySelection(
        fieldKey: 'workCenterId',
        entityId: 'wc-1',
        displayLabel: 'RC-001 — Glavna linija',
        raw: {'displayName': 'Glavna linija', 'code': 'RC-001'},
      ),
    );
    expect(values['lineName'], 'Glavna linija');
    expect(values['workCenterNameSnapshot'], 'Glavna linija');
  });

  test('HOTFIX-23 keeps empty line name when no work center', () {
    final values = <String, dynamic>{};
    applyLineClearanceLineNameFromWorkCenter(
      fieldValues: values,
    );
    expect(values.containsKey('lineName'), isFalse);
  });
}
