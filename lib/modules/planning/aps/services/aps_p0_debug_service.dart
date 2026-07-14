import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

/// Rezultat jednog APS P0 Callable poziva (interni debug).
class ApsP0CallResult {
  const ApsP0CallResult({
    required this.callableName,
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
    this.durationMs,
  });

  final String callableName;
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final String? errorMessage;
  final int? durationMs;

  String get displayText {
    final buf = StringBuffer()
      ..writeln('Callable: $callableName')
      ..writeln('Success: $success');
    if (durationMs != null) {
      buf.writeln('Duration: ${durationMs}ms');
    }
    if (errorCode != null) {
      buf.writeln('HttpsError.code: $errorCode');
    }
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      buf.writeln('Message: $errorMessage');
    }
    if (data != null && data!.isNotEmpty) {
      buf.writeln('Data:');
      buf.writeln(const JsonEncoder.withIndent('  ').convert(_dataForDisplay(data!)));
    }
    return buf.toString().trim();
  }

  /// Skraćuje velike `items` liste radi čitljivosti na mobilnom debug ekranu.
  static Map<String, dynamic> _dataForDisplay(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    final items = copy['items'];
    if (items is List) {
      copy['items_count'] = items.length;
      if (items.isNotEmpty) {
        final first = items.first;
        if (first is Map) {
          copy['items_first'] = Map<String, dynamic>.from(first);
        }
      }
      copy.remove('items');
    }
    return copy;
  }

  String get summaryLine {
    if (success) {
      final ok = data?['ok'];
      final id = (data?['id'] ?? '').toString().trim();
      final count = data?['items'];
      if (count is List) {
        var line = '$callableName → OK (${count.length} stavki)';
        if (count.isNotEmpty) {
          final first = count.first;
          if (first is Map) {
            final st = (first['status'] ?? '').toString().trim();
            if (st.isNotEmpty) {
              line += ', status: $st';
            }
          }
        }
        return line;
      }
      if (id.isNotEmpty) {
        return '$callableName → OK (id: $id)';
      }
      if (ok != null) {
        return '$callableName → OK';
      }
      final util = data?['utilizationPercent'];
      if (util != null) {
        return '$callableName → OK (util: $util%)';
      }
      final auditLogId = (data?['auditLogId'] ?? '').toString().trim();
      final auditAction = (data?['auditAction'] ?? '').toString().trim();
      if (auditLogId.isNotEmpty) {
        var line = '$callableName → OK';
        final opCount = data?['operationCount'] ?? data?['operationsReleased'];
        if (opCount != null) {
          line += ' (ops: $opCount)';
        }
        final pilotLabel = (data?['pilotModeLabel'] ?? '').toString().trim();
        if (pilotLabel.isNotEmpty) {
          line += '\n$pilotLabel';
        }
        final releaseRunId = (data?['releaseRunId'] ?? '').toString().trim();
        if (releaseRunId.isNotEmpty) {
          line += '\nreleaseRunId: $releaseRunId';
        }
        if (auditAction.isNotEmpty) {
          line += '\nauditAction: $auditAction';
        }
        line += '\nauditLogId: $auditLogId';
        return line;
      }
      final opCount = data?['operationCount'];
      if (opCount != null) {
        return '$callableName → OK (ops: $opCount)';
      }
      final targetStatus = (data?['targetStatus'] ?? '').toString().trim();
      if (targetStatus.isNotEmpty && data?['scenarioStatus'] != null) {
        return '$callableName → OK ($targetStatus, scenario: ${data!['scenarioStatus']})';
      }
      final snapId = (data?['planningInputSnapshotId'] ?? '').toString().trim();
      if (snapId.isNotEmpty) {
        return '$callableName → OK (snapshot: ${snapId.length > 12 ? '${snapId.substring(0, 12)}…' : snapId})';
      }
      return '$callableName → OK';
    }
    final code = errorCode ?? 'error';
    return '$callableName → FAIL ($code)';
  }

  /// P2 contract: sve operacije moraju biti `draft_planned` (ne `planned`).
  static String? scheduleOpsStatusMismatch(ApsP0CallResult result) {
    if (!result.success || result.data == null) {
      return 'list nije uspio';
    }
    final items = result.data!['items'];
    if (items is! List || items.isEmpty) {
      return 'nema operacija u listi';
    }
    for (final raw in items) {
      if (raw is! Map) continue;
      final st = (raw['status'] ?? '').toString().trim();
      if (st != 'draft_planned') {
        return 'očekivano draft_planned, dobiveno: ${st.isEmpty ? "(prazno)" : st}';
      }
    }
    return null;
  }
}

