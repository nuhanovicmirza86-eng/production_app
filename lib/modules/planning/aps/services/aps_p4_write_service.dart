import 'aps_p0_debug_service.dart';

/// Greška pri P4 Callable mutaciji (potvrda plana / pilot release).
class ApsP4WriteException implements Exception {
  ApsP4WriteException(this.message, {this.errorCode});

  final String message;
  final String? errorCode;

  @override
  String toString() => message;
}

/// Rezultat uspješnog [ApsP4WriteService.confirmPlan].
class ApsP4ApproveResult {
  const ApsP4ApproveResult({
    required this.operationCount,
    required this.auditLogId,
    required this.auditAction,
    required this.scenarioStatus,
  });

  final int operationCount;
  final String auditLogId;
  final String auditAction;
  final String scenarioStatus;

  factory ApsP4ApproveResult.fromCallableData(Map<String, dynamic>? data) {
    final map = data ?? const {};
    return ApsP4ApproveResult(
      operationCount: (map['operationCount'] as num?)?.toInt() ?? 0,
      auditLogId: (map['auditLogId'] ?? '').toString().trim(),
      auditAction: (map['auditAction'] ?? '').toString().trim(),
      scenarioStatus: (map['scenarioStatus'] ?? '').toString().trim(),
    );
  }
}

/// Rezultat uspješnog [ApsP4WriteService.releaseToMesPilot].
class ApsP4PilotReleaseResult {
  const ApsP4PilotReleaseResult({
    required this.releaseRunId,
    required this.operationsReleased,
    required this.auditLogId,
    required this.auditAction,
    this.productionOrdersUpdated = 0,
    this.warnings = const [],
  });

  final String releaseRunId;
  final int operationsReleased;
  final String auditLogId;
  final String auditAction;
  final int productionOrdersUpdated;
  final List<Map<String, dynamic>> warnings;

  factory ApsP4PilotReleaseResult.fromCallableData(Map<String, dynamic>? data) {
    final map = data ?? const {};
    final warningsRaw = map['warnings'];
    final warnings = <Map<String, dynamic>>[];
    if (warningsRaw is List) {
      for (final w in warningsRaw) {
        if (w is Map) {
          warnings.add(Map<String, dynamic>.from(w));
        }
      }
    }
    return ApsP4PilotReleaseResult(
      releaseRunId: (map['releaseRunId'] ?? '').toString().trim(),
      operationsReleased: (map['operationsReleased'] as num?)?.toInt() ?? 0,
      auditLogId: (map['auditLogId'] ?? '').toString().trim(),
      auditAction: (map['auditAction'] ?? '').toString().trim(),
      productionOrdersUpdated:
          (map['productionOrdersUpdated'] as num?)?.toInt() ?? 0,
      warnings: warnings,
    );
  }
}

/// P4a potvrda plana + P4b pilot release — odvojeni Callable pozivi.
class ApsP4WriteService {
  ApsP4WriteService({ApsP0DebugService? debugService})
    : _debug = debugService ?? ApsP0DebugService();

  final ApsP0DebugService _debug;

  Future<ApsP4ApproveResult> confirmPlan({
    required String companyId,
    required String plantKey,
    required String scenarioId,
    String targetStatus = 'planned',
  }) async {
    final result = await _debug.approveApsScenarioSchedule({
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'scenarioId': scenarioId.trim(),
      'targetStatus': targetStatus,
    });

    if (!result.success) {
      throw ApsP4WriteException(
        result.errorMessage ?? 'Potvrda plana nije uspjela.',
        errorCode: result.errorCode,
      );
    }

    final approve = ApsP4ApproveResult.fromCallableData(result.data);
    if (approve.auditLogId.isEmpty) {
      throw ApsP4WriteException(
        'Plan je potvrđen, ali revizijski zapis nije potpun.',
      );
    }
    return approve;
  }

  Future<ApsP4PilotReleaseResult> releaseToMesPilot({
    required String companyId,
    required String plantKey,
    required String scenarioId,
    String? confirmationNote,
  }) async {
    final result = await _debug.releaseApsScenarioToMesPilot({
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'scenarioId': scenarioId.trim(),
      'pilotAcknowledgement': true,
      if (confirmationNote != null && confirmationNote.trim().isNotEmpty)
        'confirmationNote': confirmationNote.trim(),
    });

    if (!result.success) {
      throw ApsP4WriteException(
        result.errorMessage ?? 'Pilotsko slanje u MES nije uspjelo.',
        errorCode: result.errorCode,
      );
    }

    final release = ApsP4PilotReleaseResult.fromCallableData(result.data);
    if (release.auditLogId.isEmpty) {
      throw ApsP4WriteException(
        'Slanje je završeno, ali revizijski zapis nije potpun.',
      );
    }
    return release;
  }
}
