import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/workspace_5s_cleaning_fields.dart';
import 'package:production_app/features/profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_profile_field.dart';

void main() {
  test('5S checklist chips become required deviation only on Nije u redu', () {
    expect(
      workspace5sFinishValidationMessage(
        enumSelections: {
          for (final key in workspace5sChecklistFieldKeys) key: 'ok',
        },
        fieldValues: {'workplaceZoneId': '__zone_work_table__'},
        workplaceZoneId: '__zone_work_table__',
      ),
      isNull,
    );

    expect(
      workspace5sFinishValidationMessage(
        enumSelections: {
          for (final key in workspace5sChecklistFieldKeys) key: 'ok',
          'fiveSAislesConfirmed': 'not_ok',
        },
        fieldValues: {'workplaceZoneId': '__zone_work_table__'},
        workplaceZoneId: '__zone_work_table__',
      ),
      contains('opis odstupanja'),
    );

    expect(
      workspace5sFinishValidationMessage(
        enumSelections: {
          for (final key in workspace5sChecklistFieldKeys) key: 'ok',
          'fiveSAislesConfirmed': 'not_ok',
        },
        fieldValues: {
          'workplaceZoneId': '__zone_work_table__',
          'deviationDescription': 'Prolaz je blokiran paletama.',
        },
        workplaceZoneId: '__zone_work_table__',
      ),
      isNull,
    );
  });

  test('5S Drugo requires zone name; presets do not', () {
    expect(
      workspace5sFinishValidationMessage(
        enumSelections: {
          for (final key in workspace5sChecklistFieldKeys) key: 'ok',
        },
        fieldValues: {'workplaceZoneId': workspace5sZoneOtherId},
        workplaceZoneId: workspace5sZoneOtherId,
      ),
      contains('Drugo'),
    );
    expect(
      workspace5sFinishValidationMessage(
        enumSelections: {
          for (final key in workspace5sChecklistFieldKeys) key: 'ok',
        },
        fieldValues: {
          'workplaceZoneId': workspace5sZoneOtherId,
          'workplaceZoneOther': 'Ulaz u alatnicu',
        },
        workplaceZoneId: workspace5sZoneOtherId,
      ),
      isNull,
    );
  });

  test('5S zone chips include plant workbenches, presets and Drugo', () {
    final merged = mergeWorkspace5sZoneChoices(
      plantWorkbenches: const [
        StructuredEntitySearchResult(
          id: 'wb1',
          displayLabel: 'RS-01 — Sto brizganje',
        ),
      ],
      query: '',
    );
    expect(merged.map((e) => e.displayLabel), contains('RS-01 — Sto brizganje'));
    expect(merged.map((e) => e.displayLabel), contains('Radni sto'));
    expect(merged.map((e) => e.displayLabel), contains('Drugo'));
    expect(merged.any((e) => e.id == 'wb1'), isTrue);
  });

  test('deviationDescription visibleWhen any Nije u redu', () {
    final field = ProductionStationProfileField.fromMap({
      'key': 'deviationDescription',
      'label': 'Opis odstupanja / potrebna korekcija',
      'type': 'text',
      'required': false,
      'visibleWhen': {
        'anyOfFields': workspace5sChecklistFieldKeys,
        'equals': 'not_ok',
      },
    });
    expect(
      field.isVisibleGiven(
        fieldValues: const {},
        enumSelections: {
          for (final key in workspace5sChecklistFieldKeys) key: 'ok',
        },
      ),
      isFalse,
    );
    expect(
      field.isVisibleGiven(
        fieldValues: const {},
        enumSelections: {
          for (final key in workspace5sChecklistFieldKeys) key: 'ok',
          'fiveSOrderConfirmed': 'not_ok',
        },
      ),
      isTrue,
    );
  });

  test('5S enum uiControl chips is parsed from catalog', () {
    final field = ProductionStationProfileField.fromMap({
      'key': 'fiveSSortConfirmed',
      'label': 'Sortiranje nepotrebnih stvari',
      'type': 'enum',
      'required': true,
      'uiControl': 'chips',
      'enumValues': ['ok', 'not_ok', 'na'],
      'enumLabels': {
        'ok': 'U redu',
        'not_ok': 'Nije u redu',
        'na': 'Nije primjenjivo',
      },
    });
    expect(field.usesChipEnumControl, isTrue);
    expect(field.enumLabelFor('not_ok'), 'Nije u redu');
  });
}
