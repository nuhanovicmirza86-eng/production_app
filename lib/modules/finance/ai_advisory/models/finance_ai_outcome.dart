import '../../shared/finance_callable_utils.dart';
import 'finance_ai_outcome_evidence.dart';
import 'finance_ai_recommendation_interaction.dart';

class FinanceAiConfirmedImpact {
  const FinanceAiConfirmedImpact({
    this.impactCurrency = '',
    this.confirmedImpactAmount,
    this.confirmationMethod = '',
    this.confirmedBy = '',
    this.confirmedAt,
    this.evidenceIds = const [],
  });

  final String impactCurrency;
  final double? confirmedImpactAmount;
  final String confirmationMethod;
  final String confirmedBy;
  final DateTime? confirmedAt;
  final List<String> evidenceIds;

  factory FinanceAiConfirmedImpact.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const FinanceAiConfirmedImpact();
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, ['confirmedAt']);
    final amount = m['confirmedImpactAmount'];
    return FinanceAiConfirmedImpact(
      impactCurrency: (m['impactCurrency'] ?? '').toString(),
      confirmedImpactAmount: amount == null
          ? null
          : FinanceCallableUtils.parseAmount(amount),
      confirmationMethod: (m['confirmationMethod'] ?? '').toString(),
      confirmedBy: (m['confirmedBy'] ?? '').toString(),
      confirmedAt: m['confirmedAt'] as DateTime?,
      evidenceIds: m['evidenceIds'] is List
          ? (m['evidenceIds'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// Backend outcome zapis — Callable read-only.
class FinanceAiOutcome {
  const FinanceAiOutcome({
    required this.outcomeId,
    required this.companyId,
    required this.recommendationId,
    required this.alertId,
    required this.outcomeStatus,
    this.ruleId = '',
    this.plantKey = '',
    this.attributionLevel = '',
    this.outcomeRuleVersion = '',
    this.outcomeGeneration = 1,
    this.actionType = '',
    this.targetEntityType = '',
    this.targetEntityId = '',
    this.actionAuditId = '',
    this.observationStartedAt,
    this.observationEndsAt,
    this.nextEvaluationAt,
    this.evaluationAttemptCount = 0,
    this.outcomeEvaluatedAt,
    this.confirmedImpact,
  });

  final String outcomeId;
  final String companyId;
  final String recommendationId;
  final String alertId;
  final String outcomeStatus;
  final String ruleId;
  final String plantKey;
  final String attributionLevel;
  final String outcomeRuleVersion;
  final int outcomeGeneration;
  final String actionType;
  final String targetEntityType;
  final String targetEntityId;
  final String actionAuditId;
  final DateTime? observationStartedAt;
  final DateTime? observationEndsAt;
  final DateTime? nextEvaluationAt;
  final int evaluationAttemptCount;
  final DateTime? outcomeEvaluatedAt;
  final FinanceAiConfirmedImpact? confirmedImpact;

  bool get isPending => outcomeStatus == 'outcome_pending';
  bool get isConfirmed => outcomeStatus == 'outcome_confirmed';
  bool get isNotConfirmed => outcomeStatus == 'outcome_not_confirmed';
  bool get isUnknown => outcomeStatus == 'outcome_unknown';

  factory FinanceAiOutcome.fromCallableMap(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, [
      'observationStartedAt',
      'observationEndsAt',
      'nextEvaluationAt',
      'outcomeEvaluatedAt',
      'actionCompletedAt',
      'createdAt',
      'updatedAt',
    ]);
    final ci = m['confirmedImpact'];
    return FinanceAiOutcome(
      outcomeId: (m['outcomeId'] ?? '').toString(),
      companyId: (m['companyId'] ?? '').toString(),
      recommendationId: (m['recommendationId'] ?? '').toString(),
      alertId: (m['alertId'] ?? '').toString(),
      outcomeStatus: (m['outcomeStatus'] ?? '').toString(),
      ruleId: (m['ruleId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      attributionLevel: (m['attributionLevel'] ?? '').toString(),
      outcomeRuleVersion: (m['outcomeRuleVersion'] ?? '').toString(),
      outcomeGeneration: _asInt(m['outcomeGeneration'], fallback: 1),
      actionType: (m['actionType'] ?? '').toString(),
      targetEntityType: (m['targetEntityType'] ?? '').toString(),
      targetEntityId: (m['targetEntityId'] ?? '').toString(),
      actionAuditId: (m['actionAuditId'] ?? '').toString(),
      observationStartedAt: m['observationStartedAt'] as DateTime?,
      observationEndsAt: m['observationEndsAt'] as DateTime?,
      nextEvaluationAt: m['nextEvaluationAt'] as DateTime?,
      evaluationAttemptCount: _asInt(m['evaluationAttemptCount']),
      outcomeEvaluatedAt: m['outcomeEvaluatedAt'] as DateTime?,
      confirmedImpact: ci is Map
          ? FinanceAiConfirmedImpact.fromMap(Map<String, dynamic>.from(ci))
          : null,
    );
  }
}

class FinanceAiOutcomeDetail {
  const FinanceAiOutcomeDetail({
    this.outcome,
    this.evidence = const [],
    this.interactionSummary,
  });

  final FinanceAiOutcome? outcome;
  final List<FinanceAiOutcomeEvidence> evidence;
  final FinanceAiInteractionSummary? interactionSummary;

  factory FinanceAiOutcomeDetail.fromCallableMap(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    final outcomeRaw = m['outcome'];
    final evidenceRaw = m['evidence'];
    final summaryRaw = m['interactionSummary'];
    return FinanceAiOutcomeDetail(
      outcome: outcomeRaw is Map
          ? FinanceAiOutcome.fromCallableMap(
              Map<String, dynamic>.from(outcomeRaw),
            )
          : null,
      evidence: evidenceRaw is List
          ? evidenceRaw
                .whereType<Map>()
                .map(
                  (e) => FinanceAiOutcomeEvidence.fromCallableMap(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      interactionSummary: summaryRaw is Map
          ? FinanceAiInteractionSummary.fromCallableMap(
              Map<String, dynamic>.from(summaryRaw),
            )
          : null,
    );
  }
}

int _asInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}
