import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../models/structured_profile_session.dart';
import '../models/structured_repeatable_row.dart';

/// M1-E3 — structured_lite sesija (`final_control`, subkolekcija controlled_items).
class FinalControlProfileSessionService {
  FinalControlProfileSessionService({
    ProductionStationWorkSessionCallableService? sessionCallables,
  }) : _sessionCallables =
           sessionCallables ?? ProductionStationWorkSessionCallableService();

  final ProductionStationWorkSessionCallableService _sessionCallables;

  static const _tableKeys = ['controlled_items'];

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
    return _hydrateStateFromSession(
      session: active.session,
      structuredTables: active.structuredTables,
    );
  }

  StructuredProfileSessionState _hydrateStateFromSession({
    required ProductionStationWorkSession session,
    Map<String, List<Map<String, dynamic>>>? structuredTables,
  }) {
    final state = StructuredProfileSessionState(
      fieldValues: Map<String, dynamic>.from(session.fieldValues ?? const {}),
    );
    if (structuredTables == null || structuredTables.isEmpty) {
      return state;
    }
    for (final tableKey in _tableKeys) {
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

  Future<ProductionStationWorkSession> saveState({
    required String companyId,
    required String sessionId,
    required StructuredProfileSessionState state,
  }) {
    final payload = state.buildUpdatePayload(tableKeys: _tableKeys);
    return _sessionCallables.updateFinalControlProfileSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: Map<String, dynamic>.from(
        payload['fieldValues'] as Map<String, dynamic>? ?? const {},
      ),
      controlledItems: _asMapList(payload['controlledItems']),
    );
  }

  Future<ProductionStationWorkSession> finishState({
    required String companyId,
    required String sessionId,
    required StructuredProfileSessionState state,
  }) {
    final payload = state.buildUpdatePayload(tableKeys: _tableKeys);
    return _sessionCallables.finishFinalControlProfileSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: Map<String, dynamic>.from(
        payload['fieldValues'] as Map<String, dynamic>? ?? const {},
      ),
      controlledItems: _asMapList(payload['controlledItems']),
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
