import 'workspace_5s_cleaning_fields.dart';

/// M1-I15-D-HOTFIX-19 — Brza lista / Proširena lista za 5S i čišćenje mašine.
const String cleaningChecklistModeQuick = 'quick';
const String cleaningChecklistModeExtended = 'extended';

const String cleaningChecklistModeQuickLabel = 'Brza lista';
const String cleaningChecklistModeExtendedLabel = 'Proširena lista';

bool profileSupportsCleaningChecklistMode(String profileKey) {
  final key = profileKey.trim();
  return key == 'workspace_5s_cleaning' || key == 'line_clearance';
}

String defaultCleaningChecklistMode(String profileKey) {
  if (profileKey.trim() == 'workspace_5s_cleaning') {
    return cleaningChecklistModeQuick;
  }
  if (profileKey.trim() == 'line_clearance') {
    return cleaningChecklistModeExtended;
  }
  return cleaningChecklistModeExtended;
}

String normalizeCleaningChecklistMode(String? raw, String profileKey) {
  final v = (raw ?? '').trim().toLowerCase();
  if (v == cleaningChecklistModeQuick || v == cleaningChecklistModeExtended) {
    return v;
  }
  return defaultCleaningChecklistMode(profileKey);
}

String cleaningChecklistModeLabel(String mode) {
  return mode == cleaningChecklistModeQuick
      ? cleaningChecklistModeQuickLabel
      : cleaningChecklistModeExtendedLabel;
}

const List<String> cleaningQuickStepFieldKeys = [
  'quickCleanSurface',
  'quickCleanWaste',
  'quickCleanAisles',
];

const Map<String, String> cleaningQuickStepFieldLabels = {
  'quickCleanSurface': 'Radna površina očišćena',
  'quickCleanWaste': 'Otpad uklonjen',
  'quickCleanAisles': 'Prolazi slobodni',
};

const Set<String> fiveSExtendedOnlyFieldKeys = {
  'checkType',
  ...workspace5sChecklistFieldKeys,
  'deviationDescription',
};

const Set<String> lineClearanceExtendedOnlyFieldKeys = {
  'productionOrderId',
  'productionOrderCode',
  'clearanceType',
  'lineName',
  'previousProductId',
  'nextProductId',
  'nextProductNameSnapshot',
  'clearanceStartedAt',
  'clearanceFinishedAt',
  'checklistConfirmed',
};

const Set<String> cleaningQuickOnlyFieldKeys = {
  ...cleaningQuickStepFieldKeys,
};

bool isCleaningChecklistFieldVisible({
  required String profileKey,
  required String fieldKey,
  required String mode,
  required String? outcome,
}) {
  if (!profileSupportsCleaningChecklistMode(profileKey)) return true;
  final key = fieldKey.trim();
  final isQuick = mode == cleaningChecklistModeQuick;
  final profile = profileKey.trim();

  if (key == 'operatorComment' && isQuick) {
    return (outcome ?? '').trim() == 'does_not_satisfy';
  }

  if (isQuick) {
    if (profile == 'workspace_5s_cleaning' &&
        fiveSExtendedOnlyFieldKeys.contains(key)) {
      return false;
    }
    if (profile == 'line_clearance' &&
        lineClearanceExtendedOnlyFieldKeys.contains(key)) {
      return false;
    }
    return true;
  }

  if (cleaningQuickOnlyFieldKeys.contains(key)) return false;
  if (profile == 'line_clearance' && key == 'outcome') return false;
  return true;
}

Set<String> hiddenCleaningChecklistFieldKeys({
  required String profileKey,
  required String mode,
  required String? outcome,
  required Iterable<String> fieldKeys,
}) {
  if (!profileSupportsCleaningChecklistMode(profileKey)) {
    return const {};
  }
  return {
    for (final key in fieldKeys)
      if (!isCleaningChecklistFieldVisible(
        profileKey: profileKey,
        fieldKey: key,
        mode: mode,
        outcome: outcome,
      ))
        key,
  };
}

