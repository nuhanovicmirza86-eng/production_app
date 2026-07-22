import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../models/profile_driven_evidence_session.dart';

const Set<String> profileEvidenceDetailHiddenFieldKeys = {
  'operatorId',
  'createdByUid',
  'operatorEmail',
  'operatorDisplayName',
  'createdAt',
  'updatedAt',
};

const Set<String> profileEvidenceDetailRedundantSnapshotKeys = {
  'workBathNameSnapshot',
  'chemicalNameSnapshot',
  'treatmentPointNameSnapshot',
};

const Map<String, String> _entityIdToSnapshotField = {
  'workBathId': 'workBathNameSnapshot',
  'chemicalId': 'chemicalNameSnapshot',
  'treatmentPointId': 'treatmentPointNameSnapshot',
  'productionOrderId': 'productionOrderCodeSnapshot',
};

bool profileEvidenceShouldHideDetailFieldKey(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return true;
  if (profileEvidenceDetailHiddenFieldKeys.contains(trimmed)) return true;
  if (trimmed.endsWith('Uid')) return true;
  return false;
}

bool profileEvidenceShouldShowMasterSnapshotField(
  ProductionStationProfileField field,
) {
  if (profileEvidenceShouldHideDetailFieldKey(field.key)) return false;
  if (field.isSessionScope) return false;
  if (field.key.endsWith('Id')) return false;
  if (profileEvidenceDetailRedundantSnapshotKeys.contains(field.key)) {
    return false;
  }
  return !field.isOperatorEditable;
}

String profileEvidenceDetailFieldLabel(ProductionStationProfileField field) {
  var label = field.label.trim();
  if (label.isEmpty) label = field.key;
  label = label.replaceAll(' (snapshot)', '');
  label = label.replaceAll('(snapshot)', '');
  label = label.replaceAll(' (ID)', '');
  label = label.replaceAll('(ID)', '');
  return label.trim();
}

bool profileEvidenceLooksLikeInternalDocumentId(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  if (text.contains('@') || text.contains(' ')) return false;
  if (RegExp(r'^\d{1,2}\.\d{1,2}\.\d{4}').hasMatch(text)) return false;
  if (RegExp(r'^[A-Z][A-Z0-9_]*[-_]').hasMatch(text)) return false;
  if (text.length >= 18 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(text)) {
    return true;
  }
  return false;
}

String? _snapshotValueForEntityField(
  String entityFieldKey,
  Map<String, dynamic> fieldValues,
) {
  final explicit = _entityIdToSnapshotField[entityFieldKey];
  if (explicit != null) {
    final value = formatFieldValue(fieldValues[explicit]);
    if (value != '—') return value;
  }

  if (!entityFieldKey.endsWith('Id')) return null;
  final base = entityFieldKey.substring(0, entityFieldKey.length - 2);
  for (final candidate in [
    '${base}NameSnapshot',
    '${base}DisplayNameSnapshot',
    '${base}CodeSnapshot',
    '${base}Code',
    '${base}Name',
  ]) {
    final value = formatFieldValue(fieldValues[candidate]);
    if (value != '—') return value;
  }
  return null;
}

String? _summaryValueForEntityField(
  String entityFieldKey,
  ProfileDrivenEvidenceSummaryFields summary,
) {
  switch (entityFieldKey) {
    case 'workBathId':
      return _nonEmpty(summary.workBathName);
    case 'chemicalId':
      return _nonEmpty(summary.chemicalName);
    case 'treatmentPointId':
      return _nonEmpty(summary.treatmentPointName);
    default:
      return null;
  }
}

String? _nonEmpty(String? value) {
  final text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}

String profileEvidenceDetailFieldDisplayValue({
  required ProductionStationProfileField field,
  required ProfileDrivenEvidenceSessionDetail session,
}) {
  final raw = session.fieldValues[field.key];

  if (field.isEntitySelect || field.isEntitySearchSelect) {
    final snapshot = _snapshotValueForEntityField(field.key, session.fieldValues);
    if (snapshot != null) return snapshot;
    final summary = _summaryValueForEntityField(field.key, session.summaryFields);
    if (summary != null) return summary;
    return '—';
  }

  if (field.type == 'datetime') {
    return formatEvidenceDateTime(_parseDateTime(raw));
  }

  if (field.type == 'enum') {
    final label = field.enumLabelFor(raw?.toString() ?? '');
    return label.trim().isEmpty ? '—' : label;
  }

  if (field.key == 'heavyMetalsPresent') {
    return formatHeavyMetalsLabel(raw?.toString());
  }

  final text = formatFieldValue(raw);
  if (text != '—' && profileEvidenceLooksLikeInternalDocumentId(text)) {
    return '—';
  }
  return text;
}

String profileEvidenceDetailSanitizedValue(dynamic raw) {
  if (raw == null) return '—';
  if (raw is DateTime) {
    return formatEvidenceDateTime(raw);
  }
  final parsed = _parseDateTime(raw);
  if (parsed != null && raw is String && raw.contains('T')) {
    return formatEvidenceDateTime(parsed);
  }
  final text = formatFieldValue(raw);
  if (text != '—' && profileEvidenceLooksLikeInternalDocumentId(text)) {
    return '—';
  }
  return text;
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();
  if (raw is Map) {
    final seconds = raw['seconds'] ?? raw['_seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim())?.toLocal();
  }
  return null;
}
