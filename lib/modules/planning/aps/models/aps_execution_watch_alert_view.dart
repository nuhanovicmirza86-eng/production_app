import 'aps_execution_watch_ai_explanation_view.dart';

/// P6.1 — jedno upozorenje ili prilika iz execution watch sloja.
class ApsExecutionWatchAlertView {
  const ApsExecutionWatchAlertView({
    required this.alertId,
    required this.alertKind,
    required this.alertType,
    required this.severity,
    required this.headline,
    required this.impact,
    required this.status,
    this.scenarioId,
    this.scenarioDisplayName,
    this.ruleId,
    this.recommendations = const [],
    this.navigationActions = const [],
    this.sources = const [],
    this.valueMetrics = const {},
    this.updatedAt,
    this.focusOperationId,
    this.businessOutcome,
    this.userAction,
    this.responseTimeSeconds,
    this.resolutionOutcome,
    this.resolvedAt,
    this.userActionAt,
    this.resolutionNote,
    this.recommendationAccepted,
    this.aiExplanation,
  });

  final String alertId;
  final String alertKind;
  final String alertType;
  final String severity;
  final String headline;
  final String impact;
  final String status;
  final String? scenarioId;
  final String? scenarioDisplayName;
  final String? ruleId;
  final List<ApsExecutionWatchRecommendationView> recommendations;
  final List<ApsExecutionWatchNavigationActionView> navigationActions;
  final List<ApsExecutionWatchSourceView> sources;
  final Map<String, dynamic> valueMetrics;
  final String? updatedAt;
  final String? focusOperationId;
  final String? businessOutcome;
  final String? userAction;
  final int? responseTimeSeconds;
  final String? resolutionOutcome;
  final String? resolvedAt;
  final String? userActionAt;
  final String? resolutionNote;
  final bool? recommendationAccepted;
  final ApsExecutionWatchAiExplanationView? aiExplanation;

  bool get isRisk => alertKind == 'risk';
  bool get isOpportunity => alertKind == 'opportunity';
  bool get isOpen => status == 'open' || status == 'in_progress';

