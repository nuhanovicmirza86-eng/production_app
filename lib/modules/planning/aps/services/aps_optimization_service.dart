import '../models/aps_optimization_comparison_view.dart';
import '../models/aps_optimization_run_view.dart';
import 'aps_p0_debug_service.dart';

/// Greška pri P5 Callable pozivu (operativni ekran Optimizacija).
class ApsOptimizationException implements Exception {
  ApsOptimizationException(this.message, {this.errorCode, this.callableName});

  final String message;
  final String? errorCode;
  final String? callableName;

  @override
  String toString() => message;
}

/// Rezultat pokretanja prijedloga optimizacije.
class ApsStartOptimizationResult {
  const ApsStartOptimizationResult({
    required this.optimizationRunId,
    required this.status,
    required this.baselineScheduleRunId,
    required this.candidateScheduleRunId,
    this.comparison,
  });

  final String optimizationRunId;
  final String status;
  final String baselineScheduleRunId;
  final String candidateScheduleRunId;
  final ApsOptimizationComparisonView? comparison;

  factory ApsStartOptimizationResult.fromCallableData(
    Map<String, dynamic>? data,
  ) {
    final map = data ?? const {};
    final comparisonRaw = map['comparisonResult'];
    return ApsStartOptimizationResult(
      optimizationRunId: (map['optimizationRunId'] ?? '').toString().trim(),
      status: (map['status'] ?? '').toString().trim(),
      baselineScheduleRunId:
          (map['baselineScheduleRunId'] ?? '').toString().trim(),
      candidateScheduleRunId:
          (map['candidateScheduleRunId'] ?? '').toString().trim(),
      comparison: comparisonRaw is Map
          ? ApsOptimizationComparisonView.fromMap(
              Map<String, dynamic>.from(comparisonRaw),
            )
          : null,
    );
  }
}

/// Rezultat primjene prijedloga optimizacije.
class ApsApplyOptimizationResult {
  const ApsApplyOptimizationResult({
    required this.optimizationRunId,
    required this.scenarioId,
    required this.scenarioStatus,
    required this.activeScheduleRunId,
  });

  final String optimizationRunId;
  final String scenarioId;
  final String scenarioStatus;
  final String activeScheduleRunId;

  factory ApsApplyOptimizationResult.fromCallableData(
    Map<String, dynamic>? data,
  ) {
    final map = data ?? const {};
    return ApsApplyOptimizationResult(
      optimizationRunId: (map['optimizationRunId'] ?? '').toString().trim(),
      scenarioId: (map['scenarioId'] ?? '').toString().trim(),
      scenarioStatus: (map['scenarioStatus'] ?? '').toString().trim(),
      activeScheduleRunId:
          (map['activeScheduleRunId'] ?? '').toString().trim(),
    );
  }
}

/// Operativni P5 servis — prijedlozi optimizacije (stub lifecycle P5.1).
class ApsOptimizationService {
  ApsOptimizationService({ApsP0DebugService? debugService})
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

  Future<ApsStartOptimizationResult> startOptimizationRun({
    required String companyId,
    required String plantKey,
    required String scenarioId,
  }) async {
    final result = await _debug.startApsOptimizationRun({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Pokretanje prijedloga optimizacije nije uspjelo.');
    return ApsStartOptimizationResult.fromCallableData(result.data);
  }

  Future<ApsOptimizationRunView> getOptimizationRun({
    required String companyId,
    required String plantKey,
    required String optimizationRunId,
  }) async {
    final result = await _debug.getApsOptimizationRun({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'optimizationRunId': optimizationRunId.trim(),
    });
    _throwIfFailed(result, 'Učitavanje prijedloga optimizacije nije uspjelo.');
    final runRaw = result.data?['run'];
    if (runRaw is! Map) {
      throw ApsOptimizationException(
        'Prijedlog optimizacije nije vraćen.',
        callableName: result.callableName,
      );
    }
    return ApsOptimizationRunView.fromMap(Map<String, dynamic>.from(runRaw));
  }

  Future<List<ApsOptimizationRunView>> listOptimizationRuns({
    required String companyId,
    required String plantKey,
    required String scenarioId,
  }) async {
    final result = await _debug.listApsOptimizationRuns({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Učitavanje liste prijedloga nije uspjelo.');
    return _parseRunList(result.data?['items']);
  }

  Future<ApsApplyOptimizationResult> applyOptimizationResult({
    required String companyId,
    required String plantKey,
    required String optimizationRunId,
    String? confirmationNote,
  }) async {
    final result = await _debug.applyApsOptimizationResult({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'optimizationRunId': optimizationRunId.trim(),
      if (confirmationNote != null && confirmationNote.trim().isNotEmpty)
        'confirmationNote': confirmationNote.trim(),
    });
    _throwIfFailed(result, 'Primjena prijedloga optimizacije nije uspjela.');
    return ApsApplyOptimizationResult.fromCallableData(result.data);
  }

  Future<void> discardOptimizationRun({
    required String companyId,
    required String plantKey,
    required String optimizationRunId,
  }) async {
    final result = await _debug.discardApsOptimizationRun({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'optimizationRunId': optimizationRunId.trim(),
    });
    _throwIfFailed(result, 'Odbacivanje prijedloga optimizacije nije uspjelo.');
  }

  List<ApsOptimizationRunView> _parseRunList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ApsOptimizationRunView.fromMap(Map<String, dynamic>.from(m)))
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  void _throwIfFailed(ApsP0CallResult result, String fallbackMessage) {
    if (result.success) return;
    final msg = (result.errorMessage ?? fallbackMessage).trim();
    throw ApsOptimizationException(
      msg.isNotEmpty ? msg : fallbackMessage,
      errorCode: result.errorCode,
      callableName: result.callableName,
    );
  }
}
