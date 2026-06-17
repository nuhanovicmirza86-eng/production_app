import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_cash_flow_scenario.dart';

class FinanceCashFlowScenarioService {
  FinanceCashFlowScenarioService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  static String _dateToCallable(DateTime d) => d.toUtc().toIso8601String();

  Future<List<FinanceCashFlowScenario>> listScenarios({
    required String companyId,
    String? status,
    String? scenarioType,
    String? plantKey,
    int limit = 100,
  }) async {
    final callable = _functions.httpsCallable('listFinanceCashFlowScenarios');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (scenarioType != null && scenarioType.trim().isNotEmpty)
        'scenarioType': scenarioType.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      'limit': limit,
    });
    return _parseScenarioList(response.data);
  }

  Future<FinanceCashFlowScenario> getScenario({
    required String companyId,
    required String scenarioId,
  }) async {
    final callable = _functions.httpsCallable('getFinanceCashFlowScenario');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'scenarioId': scenarioId.trim(),
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor getFinanceCashFlowScenario');
    }
    final map = Map<String, dynamic>.from(data);
    final scenarioRaw = map['scenario'];
    if (scenarioRaw is Map) {
      final scenario = Map<String, dynamic>.from(scenarioRaw);
      scenario['scenarioId'] ??= scenarioId;
      return FinanceCashFlowScenario.fromCallableMap(scenario);
    }
    map['scenarioId'] ??= scenarioId;
    return FinanceCashFlowScenario.fromCallableMap(map);
  }

  Future<FinanceCashFlowScenario> createScenario({
    required String companyId,
    required String name,
    required String scenarioType,
    String? description,
    String? plantKey,
    int? horizonDays,
    DateTime? periodFrom,
    DateTime? periodTo,
    String bucketType = 'day',
    Map<String, dynamic>? whatIfAssumptions,
    String? requestId,
  }) async {
    final callable = _functions.httpsCallable('createFinanceCashFlowScenario');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'name': name.trim(),
      'scenarioType': scenarioType.trim().toLowerCase(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      if (horizonDays != null) 'horizonDays': horizonDays,
      if (periodFrom != null) 'periodFrom': _dateToCallable(periodFrom),
      if (periodTo != null) 'periodTo': _dateToCallable(periodTo),
      'bucketType': bucketType.trim(),
      if (whatIfAssumptions != null) 'assumptions': whatIfAssumptions,
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
    return _parseScenarioResponse(response.data);
  }

  Future<FinanceCashFlowScenario> updateScenario({
    required String companyId,
    required String scenarioId,
    String? name,
    String? description,
    String? plantKey,
    Map<String, dynamic>? whatIfAssumptions,
    int? expectedRevision,
  }) async {
    final callable = _functions.httpsCallable('updateFinanceCashFlowScenario');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'scenarioId': scenarioId.trim(),
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description.trim(),
      if (plantKey != null) 'plantKey': plantKey.trim().isEmpty ? null : plantKey.trim(),
      if (whatIfAssumptions != null) 'assumptions': whatIfAssumptions,
      if (expectedRevision != null) 'revision': expectedRevision,
    });
    return _parseScenarioResponse(response.data);
  }

  Future<FinanceCashFlowScenario> calculateScenario({
    required String companyId,
    required String scenarioId,
  }) async {
    final callable =
        _functions.httpsCallable('calculateFinanceCashFlowScenario');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'scenarioId': scenarioId.trim(),
    });
    return _parseScenarioResponse(response.data);
  }

  Future<FinanceCashFlowScenario> approveScenario({
    required String companyId,
    required String scenarioId,
  }) async {
    final callable = _functions.httpsCallable('approveFinanceCashFlowScenario');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'scenarioId': scenarioId.trim(),
    });
    return _parseScenarioResponse(response.data);
  }

  Future<FinanceCashFlowScenario> archiveScenario({
    required String companyId,
    required String scenarioId,
  }) async {
    final callable = _functions.httpsCallable('archiveFinanceCashFlowScenario');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'scenarioId': scenarioId.trim(),
    });
    return _parseScenarioResponse(response.data);
  }

  List<FinanceCashFlowScenario> _parseScenarioList(dynamic data) {
    if (data is! Map) return const [];
    final raw = data['scenarios'];
    if (raw is! List) return const [];
    final out = <FinanceCashFlowScenario>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(FinanceCashFlowScenario.fromCallableMap(
          Map<String, dynamic>.from(item),
        ));
      }
    }
    return out;
  }

  FinanceCashFlowScenario _parseScenarioResponse(dynamic data) {
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor scenarija');
    }
    final map = Map<String, dynamic>.from(data);
    final scenarioRaw = map['scenario'];
    if (scenarioRaw is Map) {
      final scenario = Map<String, dynamic>.from(scenarioRaw);
      scenario['scenarioId'] ??= map['scenarioId'];
      return FinanceCashFlowScenario.fromCallableMap(scenario);
    }
    return FinanceCashFlowScenario.fromCallableMap(map);
  }
}
