import '../../shared/finance_callable_utils.dart';

/// Deterministički evidence zapis — Callable read-only.
class FinanceAiOutcomeEvidence {
  const FinanceAiOutcomeEvidence({
    required this.evidenceId,
    required this.companyId,
    required this.outcomeId,
    required this.recommendationId,
    required this.evidenceType,
    this.alertId = '',
    this.sourceCollection = '',
    this.sourceDocumentId = '',
    this.sourceAuditId = '',
    this.sourceFieldPath = '',
    this.observedBefore,
    this.observedAfter,
    this.observedAt,
    this.currency = '',
    this.evaluatorVersion = '',
  });

  final String evidenceId;
  final String companyId;
  final String outcomeId;
  final String recommendationId;
  final String alertId;
  final String evidenceType;
  final String sourceCollection;
  final String sourceDocumentId;
  final String sourceAuditId;
  final String sourceFieldPath;
  final dynamic observedBefore;
  final dynamic observedAfter;
  final DateTime? observedAt;
  final String currency;
  final String evaluatorVersion;

  factory FinanceAiOutcomeEvidence.fromCallableMap(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, ['observedAt', 'createdAt']);
    return FinanceAiOutcomeEvidence(
      evidenceId: (m['evidenceId'] ?? '').toString(),
      companyId: (m['companyId'] ?? '').toString(),
      outcomeId: (m['outcomeId'] ?? '').toString(),
      recommendationId: (m['recommendationId'] ?? '').toString(),
      alertId: (m['alertId'] ?? '').toString(),
      evidenceType: (m['evidenceType'] ?? '').toString(),
      sourceCollection: (m['sourceCollection'] ?? '').toString(),
      sourceDocumentId: (m['sourceDocumentId'] ?? '').toString(),
      sourceAuditId: (m['sourceAuditId'] ?? '').toString(),
      sourceFieldPath: (m['sourceFieldPath'] ?? '').toString(),
      observedBefore: m['observedBefore'],
      observedAfter: m['observedAfter'],
      observedAt: m['observedAt'] as DateTime?,
      currency: (m['currency'] ?? '').toString(),
      evaluatorVersion: (m['evaluatorVersion'] ?? '').toString(),
    );
  }
}
