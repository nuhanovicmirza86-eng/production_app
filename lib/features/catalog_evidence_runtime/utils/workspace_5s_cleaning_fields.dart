import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';

const String workspace5sZoneOtherId = '__other__';

const String workspace5sStatusOk = 'ok';
const String workspace5sStatusNotOk = 'not_ok';
const String workspace5sStatusNa = 'na';

const List<String> workspace5sChecklistFieldKeys = [
  'fiveSSortConfirmed',
  'fiveSOrderConfirmed',
  'fiveSCleanConfirmed',
  'fiveSWasteConfirmed',
  'fiveSMarksConfirmed',
  'fiveSAislesConfirmed',
];

const Map<String, String> workspace5sChecklistFieldLabels = {
  'fiveSSortConfirmed': 'Sortiranje nepotrebnih stvari',
  'fiveSOrderConfirmed': 'Urednost alata',
  'fiveSCleanConfirmed': 'Čistoća poda / radne površine',
  'fiveSWasteConfirmed': 'Otpad uklonjen',
  'fiveSMarksConfirmed': 'Oznake i zone ispravne',
  'fiveSAislesConfirmed': 'Sigurnosni prolazi slobodni',
};

/// Šifrarnik 5S zona (nije radni centar proizvodnje).
const List<StructuredEntitySearchResult> workspace5sPresetZoneChoices = [
  StructuredEntitySearchResult(
    id: '__zone_work_table__',
    displayLabel: 'Radni sto',
    secondaryLabel: '5S zona',
    raw: {'id': '__zone_work_table__', 'displayName': 'Radni sto'},
  ),
  StructuredEntitySearchResult(
    id: '__zone_floor__',
    displayLabel: 'Pod oko radnog mjesta',
    secondaryLabel: '5S zona',
    raw: {'id': '__zone_floor__', 'displayName': 'Pod oko radnog mjesta'},
  ),
  StructuredEntitySearchResult(
    id: '__zone_tools__',
    displayLabel: 'Alat i pribor',
    secondaryLabel: '5S zona',
    raw: {'id': '__zone_tools__', 'displayName': 'Alat i pribor'},
  ),
  StructuredEntitySearchResult(
    id: '__zone_waste__',
    displayLabel: 'Zona odlaganja',
    secondaryLabel: '5S zona',
    raw: {'id': '__zone_waste__', 'displayName': 'Zona odlaganja'},
  ),
  StructuredEntitySearchResult(
    id: '__zone_marks__',
    displayLabel: 'Označene zone',
    secondaryLabel: '5S zona',
    raw: {'id': '__zone_marks__', 'displayName': 'Označene zone'},
  ),
  StructuredEntitySearchResult(
    id: '__zone_aisle__',
    displayLabel: 'Sigurnosni prolaz',
    secondaryLabel: '5S zona',
    raw: {'id': '__zone_aisle__', 'displayName': 'Sigurnosni prolaz'},
  ),
];

const StructuredEntitySearchResult workspace5sZoneOtherChoice =
    StructuredEntitySearchResult(
  id: workspace5sZoneOtherId,
  displayLabel: 'Drugo',
  secondaryLabel: 'Nije u šifrarniku',
  raw: {'id': workspace5sZoneOtherId, 'displayName': 'Drugo'},
);

bool workspace5sIsSyntheticZoneId(String id) {
  final trimmed = id.trim();
  if (trimmed == workspace5sZoneOtherId) return true;
  return workspace5sPresetZoneChoices.any((e) => e.id == trimmed);
}

bool workspace5sHasNotOkItem({
  required Map<String, String?> enumSelections,
  required Map<String, dynamic> fieldValues,
}) {
  for (final key in workspace5sChecklistFieldKeys) {
    final fromEnum = (enumSelections[key] ?? '').trim();
    final value = fromEnum.isNotEmpty
        ? fromEnum
        : (fieldValues[key] ?? '').toString().trim();
    if (value == workspace5sStatusNotOk) return true;
  }
  return false;
}

String? workspace5sFinishValidationMessage({
  required Map<String, String?> enumSelections,
  required Map<String, dynamic> fieldValues,
  required String? workplaceZoneId,
}) {
  final zoneId = (workplaceZoneId ?? '').trim().isNotEmpty
      ? workplaceZoneId!.trim()
      : (fieldValues['workplaceZoneId'] ?? '').toString().trim();
  if (zoneId.isEmpty) {
    return 'Odaberite zonu / radno mjesto prije završavanja evidencije.';
  }
  if (zoneId == workspace5sZoneOtherId) {
    final other = (fieldValues['workplaceZoneOther'] ?? '').toString().trim();
    if (other.isEmpty) {
      return 'Unesite naziv zone jer odabir Drugo nije u šifrarniku.';
    }
  }
  for (final key in workspace5sChecklistFieldKeys) {
    final fromEnum = (enumSelections[key] ?? '').trim();
    final value = fromEnum.isNotEmpty
        ? fromEnum
        : (fieldValues[key] ?? '').toString().trim();
    if (value != workspace5sStatusOk &&
        value != workspace5sStatusNotOk &&
        value != workspace5sStatusNa) {
      final label = workspace5sChecklistFieldLabels[key] ?? key;
      return 'Odaberite ocjenu za «$label»: U redu, Nije u redu ili Nije primjenjivo.';
    }
  }
  if (workspace5sHasNotOkItem(
        enumSelections: enumSelections,
        fieldValues: fieldValues,
      ) &&
      (fieldValues['deviationDescription'] ?? '').toString().trim().isEmpty) {
    return 'Unesite opis odstupanja / potrebnu korekciju jer je najmanje jedna stavka Nije u redu.';
  }
  return null;
}

bool _matchesQuery(String haystack, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return haystack.toLowerCase().contains(q);
}

List<StructuredEntitySearchResult> mergeWorkspace5sZoneChoices({
  required List<StructuredEntitySearchResult> plantWorkbenches,
  required String query,
}) {
  final seen = <String>{};
  final out = <StructuredEntitySearchResult>[];

  void add(StructuredEntitySearchResult item) {
    final id = item.id.trim();
    if (id.isEmpty || seen.contains(id)) return;
    if (item.displayLabel.trim().isEmpty || item.displayLabel.trim() == '—') {
      return;
    }
    if (!_matchesQuery(item.displayLabel, query) &&
        !_matchesQuery(item.secondaryLabel ?? '', query)) {
      return;
    }
    seen.add(id);
    out.add(item);
  }

  for (final item in plantWorkbenches) {
    add(item);
  }
  for (final item in workspace5sPresetZoneChoices) {
    add(item);
  }
  final otherId = workspace5sZoneOtherChoice.id.trim();
  if (otherId.isNotEmpty && !seen.contains(otherId)) {
    seen.add(otherId);
    out.add(workspace5sZoneOtherChoice);
  }
  return out;
}
