import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import '../../profile_driven_structured_runtime/utils/structured_datetime_value.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import 'evidence_input_empty.dart';

/// M1-I15-D-HOTFIX-25 — operator unosi Smjenu i ostala zaglavlja; verifikator
/// ih samo vidi. Ne smiju nestati na Spremi / getActive / Završi.
const Set<String> lineClearanceHandoffFieldKeys = {
  'shiftKey',
  'clearanceType',
  'workCenterId',
  'machineId',
  'clearanceStartedAt',
  'clearanceFinishedAt',
  'checklistConfirmed',
  'performedByEmployeeId',
};

const Set<String> lineClearanceHandoffSnapshotKeys = {
  'workCenterNameSnapshot',
  'machineNameSnapshot',
  'lineName',
  'performedByNameSnapshot',
  'performedByRoleSnapshot',
};

const Set<String> workspace5sHandoffFieldKeys = {
  'shiftKey',
  'workplaceZoneId',
  'workplaceZoneOther',
  'performedByEmployeeId',
};

const Set<String> workspace5sHandoffSnapshotKeys = {
  'workplaceZoneNameSnapshot',
  'performedByNameSnapshot',
  'performedByRoleSnapshot',
};

Set<String> cleaningHandoffPersistKeys(String profileKey) {
  switch (profileKey.trim()) {
    case 'line_clearance':
      return {
        ...lineClearanceHandoffFieldKeys,
        ...lineClearanceHandoffSnapshotKeys,
      };
    case 'workspace_5s_cleaning':
      return {
        ...workspace5sHandoffFieldKeys,
        ...workspace5sHandoffSnapshotKeys,
      };
    default:
      return const {};
  }
}

bool _hasStoredHandoffValue(dynamic raw) {
  if (raw == null) return false;
  if (raw is bool) return true;
  if (raw is num) return true;
  return !isEvidenceFormPlaceholder(raw.toString());
}

Map<String, dynamic> snapshotCleaningHandoffFieldValues({
  required String profileKey,
  Map<String, dynamic>? fieldValues,
}) {
  final keys = cleaningHandoffPersistKeys(profileKey);
  if (keys.isEmpty) return const {};
  final source = fieldValues ?? const <String, dynamic>{};
  final out = <String, dynamic>{};
  for (final key in keys) {
    final value = source[key];
    if (_hasStoredHandoffValue(value)) {
      out[key] = value;
    }
  }
  return out;
}

void restoreCleaningHandoffFieldValues({
  required Map<String, dynamic> target,
  Map<String, dynamic>? preserved,
}) {
  if (preserved == null || preserved.isEmpty) return;
  preserved.forEach((key, value) {
    if (!_hasStoredHandoffValue(target[key]) && _hasStoredHandoffValue(value)) {
      target[key] = value;
    }
  });
}

void mergeCleaningHandoffFieldValues({
  required String profileKey,
  required Map<String, dynamic> target,
  Map<String, dynamic>? source,
}) {
  restoreCleaningHandoffFieldValues(
    target: target,
    preserved: snapshotCleaningHandoffFieldValues(
      profileKey: profileKey,
      fieldValues: source,
    ),
  );
}

bool isUsableCleaningHandoffEnumValue(
  String? raw, {
  required List<String> enumValues,
}) {
  final value = sanitizeEvidenceFormInput(raw);
  if (value.isEmpty) return false;
  if (enumValues.isEmpty) return true;
  return enumValues.contains(value);
}

/// Enum / datum / entitet iz kontrola — ne samo string/number.
void persistStructuredHeaderControlsToFieldValues({
  required Iterable<ProductionStationProfileField> fields,
  required Map<String, dynamic> fieldValues,
  required Map<String, String?> enumSelections,
  required Map<String, DateTime?> dateTimes,
  required Map<String, StructuredEntitySelection?> entitySelections,
}) {
  for (final field in fields) {
    if (field.type == 'enum') {
      final value = sanitizeEvidenceFormInput(enumSelections[field.key]);
      if (value.isEmpty) continue;
      fieldValues[field.key] = value;
      continue;
    }
    if (field.type == 'datetime') {
      final dt = dateTimes[field.key];
      if (dt == null) continue;
      fieldValues[field.key] = StructuredDateTimeValue.toPayload(dt);
      continue;
    }
    if (field.isEntitySelect || field.isEntitySearchSelect) {
      final selection = entitySelections[field.key];
      final id = (selection?.entityId ?? '').trim();
      if (id.isEmpty || !isUsableEvidenceEntityId(id)) continue;
      fieldValues[field.key] = id;
      final snapKey = personNameSnapshotKeyForField(field.key);
      final label = sanitizeEvidenceFormInput(selection?.displayLabel);
      if (snapKey != null && label.isNotEmpty) {
        fieldValues[snapKey] = label;
      }
    }
  }
}

void applyCleaningHandoffEnumsFromFieldValues({
  required Iterable<ProductionStationProfileField> fields,
  required Map<String, dynamic> fieldValues,
  required Map<String, String?> enumSelections,
}) {
  for (final field in fields) {
    if (field.type != 'enum') continue;
    final stored = sanitizeEvidenceFormInput(fieldValues[field.key]?.toString());
    if (!isUsableCleaningHandoffEnumValue(
      stored,
      enumValues: field.enumValues,
    )) {
      continue;
    }
    enumSelections[field.key] = stored;
  }
}

String? cleaningHandoffShiftLabel({
  required Map<String, dynamic> fieldValues,
  List<String> enumValues = const ['shift_1', 'shift_2', 'shift_3'],
  Map<String, String> enumLabels = const {
    'shift_1': '1. smjena',
    'shift_2': '2. smjena',
    'shift_3': '3. smjena',
  },
}) {
  final key = sanitizeEvidenceFormInput(fieldValues['shiftKey']?.toString());
  if (key.isEmpty) return null;
  if (enumValues.isNotEmpty && !enumValues.contains(key)) {
    return null;
  }
  final label = (enumLabels[key] ?? '').trim();
  return label.isEmpty ? null : label;
}

/// HOTFIX-26 — snapshot/audit ključevi nisu operator polja; ne šalju se u Callable.
bool isBackendOwnedEvidenceSnapshotFieldKey(String key) {
  final k = key.trim();
  if (k.isEmpty) return false;
  return k.endsWith('Snapshot');
}

Map<String, dynamic> fieldValuesWithoutClientSnapshotKeys(
  Map<String, dynamic> fieldValues,
) {
  return {
    for (final entry in fieldValues.entries)
      if (!isBackendOwnedEvidenceSnapshotFieldKey(entry.key))
        entry.key: entry.value,
  };
}