/// Interni P0 smoke — samo httpsCallable, bez Firestore mutacija iz klijenta.
class ApsP0DebugService {
  ApsP0DebugService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<ApsP0CallResult> invoke(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final raw = await _functions
          .httpsCallable(callableName)
          .call(Map<String, dynamic>.from(payload));
      sw.stop();
      return ApsP0CallResult(
        callableName: callableName,
        success: true,
        data: _normalizeResponseData(raw.data),
        durationMs: sw.elapsedMilliseconds,
      );
    } on FirebaseFunctionsException catch (e) {
      sw.stop();
      return ApsP0CallResult(
        callableName: callableName,
        success: false,
        errorCode: e.code,
        errorMessage: e.message,
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return ApsP0CallResult(
        callableName: callableName,
        success: false,
        errorMessage: e.toString(),
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }

  static Map<String, dynamic>? _normalizeResponseData(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return {'value': raw};
  }

  Future<ApsP0CallResult> createApsResource(Map<String, dynamic> body) =>
      invoke('createApsResource', body);

  Future<ApsP0CallResult> updateApsResource(Map<String, dynamic> body) =>
      invoke('updateApsResource', body);

  Future<ApsP0CallResult> listApsResources(Map<String, dynamic> body) =>
      invoke('listApsResources', body);

  Future<ApsP0CallResult> createApsCalendar(Map<String, dynamic> body) =>
      invoke('createApsCalendar', body);

  Future<ApsP0CallResult> updateApsCalendar(Map<String, dynamic> body) =>
      invoke('updateApsCalendar', body);

  Future<ApsP0CallResult> listApsCalendars(Map<String, dynamic> body) =>
      invoke('listApsCalendars', body);

  Future<ApsP0CallResult> createApsConstraint(Map<String, dynamic> body) =>
      invoke('createApsConstraint', body);

  Future<ApsP0CallResult> updateApsConstraint(Map<String, dynamic> body) =>
      invoke('updateApsConstraint', body);

  Future<ApsP0CallResult> listApsConstraints(Map<String, dynamic> body) =>
      invoke('listApsConstraints', body);

  Future<ApsP0CallResult> createApsObjectiveProfile(Map<String, dynamic> body) =>
      invoke('createApsObjectiveProfile', body);

  Future<ApsP0CallResult> updateApsObjectiveProfile(
    Map<String, dynamic> body,
  ) => invoke('updateApsObjectiveProfile', body);

  Future<ApsP0CallResult> listApsObjectiveProfiles(
    Map<String, dynamic> body,
  ) => invoke('listApsObjectiveProfiles', body);

  Future<ApsP0CallResult> createApsRoutingExtension(
    Map<String, dynamic> body,
  ) => invoke('createApsRoutingExtension', body);

  Future<ApsP0CallResult> updateApsRoutingExtension(
    Map<String, dynamic> body,
  ) => invoke('updateApsRoutingExtension', body);

  Future<ApsP0CallResult> listApsRoutingExtensions(
    Map<String, dynamic> body,
  ) => invoke('listApsRoutingExtensions', body);

  // --- APS P1 (scenarios + rough capacity) ---

  Future<ApsP0CallResult> createApsDemand(Map<String, dynamic> body) =>
      invoke('createApsDemand', body);

  Future<ApsP0CallResult> updateApsDemand(Map<String, dynamic> body) =>
      invoke('updateApsDemand', body);

  Future<ApsP0CallResult> listApsDemands(Map<String, dynamic> body) =>
      invoke('listApsDemands', body);

  Future<ApsP0CallResult> createApsScenario(Map<String, dynamic> body) =>
      invoke('createApsScenario', body);

  Future<ApsP0CallResult> updateApsScenario(Map<String, dynamic> body) =>
      invoke('updateApsScenario', body);

  Future<ApsP0CallResult> listApsScenarios(Map<String, dynamic> body) =>
      invoke('listApsScenarios', body);

  Future<ApsP0CallResult> addDemandToApsScenario(Map<String, dynamic> body) =>
      invoke('addDemandToApsScenario', body);

  Future<ApsP0CallResult> removeDemandFromApsScenario(
    Map<String, dynamic> body,
  ) => invoke('removeDemandFromApsScenario', body);

  Future<ApsP0CallResult> listApsScenarioItems(Map<String, dynamic> body) =>
      invoke('listApsScenarioItems', body);

  Future<ApsP0CallResult> calculateApsRoughCapacity(
    Map<String, dynamic> body,
  ) => invoke('calculateApsRoughCapacity', body);

  Future<ApsP0CallResult> listApsCapacityWarnings(
    Map<String, dynamic> body,
  ) => invoke('listApsCapacityWarnings', body);

  // --- APS P2 (heuristic scheduling) ---

  Future<ApsP0CallResult> generateApsHeuristicSchedule(
    Map<String, dynamic> body,
  ) => invoke('generateApsHeuristicSchedule', body);

  Future<ApsP0CallResult> listApsScheduleOperations(
    Map<String, dynamic> body,
  ) => invoke('listApsScheduleOperations', body);

  Future<ApsP0CallResult> clearApsScenarioSchedule(
    Map<String, dynamic> body,
  ) => invoke('clearApsScenarioSchedule', body);

  // --- APS P4 pilot (P4a approve — bez MES release) ---

  Future<ApsP0CallResult> approveApsScenarioSchedule(
    Map<String, dynamic> body,
  ) => invoke('approveApsScenarioSchedule', body);

  // --- APS P4 pilot (P4b release — pilot MES, ne full release) ---

  Future<ApsP0CallResult> releaseApsScenarioToMesPilot(
    Map<String, dynamic> body,
  ) => invoke('releaseApsScenarioToMesPilot', body);

  // --- APS P5 optimization (stub lifecycle) ---

  Future<ApsP0CallResult> startApsOptimizationRun(
    Map<String, dynamic> body,
  ) => invoke('startApsOptimizationRun', body);

  Future<ApsP0CallResult> getApsOptimizationRun(
    Map<String, dynamic> body,
  ) => invoke('getApsOptimizationRun', body);

  Future<ApsP0CallResult> listApsOptimizationRuns(
    Map<String, dynamic> body,
  ) => invoke('listApsOptimizationRuns', body);

  Future<ApsP0CallResult> applyApsOptimizationResult(
    Map<String, dynamic> body,
  ) => invoke('applyApsOptimizationResult', body);

  Future<ApsP0CallResult> discardApsOptimizationRun(
    Map<String, dynamic> body,
  ) => invoke('discardApsOptimizationRun', body);

  // --- APS P6 execution watch (P6.1) ---

  Future<ApsP0CallResult> evaluateApsExecutionWatch(
    Map<String, dynamic> body,
  ) => invoke('evaluateApsExecutionWatch', body);

  Future<ApsP0CallResult> listApsExecutionWatchAlerts(
    Map<String, dynamic> body,
  ) => invoke('listApsExecutionWatchAlerts', body);

  Future<ApsP0CallResult> resolveApsExecutionWatchAlert(
    Map<String, dynamic> body,
  ) => invoke('resolveApsExecutionWatchAlert', body);

  // --- APS P6.2 AI explanation ---

  Future<ApsP0CallResult> explainApsExecutionWatchAlert(
    Map<String, dynamic> body,
  ) => invoke('explainApsExecutionAlert', body);

  // --- APS P6.3 navigacija ---

  Future<ApsP0CallResult> recordApsExecutionAlertNavigation(
    Map<String, dynamic> body,
  ) => invoke('recordApsExecutionAlertNavigation', body);
}
