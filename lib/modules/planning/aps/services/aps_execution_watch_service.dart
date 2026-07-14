import '../models/aps_execution_watch_ai_explanation_view.dart';
import '../models/aps_execution_watch_alert_view.dart';
import 'aps_p0_debug_service.dart';

/// Greška pri P6 Callable pozivu.
class ApsExecutionWatchException implements Exception {
  ApsExecutionWatchException(this.message, {this.errorCode, this.callableName});

  final String message;
  final String? errorCode;
  final String? callableName;

  @override
  String toString() => message;
}

class ApsEvaluateExecutionWatchResult {
  const ApsEvaluateExecutionWatchResult({
    required this.evaluatedAt,
    required this.alertsCreated,
    required this.alertsUpdated,
    required this.alertsOpen,
  });

  final String evaluatedAt;
  final int alertsCreated;
  final int alertsUpdated;
  final int alertsOpen;

  factory ApsEvaluateExecutionWatchResult.fromCallableData(
    Map<String, dynamic>? data,
  ) {
    final map = data ?? const {};
    return ApsEvaluateExecutionWatchResult(
      evaluatedAt: (map['evaluatedAt'] ?? '').toString().trim(),
      alertsCreated: int.tryParse((map['alertsCreated'] ?? '0').toString()) ?? 0,
      alertsUpdated: int.tryParse((map['alertsUpdated'] ?? '0').toString()) ?? 0,
      alertsOpen: int.tryParse((map['alertsOpen'] ?? '0').toString()) ?? 0,
    );
  }
}

class ApsListExecutionWatchAlertsResult {
  const ApsListExecutionWatchAlertsResult({
    required this.alerts,
    required this.openCount,
    required this.criticalCount,
  });

  final List<ApsExecutionWatchAlertView> alerts;
  final int openCount;
  final int criticalCount;

  factory ApsListExecutionWatchAlertsResult.fromCallableData(
    Map<String, dynamic>? data,
  ) {
    final map = data ?? const {};
    final raw = map['alerts'];
    final alerts = <ApsExecutionWatchAlertView>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final view = ApsExecutionWatchAlertView.fromMap(
            Map<String, dynamic>.from(item),
          );
          if (view.alertId.isNotEmpty) alerts.add(view);
        }
      }
    }
    return ApsListExecutionWatchAlertsResult(
      alerts: alerts,
      openCount: int.tryParse((map['openCount'] ?? '0').toString()) ?? 0,
      criticalCount:
          int.tryParse((map['criticalCount'] ?? '0').toString()) ?? 0,
    );
  }
}

/// Operativni P6.1 servis — nadzor izvršenja plana (bez LLM).
class ApsExecutionWatchService {
  ApsExecutionWatchService({ApsP0DebugService? debugService})
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

  Future<ApsEvaluateExecutionWatchResult> evaluate({
    required String companyId,
    required String plantKey,
    String? scenarioId,
  }) async {
    final result = await _debug.evaluateApsExecutionWatch({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      if (scenarioId != null && scenarioId.trim().isNotEmpty)
        'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Procjena nadzora izvršenja nije uspjela.');
    return ApsEvaluateExecutionWatchResult.fromCallableData(result.data);
  }

  Future<ApsListExecutionWatchAlertsResult> listAlerts({
    required String companyId,
    required String plantKey,
    String? scenarioId,
    String status = 'open',
    int limit = 50,
  }) async {
    final result = await _debug.listApsExecutionWatchAlerts({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'status': status,
      'limit': limit,
      if (scenarioId != null && scenarioId.trim().isNotEmpty)
        'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Učitavanje upozorenja nije uspjelo.');
    return ApsListExecutionWatchAlertsResult.fromCallableData(result.data);
  }

  Future<ApsExecutionWatchAiExplanationView> explainAlert({
    required String companyId,
    required String plantKey,
    required String alertId,
    bool forceRefresh = false,
  }) async {
    final result = await _debug.explainApsExecutionWatchAlert({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'alertId': alertId.trim(),
      if (forceRefresh) 'forceRefresh': true,
    });
    _throwIfFailed(result, 'AI objašnjenje nije uspjelo.');
    final raw = result.data?['aiExplanation'];
    if (raw is! Map) {
      throw ApsExecutionWatchException(
        'Objašnjenje nije vraćeno.',
        callableName: result.callableName,
      );
    }
    return ApsExecutionWatchAiExplanationView.fromMap(
      Map<String, dynamic>.from(raw),
    );
  }

  /// P6.3 — audit navigacije (ne mijenja alert status niti plan).
  Future<void> recordAlertNavigation({
    required String companyId,
    required String plantKey,
    required String alertId,
    required String navigationTarget,
    String targetScreen = 'optimization',
    String? scenarioId,
  }) async {
    final result = await _debug.recordApsExecutionAlertNavigation({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'alertId': alertId.trim(),
      'navigationTarget': navigationTarget.trim(),
      'targetScreen': targetScreen.trim(),
      if (scenarioId != null && scenarioId.trim().isNotEmpty)
        'scenarioId': scenarioId.trim(),
    });
    _throwIfFailed(result, 'Bilježenje navigacije nije uspjelo.');
  }

  Future<void> resolveAlert({
    required String companyId,
    required String plantKey,
    required String alertId,
    required String resolution,
    String? resolutionNote,
    String? businessOutcome,
    String? resolutionOutcome,
    bool? recommendationAccepted,
    Map<String, dynamic>? valueMetrics,
  }) async {
    final result = await _debug.resolveApsExecutionWatchAlert({
      ..._tenant(companyId: companyId, plantKey: plantKey),
      'alertId': alertId.trim(),
      'resolution': resolution.trim(),
      if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
        'resolutionNote': resolutionNote.trim(),
      if (businessOutcome != null && businessOutcome.trim().isNotEmpty)
        'businessOutcome': businessOutcome.trim(),
      if (resolutionOutcome != null && resolutionOutcome.trim().isNotEmpty)
        'resolutionOutcome': resolutionOutcome.trim(),
      if (recommendationAccepted != null)
        'recommendationAccepted': recommendationAccepted,
      if (valueMetrics != null && valueMetrics.isNotEmpty)
        'valueMetrics': valueMetrics,
    });
    _throwIfFailed(result, 'Ažuriranje upozorenja nije uspjelo.');
  }

  void _throwIfFailed(ApsP0CallResult result, String fallbackMessage) {
    if (result.success) return;
    final msg = (result.errorMessage ?? fallbackMessage).trim();
    throw ApsExecutionWatchException(
      msg.isNotEmpty ? msg : fallbackMessage,
      errorCode: result.errorCode,
      callableName: result.callableName,
    );
  }
}
