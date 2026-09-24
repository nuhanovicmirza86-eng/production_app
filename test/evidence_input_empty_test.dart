import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/evidence_input_empty.dart';

void main() {
  test('HOTFIX-18 prazno i crtica nisu unesena vrijednost', () {
    expect(isEvidenceFormPlaceholder(null), isTrue);
    expect(isEvidenceFormPlaceholder(''), isTrue);
    expect(isEvidenceFormPlaceholder('—'), isTrue);
    expect(isEvidenceFormPlaceholder('–'), isTrue);
    expect(isEvidenceFormPlaceholder('-'), isTrue);
    expect(isEvidenceFormPlaceholder('  –  '), isTrue);
    expect(isEvidenceFormPlaceholder('Mirza Nuhanovic'), isFalse);
    expect(sanitizeEvidenceFormInput('—'), '');
    expect(sanitizeEvidenceFormInput('Mirza'), 'Mirza');
  });

  test('HOTFIX-18 entity id crtica ne postaje odabir', () {
    expect(isUsableEvidenceEntityId('—'), isFalse);
    expect(isUsableEvidenceEntityId(''), isFalse);
    expect(
      evidenceActiveEntitySelection(
        fieldKey: 'performedByEmployeeId',
        rawValue: '—',
        fieldValues: const {},
      ),
      isNull,
    );
    expect(
      evidenceActiveEntitySelection(
        fieldKey: 'performedByEmployeeId',
        rawValue: 'wf-1',
        fieldValues: const {'performedByNameSnapshot': '—'},
      ),
      isNull,
    );
    final sel = evidenceActiveEntitySelection(
      fieldKey: 'performedByEmployeeId',
      rawValue: 'wf-1',
      fieldValues: const {'performedByNameSnapshot': 'Mirza Nuhanovic'},
    );
    expect(sel?.displayLabel, 'Mirza Nuhanovic');
    expect(sel?.entityId, 'wf-1');
  });

  test('HOTFIX-21 5S zona Radni sto se mapira i bez snapshot imena', () {
    final sel = evidenceActiveEntitySelection(
      fieldKey: 'workplaceZoneId',
      rawValue: '__zone_work_table__',
      fieldValues: const {},
    );
    expect(sel?.entityId, '__zone_work_table__');
    expect(sel?.displayLabel, 'Radni sto');
    expect(
      evidenceActiveEntitySelection(
        fieldKey: 'workplaceZoneId',
        rawValue: '__zone_floor__',
        fieldValues: const {'workplaceZoneNameSnapshot': 'Pod oko radnog mjesta'},
      )?.displayLabel,
      'Pod oko radnog mjesta',
    );
  });
}
