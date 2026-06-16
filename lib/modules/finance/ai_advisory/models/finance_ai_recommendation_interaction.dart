import '../../shared/finance_callable_utils.dart';

/// Telemetry zapis — Callable `finance_ai_recommendation_interactions`.
class FinanceAiRecommendationInteraction {
  const FinanceAiRecommendationInteraction({
    required this.interactionId,
    required this.companyId,
    required this.recommendationId,
    required this.alertId,
    required this.interactionType,
    this.ruleId = '',
    this.plantKey = '',
    this.actionType = '',
    this.clientSurface = '',
    this.requestId = '',
    this.targetEntityType = '',
    this.targetEntityId = '',
    this.actionAuditId = '',
    this.interactionAt,
    this.metadata = const {},
  });

  final String interactionId;
  final String companyId;
  final String recommendationId;
  final String alertId;
  final String interactionType;
  final String ruleId;
  final String plantKey;
  final String actionType;
  final String clientSurface;
  final String requestId;
  final String targetEntityType;
  final String targetEntityId;
  final String actionAuditId;
  final DateTime? interactionAt;
  final Map<String, dynamic> metadata;

  factory FinanceAiRecommendationInteraction.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, [
      'interactionAt',
      'actionCompletedAt',
      'createdAt',
      'updatedAt',
    ]);
    final meta = m['metadata'];
    return FinanceAiRecommendationInteraction(
      interactionId: (m['interactionId'] ?? '').toString(),
      companyId: (m['companyId'] ?? '').toString(),
      recommendationId: (m['recommendationId'] ?? '').toString(),
      alertId: (m['alertId'] ?? '').toString(),
      interactionType: (m['interactionType'] ?? '').toString(),
      ruleId: (m['ruleId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      actionType: (m['actionType'] ?? '').toString(),
      clientSurface: (m['clientSurface'] ?? '').toString(),
      requestId: (m['requestId'] ?? '').toString(),
      targetEntityType: (m['targetEntityType'] ?? '').toString(),
      targetEntityId: (m['targetEntityId'] ?? '').toString(),
      actionAuditId: (m['actionAuditId'] ?? '').toString(),
      interactionAt: m['interactionAt'] as DateTime?,
      metadata: meta is Map
          ? Map<String, dynamic>.from(meta)
          : const {},
    );
  }
}

/// Sažetak interakcija za outcome read model.
class FinanceAiInteractionSummary {
  const FinanceAiInteractionSummary({
    this.shownCount = 0,
    this.viewedCount = 0,
    this.accepted = false,
    this.rejected = false,
    this.actionStarted = false,
    this.actionCompleted = false,
    this.interactionCount = 0,
    this.actionCompletedAt,
    this.lastInteractionAt,
  });

  final int shownCount;
  final int viewedCount;
  final bool accepted;
  final bool rejected;
  final bool actionStarted;
  final bool actionCompleted;
  final int interactionCount;
  final DateTime? actionCompletedAt;
  final DateTime? lastInteractionAt;

  factory FinanceAiInteractionSummary.fromCallableMap(Map<String, dynamic>? raw) {
    if (raw == null) return const FinanceAiInteractionSummary();
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, [
      'actionCompletedAt',
      'lastInteractionAt',
    ]);
    return FinanceAiInteractionSummary(
      shownCount: _asInt(m['shownCount']),
      viewedCount: _asInt(m['viewedCount']),
      accepted: m['accepted'] == true,
      rejected: m['rejected'] == true,
      actionStarted: m['actionStarted'] == true,
      actionCompleted: m['actionCompleted'] == true,
      interactionCount: _asInt(m['interactionCount']),
      actionCompletedAt: m['actionCompletedAt'] as DateTime?,
      lastInteractionAt: m['lastInteractionAt'] as DateTime?,
    );
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}