  factory ApsExecutionWatchAlertView.fromMap(Map<String, dynamic> map) {
    final recs = <ApsExecutionWatchRecommendationView>[];
    final rawRecs = map['recommendations'];
    if (rawRecs is List) {
      for (final raw in rawRecs) {
        if (raw is Map) {
          recs.add(
            ApsExecutionWatchRecommendationView.fromMap(
              Map<String, dynamic>.from(raw),
            ),
          );
        }
      }
    }

    final nav = <ApsExecutionWatchNavigationActionView>[];
    final rawNav = map['navigationActions'];
    if (rawNav is List) {
      for (final raw in rawNav) {
        if (raw is Map) {
          nav.add(
            ApsExecutionWatchNavigationActionView.fromMap(
              Map<String, dynamic>.from(raw),
            ),
          );
        }
      }
    }

    final src = <ApsExecutionWatchSourceView>[];
    final rawSrc = map['sources'];
    if (rawSrc is List) {
      for (final raw in rawSrc) {
        if (raw is Map) {
          src.add(
            ApsExecutionWatchSourceView.fromMap(
              Map<String, dynamic>.from(raw),
            ),
          );
        }
      }
    }

    String? focusOp;
    for (final action in nav) {
      final id = action.focusOperationId?.trim() ?? '';
      if (id.isNotEmpty) {
        focusOp = id;
        break;
      }
    }

    final vm = map['valueMetrics'];
    return ApsExecutionWatchAlertView(
      alertId: (map['alertId'] ?? '').toString().trim(),
      alertKind: (map['alertKind'] ?? 'risk').toString().trim(),
      alertType: (map['alertType'] ?? '').toString().trim(),
      severity: (map['severity'] ?? 'medium').toString().trim(),
      headline: (map['headline'] ?? '').toString().trim(),
      impact: (map['impact'] ?? '').toString().trim(),
      status: (map['status'] ?? 'open').toString().trim(),
      scenarioId: (map['scenarioId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['scenarioId'] ?? '').toString().trim(),
      scenarioDisplayName:
          (map['scenarioDisplayName'] ?? '').toString().trim().isEmpty
          ? null
          : (map['scenarioDisplayName'] ?? '').toString().trim(),
      ruleId: (map['ruleId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['ruleId'] ?? '').toString().trim(),
      recommendations: recs,
      navigationActions: nav,
      sources: src,
      valueMetrics: vm is Map
          ? Map<String, dynamic>.from(vm)
          : const {},
      updatedAt: (map['updatedAt'] ?? '').toString().trim().isEmpty
          ? null
          : (map['updatedAt'] ?? '').toString().trim(),
      focusOperationId: focusOp,
      businessOutcome: (map['businessOutcome'] ?? '').toString().trim().isEmpty
          ? null
          : (map['businessOutcome'] ?? '').toString().trim(),
      userAction: (map['userAction'] ?? '').toString().trim().isEmpty
          ? null
          : (map['userAction'] ?? '').toString().trim(),
      responseTimeSeconds: _parseInt(map['responseTimeSeconds']),
      resolutionOutcome:
          (map['resolutionOutcome'] ?? '').toString().trim().isEmpty
          ? null
          : (map['resolutionOutcome'] ?? '').toString().trim(),
      resolvedAt: (map['resolvedAt'] ?? '').toString().trim().isEmpty
          ? null
          : (map['resolvedAt'] ?? '').toString().trim(),
      userActionAt: (map['userActionAt'] ?? '').toString().trim().isEmpty
          ? null
          : (map['userActionAt'] ?? '').toString().trim(),
      resolutionNote: (map['resolutionNote'] ?? '').toString().trim().isEmpty
          ? null
          : (map['resolutionNote'] ?? '').toString().trim(),
      recommendationAccepted: map['recommendationAccepted'] is bool
          ? map['recommendationAccepted'] as bool
          : null,
      aiExplanation: map['aiExplanation'] is Map
          ? ApsExecutionWatchAiExplanationView.fromMap(
              Map<String, dynamic>.from(map['aiExplanation'] as Map),
            )
          : null,
    );
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }
}

class ApsExecutionWatchRecommendationView {
  const ApsExecutionWatchRecommendationView({
    required this.rank,
    required this.label,
    this.type,
  });

  final int rank;
  final String label;
  final String? type;

  factory ApsExecutionWatchRecommendationView.fromMap(
    Map<String, dynamic> map,
  ) {
    return ApsExecutionWatchRecommendationView(
      rank: int.tryParse((map['rank'] ?? '0').toString()) ?? 0,
      label: (map['label'] ?? '').toString().trim(),
      type: (map['type'] ?? '').toString().trim().isEmpty
          ? null
          : (map['type'] ?? '').toString().trim(),
    );
  }
}

class ApsExecutionWatchNavigationActionView {
  const ApsExecutionWatchNavigationActionView({
    required this.actionId,
    required this.label,
    required this.navigationTarget,
    this.scenarioId,
    this.focusOperationId,
  });

  final String actionId;
  final String label;
  final String navigationTarget;
  final String? scenarioId;
  final String? focusOperationId;

  factory ApsExecutionWatchNavigationActionView.fromMap(
    Map<String, dynamic> map,
  ) {
    return ApsExecutionWatchNavigationActionView(
      actionId: (map['actionId'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString().trim(),
      navigationTarget: (map['navigationTarget'] ?? 'none').toString().trim(),
      scenarioId: (map['scenarioId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['scenarioId'] ?? '').toString().trim(),
      focusOperationId:
          (map['focusOperationId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['focusOperationId'] ?? '').toString().trim(),
    );
  }
}

class ApsExecutionWatchSourceView {
  const ApsExecutionWatchSourceView({
    required this.type,
    required this.id,
    this.displayName,
  });

  final String type;
  final String id;
  final String? displayName;

  factory ApsExecutionWatchSourceView.fromMap(Map<String, dynamic> map) {
    return ApsExecutionWatchSourceView(
      type: (map['type'] ?? '').toString().trim(),
      id: (map['id'] ?? '').toString().trim(),
      displayName: (map['displayName'] ?? '').toString().trim().isEmpty
          ? null
          : (map['displayName'] ?? '').toString().trim(),
    );
  }
}
