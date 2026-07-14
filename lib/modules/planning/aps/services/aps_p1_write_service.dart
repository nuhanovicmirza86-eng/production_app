import '../models/aps_objective_profile_view.dart';
import '../models/aps_demand_view.dart';
import '../models/aps_capacity_warning_view.dart';
import '../models/aps_rough_capacity_result.dart';
import '../models/aps_scenario_item_view.dart';
import '../models/aps_scenario_view.dart';
import 'aps_p0_debug_service.dart';

/// Greška pri operativnom P1/P2 Callable pozivu (scenariji i potrebe).
class ApsP1WriteException implements Exception {
  ApsP1WriteException(this.message, {this.errorCode, this.callableName});

  final String message;
  final String? errorCode;
  final String? callableName;

  @override
  String toString() => message;
}

/// Rezultat generiranja početnog rasporeda (P2).
class ApsGenerateScheduleResult {
  const ApsGenerateScheduleResult({
    required this.operationCount,
    required this.scenarioStatus,
    this.scheduleRunId = '',
    this.warningCount = 0,
  });

  final int operationCount;
  final String scenarioStatus;
  final String scheduleRunId;
  final int warningCount;

  factory ApsGenerateScheduleResult.fromCallableData(Map<String, dynamic>? data) {
    final map = data ?? const {};
    return ApsGenerateScheduleResult(
      operationCount: (map['operationCount'] as num?)?.toInt() ?? 0,
      scenarioStatus: (map['scenarioStatus'] ?? '').toString().trim(),
      scheduleRunId: (map['scheduleRunId'] ?? '').toString().trim(),
      warningCount: (map['warningCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Operativni P1 servis — potražnje, scenariji, sastav scenarija, P2 generate.
///
/// Koristi iste Callable-e kao interni debug alat, ali s poslovnim exception tipom.
class ApsP1WriteService {
  ApsP1WriteService({ApsP0DebugService? debugService})
    : _debug = debugService ?? ApsP0DebugService();

  final ApsP0DebugService _debug;

  Map<String, dynamic> _tenant({
    required String companyId,
    required String plantKey,
  }) {
    return {
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
    };
  }

  Future<List<ApsDemandView>> fetchDemands({
    required String companyId,
    required String plantKey,
    bool activeOnly = true,
  }) async {
    final payload = {
      ..._tenant(companyId: companyId, plantKey: plantKey),
      if (activeOnly) 'isActive': true,
    };
    final result = await _debug.listApsDemands(payload);
    _throwIfFailed(result, 'Neuspjelo učitavanje potražnji.');
    return _parseDemandList(result.data?['items']);
  }

  Future<List<ApsScenarioView>> fetchScenarios({
    required String companyId,
    required String plantKey,
    bool activeOnly = true,
  }) async {
    final payload = {
      ..._tenant(companyId: companyId, plantKey: plantKey),
      if (activeOnly) 'isActive': true,
    };
    final result = await _debug.listApsScenarios(payload);
    _throwIfFailed(result, 'Neuspjelo učitavanje scenarija.');
    return _parseScenarioList(result.data?['items']);
  }

  Future<List<ApsScenarioItemView>> fetchScenarioItems({
    required String companyId,
    required String plantKey,
    required String scenarioId,
  }) async {
    final result = await _debug.listApsScenarioItems({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Neuspjelo učitavanje stavki scenarija.');
    final items = result.data?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => ApsScenarioItemView.fromMap(Map<String, dynamic>.from(m)))
        .where((i) => i.id.isNotEmpty)
        .toList();
  }

  Future<String> createDemand({
    required String companyId,
    required String plantKey,
    required String demandCode,
    required String demandName,
    required num quantity,
    required DateTime dueDate,
    num? estimatedMinutesPerUnit,
    String demandType = 'manual',
    String quantityUom = 'pcs',
  }) async {
    final result = await _debug.createApsDemand({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'demandCode': demandCode.trim(),
      'demandName': demandName.trim(),
      'demandType': demandType,
      'quantity': quantity,
      'quantityUom': quantityUom,
      'dueDate': dueDate.toUtc().toIso8601String(),
      'status': 'active',
      'isActive': true,
      if (estimatedMinutesPerUnit != null)
        'estimatedMinutesPerUnit': estimatedMinutesPerUnit,
    });
    _throwIfFailed(result, 'Kreiranje potražnje nije uspjelo.');
    final id = (result.data?['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      throw ApsP1WriteException(
        'Potražnja je kreirana, ali identifikator nije vraćen.',
        callableName: result.callableName,
      );
    }
    return id;
  }

  Future<List<ApsObjectiveProfileView>> fetchObjectiveProfiles({
    required String companyId,
    required String plantKey,
    bool activeOnly = true,
  }) async {
    final result = await _debug.listApsObjectiveProfiles({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      if (activeOnly) 'isActive': true,
    });
    _throwIfFailed(result, 'Neuspjelo učitavanje profila cilja optimizacije.');
    final items = result.data?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => ApsObjectiveProfileView.fromMap(Map<String, dynamic>.from(m)))
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  Future<String> createScenario({
    required String companyId,
    required String plantKey,
    required String scenarioCode,
    required String scenarioName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String objectiveProfileId,
  }) async {
    final result = await _debug.createApsScenario({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioCode': scenarioCode.trim(),
      'scenarioName': scenarioName.trim(),
      'periodStart': periodStart.toUtc().toIso8601String(),
      'periodEnd': periodEnd.toUtc().toIso8601String(),
      'objectiveProfileId': objectiveProfileId.trim(),
      'isActive': true,
    });
    _throwIfFailed(result, 'Kreiranje scenarija nije uspjelo.');
    final id = (result.data?['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      throw ApsP1WriteException(
        'Scenarij je kreiran, ali identifikator nije vraćen.',
        callableName: result.callableName,
      );
    }
    return id;
  }

  Future<void> updateScenarioObjectiveProfile({
    required String companyId,
    required String plantKey,
    required String scenarioId,
    required String objectiveProfileId,
  }) async {
    final result = await _debug.updateApsScenario({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'id': scenarioId.trim(),
      'objectiveProfileId': objectiveProfileId.trim(),
    });
    _throwIfFailed(result, 'Postavljanje cilja optimizacije nije uspjelo.');
  }

  Future<void> addDemandToScenario({
    required String companyId,
    required String plantKey,
    required String scenarioId,
    required String demandId,
  }) async {
    final result = await _debug.addDemandToApsScenario({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
      'demandId': demandId.trim(),
    });
    _throwIfFailed(result, 'Dodavanje potražnje u scenarij nije uspjelo.');
  }

  Future<void> removeDemandFromScenario({
    required String companyId,
    required String plantKey,
    required String scenarioId,
    required String demandId,
  }) async {
    final result = await _debug.removeDemandFromApsScenario({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
      'demandId': demandId.trim(),
    });
    _throwIfFailed(result, 'Uklanjanje potražnje iz scenarija nije uspjelo.');
  }

  Future<ApsGenerateScheduleResult> generateHeuristicSchedule({
    required String companyId,
    required String plantKey,
    required String scenarioId,
  }) async {
    final result = await _debug.generateApsHeuristicSchedule({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Generiranje rasporeda nije uspjelo.');
    return ApsGenerateScheduleResult.fromCallableData(result.data);
  }

  Future<ApsRoughCapacityResult> calculateRoughCapacity({
    required String companyId,
    required String plantKey,
    required String scenarioId,
  }) async {
    final result = await _debug.calculateApsRoughCapacity({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Rough capacity proračun nije uspio.');
    return ApsRoughCapacityResult.fromCallableData(result.data);
  }

  Future<List<ApsCapacityWarningView>> fetchCapacityWarnings({
    required String companyId,
    required String plantKey,
    required String scenarioId,
    String? snapshotId,
  }) async {
    final result = await _debug.listApsCapacityWarnings({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
      if (snapshotId != null && snapshotId.trim().isNotEmpty)
        'snapshotId': snapshotId.trim(),
    });
    _throwIfFailed(result, 'Neuspjelo učitavanje upozorenja kapaciteta.');
    final items = result.data?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => ApsCapacityWarningView.fromMap(Map<String, dynamic>.from(m)))
        .where((w) => w.id.isNotEmpty)
        .toList();
  }

  List<ApsDemandView> _parseDemandList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ApsDemandView.fromMap(Map<String, dynamic>.from(m)))
        .where((d) => d.id.isNotEmpty)
        .toList();
  }

  List<ApsScenarioView> _parseScenarioList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ApsScenarioView.fromMap(Map<String, dynamic>.from(m)))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  void _throwIfFailed(ApsP0CallResult result, String fallbackMessage) {
    if (result.success) return;
    final msg = (result.errorMessage ?? fallbackMessage).trim();
    throw ApsP1WriteException(
      msg.isNotEmpty ? msg : fallbackMessage,
      errorCode: result.errorCode,
      callableName: result.callableName,
    );
  }
}
