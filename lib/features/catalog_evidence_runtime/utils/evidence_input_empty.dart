import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import 'workspace_5s_cleaning_fields.dart';

/// M1-I15-D-HOTFIX-18 — prazno polje u aktivnoj formi je stvarno prazno.
/// Crtica „–” ostaje samo u read-only detalju / historiji.
bool isEvidenceFormPlaceholder(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return true;
  return t == '—' || t == '–' || t == '-';
}

String sanitizeEvidenceFormInput(String? raw) {
  return isEvidenceFormPlaceholder(raw) ? '' : (raw ?? '').trim();
}

String evidenceSearchHint() => 'Pretražite...';

String evidenceSelectHint() => 'Odaberite...';

String evidenceTextHint() => 'Unesite naziv...';

String? personNameSnapshotKeyForField(String fieldKey) {
  switch (fieldKey.trim()) {
    case 'performedByEmployeeId':
      return 'performedByNameSnapshot';
    case 'verifiedByEmployeeId':
      return 'verifiedByNameSnapshot';
    case 'controllerEmployeeId':
      return 'controllerNameSnapshot';
    case 'inspectorEmployeeId':
      return 'inspectorNameSnapshot';
    case 'productionOperatorEmployeeId':
      return 'productionOperatorNameSnapshot';
    case 'packagingOperatorEmployeeId':
      return 'packagingOperatorNameSnapshot';
    case 'workplaceZoneId':
      return 'workplaceZoneNameSnapshot';
    case 'machineId':
      return 'machineNameSnapshot';
    case 'workbenchId':
      return 'workbenchNameSnapshot';
    case 'workCenterId':
      return 'workCenterNameSnapshot';
    case 'previousProductId':
      return 'previousProductNameSnapshot';
    case 'nextProductId':
      return 'nextProductNameSnapshot';
    default:
      return null;
  }
}

bool isUsableEvidenceEntityId(String? raw) {
  final id = (raw ?? '').trim();
  return id.isNotEmpty && !isEvidenceFormPlaceholder(id);
}

String? usableEvidenceDisplayLabel(String? raw, {String? entityId}) {
  final label = sanitizeEvidenceFormInput(raw);
  if (label.isEmpty) return null;
  final id = (entityId ?? '').trim();
  if (id.isNotEmpty && label == id) {
    if (StructuredEntitySearchResult.productionOrderDisplayLabel({
          'productionOrderCode': id,
        }) ==
        '—') {
      return null;
    }
  }
  return label;
}

/// Ljudska oznaka za aktivni entity input — nikad crtica, nikad sirovi ID.
String? evidenceActiveEntityLabel({
  required String fieldKey,
  required String id,
  required Map<String, dynamic> fieldValues,
  Map<String, dynamic> existingRaw = const {},
  String? existingDisplayLabel,
}) {
  if (!isUsableEvidenceEntityId(id)) return null;

  if (fieldKey == 'productId') {
    final composed = StructuredEntitySearchResult.productDisplayLabel({
      'productCode': (fieldValues['productCode'] ??
              existingRaw['productCode'] ??
              '')
          .toString(),
      'productName': (fieldValues['productNameSnapshot'] ??
              existingRaw['productName'] ??
              existingRaw['displayName'] ??
              '')
          .toString(),
    });
    return usableEvidenceDisplayLabel(composed, entityId: id);
  }
  if (fieldKey == 'materialId') {
    final composed = StructuredEntitySearchResult.productDisplayLabel({
      'productCode': (fieldValues['materialCodeSnapshot'] ??
              existingRaw['productCode'] ??
              '')
          .toString(),
      'productName': (fieldValues['materialNameSnapshot'] ??
              existingRaw['productName'] ??
              existingRaw['displayName'] ??
              '')
          .toString(),
    });
    return usableEvidenceDisplayLabel(composed, entityId: id);
  }
  if (fieldKey == 'productionOrderId') {
    final composed = StructuredEntitySearchResult.productionOrderDisplayLabel({
      'productionOrderCode': (fieldValues['productionOrderCode'] ??
              existingRaw['productionOrderCode'] ??
              existingRaw['orderCode'] ??
              existingRaw['displayCode'] ??
              '')
          .toString(),
    });
    return usableEvidenceDisplayLabel(composed, entityId: id);
  }
  if (fieldKey == 'machineId' || fieldKey == 'workbenchId') {
    final codeKey =
        fieldKey == 'machineId' ? 'machineCodeSnapshot' : 'workbenchCodeSnapshot';
    final nameKey =
        fieldKey == 'machineId' ? 'machineNameSnapshot' : 'workbenchNameSnapshot';
    final code = (fieldValues[codeKey] ?? '').toString().trim();
    final name = (fieldValues[nameKey] ?? '').toString().trim();
    if (code.isNotEmpty && name.isNotEmpty) {
      return '$code — $name';
    }
    return usableEvidenceDisplayLabel(
      name.isNotEmpty ? name : code,
      entityId: id,
    );
  }

  final snapKey = personNameSnapshotKeyForField(fieldKey);
  if (snapKey != null) {
    final name = (fieldValues[snapKey] ?? '').toString().trim();
    final fromSnap = usableEvidenceDisplayLabel(name, entityId: id);
    if (fromSnap != null) return fromSnap;
  }

  if (fieldKey == 'workplaceZoneId') {
    for (final zone in workspace5sPresetZoneChoices) {
      if (zone.id == id) return zone.displayLabel;
    }
    if (id == workspace5sZoneOtherId) {
      final other = usableEvidenceDisplayLabel(
        fieldValues['workplaceZoneOther']?.toString(),
        entityId: id,
      );
      if (other != null) return other;
      return workspace5sZoneOtherChoice.displayLabel;
    }
  }

  return usableEvidenceDisplayLabel(existingDisplayLabel, entityId: id);
}

StructuredEntitySelection? evidenceActiveEntitySelection({
  required String fieldKey,
  required String? rawValue,
  required Map<String, dynamic> fieldValues,
  StructuredEntitySelection? existing,
}) {
  if (!isUsableEvidenceEntityId(rawValue)) return null;
  final id = rawValue!.trim();
  final existingRaw = (existing != null && existing.entityId == id)
      ? existing.raw
      : const <String, dynamic>{};
  final label = evidenceActiveEntityLabel(
    fieldKey: fieldKey,
    id: id,
    fieldValues: fieldValues,
    existingRaw: existingRaw,
    existingDisplayLabel:
        existing != null && existing.entityId == id ? existing.displayLabel : null,
  );
  if (label == null) return null;
  return StructuredEntitySelection(
    fieldKey: fieldKey,
    entityId: id,
    displayLabel: label,
    raw: existingRaw.isNotEmpty ? existingRaw : <String, dynamic>{'id': id},
  );
}
