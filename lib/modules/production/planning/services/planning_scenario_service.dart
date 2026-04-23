import 'package:cloud_functions/cloud_functions.dart';

import '../models/planning_scenario_record.dart';

/// F4.1 — scenariji planiranja (Callable, tanka rules).
class PlanningScenarioService {
  PlanningScenarioService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  static List<PlanningScenarioRecord> _parseList(dynamic data) {
    final raw = (data as Map?)?['scenarios'] as List? ?? const [];
    final out = <PlanningScenarioRecord>[];
    for (final e in raw) {
      if (e is! Map) {
        continue;
      }
      final m = Map<String, dynamic>.from(e);
      final id = (m['id'] ?? '').toString().trim();
      if (id.isEmpty) {
        continue;
      }
      out.add(PlanningScenarioRecord.fromMap(id, m));
    }
    return out;
  }

  Future<List<PlanningScenarioRecord>> listScenarios({
    required String companyId,
    required String plantKey,
  }) async {
    final c = _f.httpsCallable('listPlanningScenarios');
    final res = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
    });
    return _parseList(res.data);
  }

  Future<String> upsertScenario({
    required String companyId,
    required String plantKey,
    String? scenarioId,
    required String title,
    required String scenarioType,
    String basePlanId = '',
    String notes = '',
  }) async {
    final c = _f.httpsCallable('upsertPlanningScenario');
    final res = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      if (scenarioId != null && scenarioId.isNotEmpty) 'scenarioId': scenarioId,
      'title': title,
      'scenarioType': scenarioType,
      'basePlanId': basePlanId,
      'notes': notes,
    });
    final id = (res.data as Map?)?['scenarioId']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError('upsertPlanningScenario: nije vraćen scenarioId');
    }
    return id;
  }

  Future<void> deleteScenario({
    required String companyId,
    required String plantKey,
    required String scenarioId,
  }) async {
    final c = _f.httpsCallable('deletePlanningScenario');
    await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'scenarioId': scenarioId,
    });
  }
}
