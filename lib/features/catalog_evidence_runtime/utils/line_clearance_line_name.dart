import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';

/// M1-I15-D-HOTFIX-23 — Naziv linije je ručni fallback samo bez radnog centra.
const String lineClearanceLineNameFieldKey = 'lineName';
const String lineClearanceWorkCenterFieldKey = 'workCenterId';

bool hasSelectedLineClearanceWorkCenter({
  String? workCenterId,
  Map<String, dynamic>? fieldValues,
}) {
  final fromArg = (workCenterId ?? '').trim();
  if (fromArg.isNotEmpty) return true;
  final stored =
      (fieldValues?[lineClearanceWorkCenterFieldKey] ?? '').toString().trim();
  return stored.isNotEmpty;
}

bool isLineClearanceLineNameFallbackVisible({
  String? workCenterId,
  Map<String, dynamic>? fieldValues,
}) {
  return !hasSelectedLineClearanceWorkCenter(
    workCenterId: workCenterId,
    fieldValues: fieldValues,
  );
}

/// Ljudski naziv linije iz šifrarnika (npr. Glavna linija), bez šifre i raw ID.
String lineClearanceLineNameFromWorkCenter({
  Map<String, dynamic>? raw,
  String? displayLabel,
}) {
  final fromRaw = (raw?['displayName'] ?? raw?['name'] ?? '').toString().trim();
  if (_isPresentableLineName(fromRaw)) return fromRaw;

  final label = (displayLabel ?? '').trim();
  const sep = ' — ';
  if (label.contains(sep)) {
    final name = label.split(sep).skip(1).join(sep).trim();
    if (_isPresentableLineName(name)) return name;
  }
  if (_isPresentableLineName(label)) return label;
  return '';
}

void applyLineClearanceLineNameFromWorkCenter({
  required Map<String, dynamic> fieldValues,
  StructuredEntitySelection? workCenter,
  void Function(String text)? setLineNameText,
}) {
  if (!hasSelectedLineClearanceWorkCenter(
    workCenterId: workCenter?.entityId,
    fieldValues: fieldValues,
  )) {
    return;
  }
  final existingSnapshot =
      (fieldValues['workCenterNameSnapshot'] ?? '').toString().trim();
  final resolved = lineClearanceLineNameFromWorkCenter(
    raw: workCenter?.raw,
    displayLabel: workCenter?.displayLabel,
  );
  final name = resolved.isNotEmpty ? resolved : existingSnapshot;
  if (name.isEmpty) return;
  fieldValues[lineClearanceLineNameFieldKey] = name;
  if (existingSnapshot.isEmpty) {
    fieldValues['workCenterNameSnapshot'] = name;
  }
  setLineNameText?.call(name);
}

bool _isPresentableLineName(String value) {
  final t = value.trim();
  if (t.isEmpty || t == '—' || t == '-') return false;
  if (RegExp(r'^PLANT_\d+$', caseSensitive: false).hasMatch(t)) return false;
  if (t.length >= 16 &&
      t.length <= 32 &&
      !t.contains('-') &&
      !t.contains('_') &&
      !t.contains(' ') &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(t)) {
    return false;
  }
  return true;
}
