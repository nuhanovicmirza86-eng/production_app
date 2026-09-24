import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/cleaning_handoff_persistence.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_profile_field.dart';

void main() {
  test('HOTFIX-25 snapshot keeps machine cleaning handoff keys', () {
    final snap = snapshotCleaningHandoffFieldValues(
      profileKey: 'line_clearance',
      fieldValues: {
        'shiftKey': 'shift_2',
        'clearanceType': 'after_downtime',
        'workCenterId': 'wc-1',
        'checklistConfirmed': true,
        'operatorComment': 'x',
      },
    );
    expect(snap['shiftKey'], 'shift_2');
    expect(snap['clearanceType'], 'after_downtime');
    expect(snap['workCenterId'], 'wc-1');
    expect(snap['checklistConfirmed'], true);
    expect(snap.containsKey('operatorComment'), isFalse);
  });

  test('HOTFIX-25 restore does not overwrite filled values', () {
    final target = <String, dynamic>{'shiftKey': 'shift_1'};
    restoreCleaningHandoffFieldValues(
      target: target,
      preserved: {'shiftKey': 'shift_3', 'clearanceType': 'scheduled_clean'},
    );
    expect(target['shiftKey'], 'shift_1');
    expect(target['clearanceType'], 'scheduled_clean');
  });

  test('HOTFIX-25 persist writes enum from selections when fieldValues empty', () {
    final fieldValues = <String, dynamic>{};
    persistStructuredHeaderControlsToFieldValues(
      fields: const [
        ProductionStationProfileField(
          key: 'shiftKey',
          label: 'Smjena',
          type: 'enum',
          required: true,
          enumValues: ['shift_1', 'shift_2', 'shift_3'],
        ),
      ],
      fieldValues: fieldValues,
      enumSelections: {'shiftKey': 'shift_2'},
      dateTimes: const {},
      entitySelections: const {},
    );
    expect(fieldValues['shiftKey'], 'shift_2');
  });

  test('HOTFIX-25 persist keeps saved enum when dropdown is empty', () {
    final fieldValues = <String, dynamic>{'shiftKey': 'shift_1'};
    persistStructuredHeaderControlsToFieldValues(
      fields: const [
        ProductionStationProfileField(
          key: 'shiftKey',
          label: 'Smjena',
          type: 'enum',
          required: true,
          enumValues: ['shift_1', 'shift_2', 'shift_3'],
        ),
      ],
      fieldValues: fieldValues,
      enumSelections: {'shiftKey': null},
      dateTimes: const {},
      entitySelections: const {},
    );
    expect(fieldValues['shiftKey'], 'shift_1');
  });

  test('HOTFIX-25 hydrate fills enum selections from saved shift', () {
    final enumSelections = <String, String?>{};
    applyCleaningHandoffEnumsFromFieldValues(
      fields: const [
        ProductionStationProfileField(
          key: 'shiftKey',
          label: 'Smjena',
          type: 'enum',
          required: true,
          enumValues: ['shift_1', 'shift_2', 'shift_3'],
        ),
      ],
      fieldValues: {'shiftKey': 'shift_3'},
      enumSelections: enumSelections,
    );
    expect(enumSelections['shiftKey'], 'shift_3');
  });

  test('HOTFIX-25 shift label is BCS without raw key', () {
    expect(
      cleaningHandoffShiftLabel(fieldValues: {'shiftKey': 'shift_2'}),
      '2. smjena',
    );
    expect(
      cleaningHandoffShiftLabel(fieldValues: {'shiftKey': 'shift_x'}),
      isNull,
    );
  });

  test('HOTFIX-26 snapshot keys are stripped from Callable payload', () {
    final payload = fieldValuesWithoutClientSnapshotKeys({
      'shiftKey': 'shift_1',
      'performedByEmployeeId': 'emp-1',
      'performedByNameSnapshot': 'Test korisnik',
      'performedByRoleSnapshot': 'Operater proizvodnje',
      'workCenterNameSnapshot': 'Glavna linija',
      'zoneNameSnapshot': 'Zona A',
      'verifiedByNameSnapshot': 'Mirza Nuhan',
    });
    expect(payload['shiftKey'], 'shift_1');
    expect(payload['performedByEmployeeId'], 'emp-1');
    expect(payload.containsKey('performedByNameSnapshot'), isFalse);
    expect(payload.containsKey('performedByRoleSnapshot'), isFalse);
    expect(payload.containsKey('workCenterNameSnapshot'), isFalse);
    expect(payload.containsKey('zoneNameSnapshot'), isFalse);
    expect(payload.containsKey('verifiedByNameSnapshot'), isFalse);
  });

  test('HOTFIX-26 lineName is a form field, not a snapshot key', () {
    expect(isBackendOwnedEvidenceSnapshotFieldKey('lineName'), isFalse);
    expect(
      isBackendOwnedEvidenceSnapshotFieldKey('performedByNameSnapshot'),
      isTrue,
    );
  });
}