String? _enumOrStored({
  required String key,
  required Map<String, String?> enumSelections,
  required Map<String, dynamic> fieldValues,
}) {
  final fromEnum = (enumSelections[key] ?? '').trim();
  if (fromEnum.isNotEmpty) return fromEnum;
  final stored = (fieldValues[key] ?? '').toString().trim();
  return stored.isEmpty ? null : stored;
}

String? cleaningQuickFinishValidationMessage({
  required Map<String, String?> enumSelections,
  required Map<String, dynamic> fieldValues,
}) {
  for (final key in cleaningQuickStepFieldKeys) {
    final value = _enumOrStored(
      key: key,
      enumSelections: enumSelections,
      fieldValues: fieldValues,
    );
    if (value != workspace5sStatusOk &&
        value != workspace5sStatusNotOk &&
        value != workspace5sStatusNa) {
      final label = cleaningQuickStepFieldLabels[key] ?? key;
      return 'Odaberite ocjenu za «$label»: U redu, Nije u redu ili Nije primjenjivo.';
    }
  }
  final outcome = _enumOrStored(
    key: 'outcome',
    enumSelections: enumSelections,
    fieldValues: fieldValues,
  );
  if (outcome != 'satisfies' && outcome != 'does_not_satisfy') {
    return 'Odaberite ishod: Zadovoljava ili Ne zadovoljava.';
  }
  if (outcome == 'does_not_satisfy' &&
      (fieldValues['operatorComment'] ?? '').toString().trim().isEmpty) {
    return 'Unesite komentar jer ishod nije zadovoljan.';
  }
  return null;
}

String? cleaningModeFinishValidationMessage({
  required String profileKey,
  required String mode,
  required Map<String, String?> enumSelections,
  required Map<String, dynamic> fieldValues,
  String? workplaceZoneId,
  String? workCenterId,
  String? machineId,
}) {
  if (!profileSupportsCleaningChecklistMode(profileKey)) return null;

  final shift = _enumOrStored(
    key: 'shiftKey',
    enumSelections: enumSelections,
    fieldValues: fieldValues,
  );
  if (shift == null || shift.isEmpty) {
    return 'Odaberite smjenu prije završavanja evidencije.';
  }

  if (mode != cleaningChecklistModeQuick) {
    if (profileKey.trim() == 'workspace_5s_cleaning') {
      return workspace5sFinishValidationMessage(
        enumSelections: enumSelections,
        fieldValues: fieldValues,
        workplaceZoneId: workplaceZoneId,
      );
    }
    return null;
  }

  if (profileKey.trim() == 'workspace_5s_cleaning') {
    final zoneId = (workplaceZoneId ?? '').trim().isNotEmpty
        ? workplaceZoneId!.trim()
        : (fieldValues['workplaceZoneId'] ?? '').toString().trim();
    if (zoneId.isEmpty) {
      return 'Odaberite zonu / radno mjesto prije završavanja evidencije.';
    }
    if (zoneId == workspace5sZoneOtherId) {
      final other =
          (fieldValues['workplaceZoneOther'] ?? '').toString().trim();
      if (other.isEmpty) {
        return 'Unesite naziv zone jer odabir Drugo nije u šifrarniku.';
      }
    }
  } else if (profileKey.trim() == 'line_clearance') {
    final center = (workCenterId ?? '').trim().isNotEmpty
        ? workCenterId!.trim()
        : (fieldValues['workCenterId'] ?? '').toString().trim();
    final machine = (machineId ?? '').trim().isNotEmpty
        ? machineId!.trim()
        : (fieldValues['machineId'] ?? '').toString().trim();
    if (center.isEmpty && machine.isEmpty) {
      return 'Odaberite radni centar / liniju ili mašinu prije završavanja evidencije.';
    }
  }

  return cleaningQuickFinishValidationMessage(
    enumSelections: enumSelections,
    fieldValues: fieldValues,
  );
}
