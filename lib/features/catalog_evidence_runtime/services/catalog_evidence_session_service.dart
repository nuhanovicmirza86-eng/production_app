import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../../../modules/production/station_work/services/production_station_work_session_callable_service.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../profile_driven_structured_runtime/models/structured_profile_session.dart';
import '../utils/catalog_evidence_table_payload.dart';

/// M1-F3 — sesija za catalog evidence profile (flat / structured_lite).
class CatalogEvidenceSessionService {
  CatalogEvidenceSessionService({
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
    required ProductionStationProfileCatalogEntry profile,
  }) async {
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
    );
  }

  Future<ProductionStationWorkSession> finishFlatState({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> fieldValues,
  }) {
    return _sessionCallables.finishProductionStationWorkSession(
      companyId: companyId,
      sessionId: sessionId,
      fieldValues: fieldValues,
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
      fieldValues: fieldValues,
    );
  }
}
