import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../profile_driven_structured_runtime/models/structured_profile_session.dart';
import '../../profile_driven_structured_runtime/models/structured_repeatable_row.dart';

/// Mapiranje tableKey → Callable payload key (isti algoritam kao backend M1-F2).
String catalogEvidenceTableKeyToPayloadKey(String tableKey) {
  return tableKey.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (match) => match.group(1)!.toUpperCase(),
  );
}

Map<String, dynamic> buildCatalogEvidenceUpdatePayload({
  required ProductionStationProfileCatalogEntry profile,
  required StructuredProfileSessionState state,
}) {
  final payload = <String, dynamic>{
    'fieldValues': Map<String, dynamic>.from(state.fieldValues),
  };
  for (final table in profile.repeatableTableDefinitions) {
    final payloadKey = catalogEvidenceTableKeyToPayloadKey(table.key);
    payload[payloadKey] = state
        .rowsFor(table.key)
        .map((row) => row.toPayload())
        .toList(growable: false);
  }
  return payload;
}

StructuredProfileSessionState hydrateCatalogEvidenceState({
  required Map<String, dynamic>? fieldValues,
  Map<String, List<Map<String, dynamic>>>? structuredTables,
  required ProductionStationProfileCatalogEntry profile,
}) {
  final state = StructuredProfileSessionState(
    fieldValues: Map<String, dynamic>.from(fieldValues ?? const {}),
  );
  if (structuredTables == null || structuredTables.isEmpty) {
    return state;
  }
  for (final table in profile.repeatableTableDefinitions) {
    final rowsRaw = structuredTables[table.key];
    if (rowsRaw == null) continue;
    state.setRows(
      table.key,
      rowsRaw
          .map((row) => StructuredRepeatableRow.fromPayload(row))
          .toList(growable: false),
    );
  }
  return state;
}
