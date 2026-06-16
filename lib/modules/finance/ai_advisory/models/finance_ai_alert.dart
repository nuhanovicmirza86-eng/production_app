import '../../shared/finance_callable_utils.dart';

class FinanceAiAlertFact {
  const FinanceAiAlertFact({
    required this.factType,
    required this.sourceCollection,
    required this.label,
    this.sourceId = '',
    this.asOfAt,
    this.snapshot = const {},
  });

  final String factType;
  final String sourceCollection;
  final String sourceId;
  final String label;
  final DateTime? asOfAt;
  final Map<String, dynamic> snapshot;

  factory FinanceAiAlertFact.fromMap(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, ['asOfAt']);
    return FinanceAiAlertFact(
      factType: (m['factType'] ?? '').toString(),
      sourceCollection: (m['sourceCollection'] ?? '').toString(),
      sourceId: (m['sourceId'] ?? '').toString(),
      label: (m['label'] ?? '').toString(),
      asOfAt: m['asOfAt'] as DateTime?,
      snapshot: m['snapshot'] is Map
          ? Map<String, dynamic>.from(m['snapshot'] as Map)
          : const {},
    );
  }
}

class FinanceAiPrimaryRecommendation {
  const FinanceAiPrimaryRecommendation({
    required this.actionType,
    required this.title,
    required this.detail,
    this.navigationParams = const {},
  });

  final String actionType;
  final String title;
  final String detail;
  final Map<String, dynamic> navigationParams;

  factory FinanceAiPrimaryRecommendation.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) {
      return const FinanceAiPrimaryRecommendation(
        actionType: 'no_action',
        title: '',
        detail: '',
      );
    }
    final m = Map<String, dynamic>.from(raw);
    final nav = m['navigationParams'];
    return FinanceAiPrimaryRecommendation(
      actionType: (m['actionType'] ?? 'no_action').toString(),
      title: (m['title'] ?? '').toString(),
      detail: (m['detail'] ?? '').toString(),
      navigationParams: nav is Map
          ? Map<String, dynamic>.from(nav)
          : const {},
    );
  }
}

class FinanceAiAlertExplanation {
  const FinanceAiAlertExplanation({
    this.causeSummary = '',
    this.recommendedActionNarrative = '',
    this.limitations = '',
    this.generatedAt,
    this.modelId = '',
    this.promptVersion = '',
  });

  final String causeSummary;
  final String recommendedActionNarrative;
  final String limitations;
  final DateTime? generatedAt;
  final String modelId;
  final String promptVersion;

  factory FinanceAiAlertExplanation.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const FinanceAiAlertExplanation();
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, ['generatedAt']);
    return FinanceAiAlertExplanation(
      causeSummary: (m['causeSummary'] ?? '').toString(),
      recommendedActionNarrative:
          (m['recommendedActionNarrative'] ?? '').toString(),
      limitations: (m['limitations'] ?? '').toString(),
      generatedAt: m['generatedAt'] as DateTime?,
      modelId: (m['modelId'] ?? '').toString(),
      promptVersion: (m['promptVersion'] ?? '').toString(),
    );
  }
}

/// Proaktivno finance AI upozorenje — Callable `finance_ai_alerts`.
class FinanceAiAlert {
  const FinanceAiAlert({
    required this.alertId,
    required this.companyId,
    required this.ruleId,
    required this.status,
    required this.severity,
    required this.headline,
    required this.summary,
    required this.factsUsed,
    required this.confidenceScore,
    required this.confidenceOrigin,
    required this.confidenceFactors,
    required this.primaryRecommendation,
    required this.aiExplanation,
    this.primaryRecommendationId = '',
    this.plantKey = '',
    this.businessYearId = '',
    this.dedupeKey = '',
    this.signalHash = '',
    this.analysisRunId = '',
    this.triggerSource = '',
    this.triggeredAt,
    this.firstDetectedAt,
    this.lastDetectedAt,
    this.contractVersion = '',
    this.dismissReason,
    this.resolutionReason,
  });

  final String alertId;
  final String companyId;
  final String plantKey;
  final String businessYearId;
  final String ruleId;
  final String dedupeKey;
  final String signalHash;
  final String status;
  final String severity;
  final String headline;
  final String summary;
  final List<FinanceAiAlertFact> factsUsed;
  final double confidenceScore;
  final String confidenceOrigin;
  final Map<String, dynamic> confidenceFactors;
  final FinanceAiPrimaryRecommendation primaryRecommendation;
  final FinanceAiAlertExplanation aiExplanation;
  final String primaryRecommendationId;
  final String analysisRunId;
  final String triggerSource;
  final DateTime? triggeredAt;
  final DateTime? firstDetectedAt;
  final DateTime? lastDetectedAt;
  final String contractVersion;
  final String? dismissReason;
  final String? resolutionReason;

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isAcknowledged => status.toLowerCase() == 'acknowledged';
  bool get isResolved => status.toLowerCase() == 'resolved';
  bool get isDismissed => status.toLowerCase() == 'dismissed';
  bool get isActive => isOpen || isAcknowledged;

  factory FinanceAiAlert.fromCallableMap(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, [
      'triggeredAt',
      'firstDetectedAt',
      'lastDetectedAt',
      'acknowledgedAt',
      'resolvedAt',
      'dismissedAt',
      'createdAt',
      'updatedAt',
    ]);
    final factsRaw = m['factsUsed'];
    final facts = <FinanceAiAlertFact>[];
    if (factsRaw is List) {
      for (final f in factsRaw) {
        if (f is Map) {
          facts.add(FinanceAiAlertFact.fromMap(Map<String, dynamic>.from(f)));
        }
      }
    }
    final cf = m['confidenceFactors'];
    return FinanceAiAlert(
      alertId: (m['alertId'] ?? m['documentId'] ?? '').toString(),
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      businessYearId: (m['businessYearId'] ?? '').toString(),
      ruleId: (m['ruleId'] ?? '').toString(),
      dedupeKey: (m['dedupeKey'] ?? '').toString(),
      signalHash: (m['signalHash'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      severity: (m['severity'] ?? '').toString(),
      headline: (m['headline'] ?? '').toString(),
      summary: (m['summary'] ?? '').toString(),
      factsUsed: facts,
      confidenceScore: FinanceCallableUtils.parseAmount(m['confidenceScore']),
      confidenceOrigin: (m['confidenceOrigin'] ?? '').toString(),
      confidenceFactors: cf is Map
          ? Map<String, dynamic>.from(cf)
          : const {},
      primaryRecommendation: FinanceAiPrimaryRecommendation.fromMap(
        m['primaryRecommendation'] is Map
            ? Map<String, dynamic>.from(m['primaryRecommendation'] as Map)
            : null,
      ),
      primaryRecommendationId: (m['primaryRecommendationId'] ?? '').toString(),
      aiExplanation: FinanceAiAlertExplanation.fromMap(
        m['aiExplanation'] is Map
            ? Map<String, dynamic>.from(m['aiExplanation'] as Map)
            : null,
      ),
      analysisRunId: (m['analysisRunId'] ?? '').toString(),
      triggerSource: (m['triggerSource'] ?? '').toString(),
      triggeredAt: m['triggeredAt'] as DateTime?,
      firstDetectedAt: m['firstDetectedAt'] as DateTime?,
      lastDetectedAt: m['lastDetectedAt'] as DateTime?,
      contractVersion: (m['contractVersion'] ?? '').toString(),
      dismissReason: m['dismissReason']?.toString(),
      resolutionReason: m['resolutionReason']?.toString(),
    );
  }
}
