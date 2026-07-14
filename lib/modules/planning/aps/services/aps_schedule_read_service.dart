import '../models/aps_gantt_resource_lane.dart';
import '../models/aps_gantt_view_data.dart';
import '../models/aps_scenario_view.dart';
import '../models/aps_schedule_operation_view.dart';
import 'aps_p0_debug_service.dart';

/// Greška pri Callable čitanju APS rasporeda (P3 read-only).
class ApsScheduleReadException implements Exception {
  ApsScheduleReadException(this.message, {this.callableName, this.errorCode});

  final String message;
  final String? callableName;
  final String? errorCode;

  @override
  String toString() => message;
}

/// P3 read servis — samo [listApsScenarios] i [listApsScheduleOperations]
/// (+ opcionalno [listApsDemands] za productCode / demandName).
class ApsScheduleReadService {
  ApsScheduleReadService({ApsP0DebugService? debugService})
    : _debug = debugService ?? ApsP0DebugService();

  final ApsP0DebugService _debug;

  Map<String, dynamic> _tenantPayload({
    required String companyId,
    required String plantKey,
  }) {
    return {
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
    };
  }

  Future<List<ApsScenarioView>> fetchScenarios({
    required String companyId,
    required String plantKey,
  }) async {
    final result = await _debug.listApsScenarios(
      _tenantPayload(companyId: companyId, plantKey: plantKey),
    );
    _throwIfFailed(result, 'Neuspjelo učitavanje scenarija.');
    final items = result.data?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => ApsScenarioView.fromMap(Map<String, dynamic>.from(m)))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  Future<ApsGanttViewData> fetchGanttForScenario({
    required String companyId,
    required String plantKey,
    required ApsScenarioView scenario,
  }) async {
    final demandMeta = await _loadDemandMeta(
      companyId: companyId,
      plantKey: plantKey,
    );

    final opsResult = await _debug.listApsScheduleOperations({
      ..._tenantPayload(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenario.id,
    });
    _throwIfFailed(opsResult, 'Neuspjelo učitavanje operacija rasporeda.');

    final rawItems = opsResult.data?['items'];
    final operations = <ApsScheduleOperationView>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final demandId = (map['demandId'] ?? '').toString().trim();
        final meta = demandMeta[demandId];
        operations.add(
          ApsScheduleOperationView.fromMap(
            map,
            demandName: meta?.$1,
            productCode: meta?.$2,
          ),
        );
      }
    }

    final lanes = _groupByResource(operations);
    return ApsGanttViewData(
      scenario: scenario,
      lanes: lanes,
      operations: operations,
    );
  }

  Future<Map<String, (String?, String?)>> _loadDemandMeta({
    required String companyId,
    required String plantKey,
  }) async {
    final result = await _debug.listApsDemands(
      _tenantPayload(companyId: companyId, plantKey: plantKey),
    );
    if (!result.success) return const {};
    final items = result.data?['items'];
    if (items is! List) return const {};
    final out = <String, (String?, String?)>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final id = (map['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final name = (map['demandName'] ?? '').toString().trim();
      final product = (map['productCode'] ?? '').toString().trim();
      out[id] = (
        name.isEmpty ? null : name,
        product.isEmpty ? null : product,
      );
    }
    return out;
  }

  List<ApsGanttResourceLane> _groupByResource(
    List<ApsScheduleOperationView> operations,
  ) {
    final byResource = <String, List<ApsScheduleOperationView>>{};
    for (final op in operations) {
      final key = op.resourceCode.trim().isNotEmpty
          ? op.resourceCode.trim()
          : '—';
      byResource.putIfAbsent(key, () => []).add(op);
    }
    final keys = byResource.keys.toList()..sort();
    return keys
        .map(
          (code) => ApsGanttResourceLane(
            resourceCode: code,
            operations: byResource[code]!,
          ),
        )
        .toList();
  }

  void _throwIfFailed(ApsP0CallResult result, String fallbackMessage) {
    if (result.success) return;
    final msg = (result.errorMessage ?? fallbackMessage).trim();
    throw ApsScheduleReadException(
      msg.isNotEmpty ? msg : fallbackMessage,
      callableName: result.callableName,
      errorCode: result.errorCode,
    );
  }
}
