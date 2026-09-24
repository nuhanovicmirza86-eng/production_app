import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/cleaning_checklist_mode.dart';

void main() {
  test('HOTFIX-19 default načina liste', () {
    expect(
      defaultCleaningChecklistMode('workspace_5s_cleaning'),
      cleaningChecklistModeQuick,
    );
    expect(
      defaultCleaningChecklistMode('line_clearance'),
      cleaningChecklistModeExtended,
    );
  });

  test('HOTFIX-19 5S brza lista skriva detaljne 5S stavke', () {
    expect(
      isCleaningChecklistFieldVisible(
        profileKey: 'workspace_5s_cleaning',
        fieldKey: 'fiveSSortConfirmed',
        mode: cleaningChecklistModeQuick,
        outcome: 'satisfies',
      ),
      isFalse,
    );
    expect(
      isCleaningChecklistFieldVisible(
        profileKey: 'workspace_5s_cleaning',
        fieldKey: 'quickCleanSurface',
        mode: cleaningChecklistModeQuick,
        outcome: 'satisfies',
      ),
      isTrue,
    );
    expect(
      isCleaningChecklistFieldVisible(
        profileKey: 'workspace_5s_cleaning',
        fieldKey: 'operatorComment',
        mode: cleaningChecklistModeQuick,
        outcome: 'satisfies',
      ),
      isFalse,
    );
    expect(
      isCleaningChecklistFieldVisible(
        profileKey: 'workspace_5s_cleaning',
        fieldKey: 'operatorComment',
        mode: cleaningChecklistModeQuick,
        outcome: 'does_not_satisfy',
      ),
      isTrue,
    );
  });

  test('HOTFIX-19 čišćenje mašine proširena ne pokazuje brze korake', () {
    expect(
      isCleaningChecklistFieldVisible(
        profileKey: 'line_clearance',
        fieldKey: 'quickCleanSurface',
        mode: cleaningChecklistModeExtended,
        outcome: null,
      ),
      isFalse,
    );
    expect(
      isCleaningChecklistFieldVisible(
        profileKey: 'line_clearance',
        fieldKey: 'clearanceType',
        mode: cleaningChecklistModeExtended,
        outcome: null,
      ),
      isTrue,
    );
    expect(
      isCleaningChecklistFieldVisible(
        profileKey: 'line_clearance',
        fieldKey: 'previousProductId',
        mode: cleaningChecklistModeQuick,
        outcome: 'satisfies',
      ),
      isFalse,
    );
  });

  test('HOTFIX-19 brza lista zahtijeva tri koraka i ishod', () {
    expect(
      cleaningQuickFinishValidationMessage(
        enumSelections: const {},
        fieldValues: const {},
      ),
      contains('Radna površina očišćena'),
    );
    expect(
      cleaningQuickFinishValidationMessage(
        enumSelections: const {
          'quickCleanSurface': 'ok',
          'quickCleanWaste': 'ok',
          'quickCleanAisles': 'ok',
          'outcome': 'satisfies',
        },
        fieldValues: const {},
      ),
      isNull,
    );
    expect(
      cleaningQuickFinishValidationMessage(
        enumSelections: const {
          'quickCleanSurface': 'ok',
          'quickCleanWaste': 'ok',
          'quickCleanAisles': 'ok',
          'outcome': 'does_not_satisfy',
        },
        fieldValues: const {},
      ),
      contains('komentar'),
    );
  });
}
