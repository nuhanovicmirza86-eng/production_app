import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../profile_driven_structured_runtime/models/structured_profile_session.dart';
import '../utils/catalog_evidence_table_payload.dart';
import '../utils/cleaning_handoff_persistence.dart';

/// M1-F3 — sesija za catalog evidence profile (flat / structured_lite).
class CatalogEvidenceSessionService {
  CatalogEvidenceSessionService({
    ProductionStationWorkSessionCallableService? sessionCallables,
  }) : _sessionCallables =
           sessionCallables ?? ProductionStationWorkSessionCallableService();

  final ProductionStationWorkSessionCallableService _sessionCallables;

  Future<ProductionStationWorkSession> startSession({
    required String companyId,
    int? stationSlot,
    String? evidenceConfigId,
  }) async {
    final result = await startSessionDetailed(
      companyId: companyId,
      stationSlot: stationSlot,
      evidenceConfigId: evidenceConfigId,
    );
    return result.session;
  }

  Future<StartProductionEvidenceWorkSessionResult> startSessionDetailed({
    required String companyId,
    int? stationSlot,
    String? evidenceConfigId,
  }) async {
    final eid = evidenceConfigId?.trim();
    if (eid != null && eid.isNotEmpty) {
      return _sessionCallables.startProductionEvidenceWorkSessionDetailed(
        companyId: companyId,
        evidenceConfigId: eid,
      );
    }
    if (stationSlot == null || stationSlot < 1) {
      throw ArgumentError('stationSlot ili evidenceConfigId je obavezan.');
    }
    final session = await _sessionCallables.startProductionStationWorkSession(
      companyId: companyId,
      stationSlot: stationSlot,
    );
    return StartProductionEvidenceWorkSessionResult(session: session);
  }

  Future<ActiveStructuredSessionResult?> getActiveEvidenceSession({
    required String companyId,
    required String evidenceConfigId,
  }) {
    return _sessionCallables.getActiveProductionEvidenceWorkSession(
      companyId: companyId,
      evidenceConfigId: evidenceConfigId,
    );
  }

  Future<List<ProductionStationWorkSession>> listClosedEvidenceSessions({
    required String companyId,
    required String evidenceConfigId,
    int limit = 25,
  }) {
    return _sessionCallables.listClosedProductionEvidenceWorkSessions(
      companyId: companyId,
      evidenceConfigId: evidenceConfigId,
      limit: limit,
    );
  }

  Future<StructuredProfileSessionState?> loadActiveState({
    required String companyId,
    int? stationSlot,
    String? evidenceConfigId,
    required ProductionStationProfileCatalogEntry profile,
  }) async {
    final eid = evidenceConfigId?.trim();
    if (eid != null && eid.isNotEmpty) {
      final active = await _sessionCallables.getActiveProductionEvidenceWorkSession(
        companyId: companyId,
        evidenceConfigId: eid,
      );
      if (active == null) return null;
      return hydrateCatalogEvidenceState(
        fieldValues: active.session.fieldValues,
        structuredTables: active.structuredTables,
        profile: profile,
      );
    }
    if (stationSlot == null || stationSlot < 1) {
      return null;
    }
    final active = await _sessionCallables.getActiveStructuredSession(
      companyId: companyId,
      stationSlot: stationSlot,
    );
    if (active == null) return null;
    return hydrateCatalogEvidenceState(
      fieldValues: active.session.fieldValues,
      structuredTables: active.structuredTables,
      profile: profile,
    );
  }

  Future<ProductionStationWorkSession> saveState({
    required String companyId,
    required String sessionId,
    required ProductionStationProfileCatalogEntry profile,
    required StructuredProfileSessionState state,
  }) {
    final payload = buildCatalogEvidenceUpdatePayload(
      profile: profile,
      state: state,
    );
    return _sessionCallables.updateCatalogEvidenceSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: Map<String, dynamic>.from(
        payload['fieldValues'] as Map<String, dynamic>? ?? const {},
      ),
      tablePayload: Map<String, dynamic>.from(payload)
        ..remove('fieldValues'),
    );
  }

  Future<ProductionStationWorkSession> finishState({
    required String companyId,
    required String sessionId,
    required ProductionStationProfileCatalogEntry profile,
    required StructuredProfileSessionState state,
    String? containmentAction,
  }) {
    final payload = buildCatalogEvidenceUpdatePayload(
      profile: profile,
      state: state,
    );
    return _sessionCallables.finishCatalogEvidenceSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: Map<String, dynamic>.from(
        payload['fieldValues'] as Map<String, dynamic>? ?? const {},
      ),
      tablePayload: Map<String, dynamic>.from(payload)
        ..remove('fieldValues'),
      containmentAction: containmentAction,
    );
  }

  Future<ProductionStationWorkSession> finishFlatState({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> fieldValues,
    String? containmentAction,
  }) {
    return _sessionCallables.finishProductionStationWorkSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: fieldValuesWithoutClientSnapshotKeys(fieldValues),
      containmentAction: containmentAction,
    );
  }

  Future<ProductionStationWorkSession> saveFlatState({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> fieldValues,
  }) {
    return _sessionCallables.setProfileFieldValues(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: fieldValuesWithoutClientSnapshotKeys(fieldValues),
    );
  }
}
