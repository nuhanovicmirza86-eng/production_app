import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../models/structured_profile_session.dart';
import '../models/structured_repeatable_row.dart';

/// Structured sesija — update payload + hidratacija tablica iz Callabla.
class StructuredProfileSessionService {
  StructuredProfileSessionService({
    ProductionStationWorkSessionCallableService? sessionCallables,
  }) : _sessionCallables =
           sessionCallables ?? ProductionStationWorkSessionCallableService();

  final ProductionStationWorkSessionCallableService _sessionCallables;

  Future<ProductionStationWorkSession> startSession({
    required String companyId,
    required int stationSlot,
  }) {
    return _sessionCallables.startProductionStationWorkSession(
      companyId: companyId,
      stationSlot: stationSlot,
    );
  }

  Future<StructuredProfileSessionState?> loadActiveState({
    required String companyId,
    required int stationSlot,
  }) async {
    final active = await _sessionCallables.getActiveStructuredSession(
      companyId: companyId,
      stationSlot: stationSlot,
    );
    if (active == null) return null;
    return hydrateStateFromSession(
      session: active.session,
      structuredTables: active.structuredTables,
    );
  }

  StructuredProfileSessionState hydrateStateFromSession({
    required ProductionStationWorkSession session,
    Map<String, List<Map<String, dynamic>>>? structuredTables,
  }) {
    final state = StructuredProfileSessionState(
      fieldValues: Map<String, dynamic>.from(session.fieldValues ?? const {}),
    );
    if (structuredTables == null || structuredTables.isEmpty) {
      return state;
    }
    for (final entry
        in StructuredProfileTablePayloadKeys.subcollectionToPayloadKey.entries) {
      final tableKey = entry.key;
      final rowsRaw = structuredTables[tableKey];
      if (rowsRaw == null) continue;
      state.setRows(
        tableKey,
        rowsRaw
            .map((row) => StructuredRepeatableRow.fromPayload(row))
            .toList(growable: false),
      );
    }
    return state;
  }

  Future<ProductionStationWorkSession> saveStructuredState({
    required String companyId,
    required String sessionId,
    required StructuredProfileSessionState state,
  }) {
    final payload = state.buildUpdatePayload();
    return _sessionCallables.updateStructuredProfileSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: Map<String, dynamic>.from(
        payload['fieldValues'] as Map<String, dynamic>? ?? const {},
      ),
      processedItems: _asMapList(payload['processedItems']),
      materialConsumptions: _asMapList(payload['materialConsumptions']),
      operatorWorkLogs: _asMapList(payload['operatorWorkLogs']),
      scrapItems: _asMapList(payload['scrapItems']),
    );
  }

  Future<ProductionStationWorkSession> finishStructuredSession({
    required String companyId,
    required String sessionId,
    StructuredProfileSessionState? state,
  }) {
    if (state == null) {
      return _sessionCallables.finishProductionStationWorkSession(
        companyId: companyId,
        sessionId: sessionId,
      );
    }
    final payload = state.buildUpdatePayload();
    return _sessionCallables.finishStructuredProfileSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: Map<String, dynamic>.from(
        payload['fieldValues'] as Map<String, dynamic>? ?? const {},
      ),
      processedItems: _asMapList(payload['processedItems']),
      materialConsumptions: _asMapList(payload['materialConsumptions']),
      operatorWorkLogs: _asMapList(payload['operatorWorkLogs']),
      scrapItems: _asMapList(payload['scrapItems']),
    );
  }

  List<Map<String, dynamic>> _asMapList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
