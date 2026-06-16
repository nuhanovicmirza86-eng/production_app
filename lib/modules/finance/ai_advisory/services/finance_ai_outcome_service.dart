import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_ai_outcome.dart';
import '../models/finance_ai_outcome_evidence.dart';
import '../models/finance_ai_recommendation_interaction.dart';

/// Stabilni requestId ključevi za idempotentnu telemetry.
class FinanceAiInteractionRequestIds {
  FinanceAiInteractionRequestIds._();

  static String shown(String alertId, String recommendationId) =>
      'shown-$alertId-$recommendationId';

  static String viewed(String alertId, String recommendationId) =>
      'viewed-$alertId-$recommendationId';

  static String accepted(String alertId, String recommendationId) =>
      'accepted-$alertId-$recommendationId';

  static String rejected(String alertId, String recommendationId, String reasonCode) =>
      'rejected-$alertId-$recommendationId-$reasonCode';

  static String actionStarted(String alertId, String recommendationId) =>
      'action-started-$alertId-$recommendationId';

  static String actionCompleted(String alertId, String recommendationId) =>
      'action-completed-$alertId-$recommendationId';
}

class FinanceAiOutcomeService {
  FinanceAiOutcomeService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  Future<FinanceAiRecommendationInteraction> recordInteraction({
    required String companyId,
    required String recommendationId,
    required String interactionType,
    required String requestId,
    String clientSurface = 'alert_detail',
    String? targetEntityType,
    String? targetEntityId,
    String? actionAuditId,
    Map<String, dynamic>? metadata,
  }) async {
    final callable =
        _functions.httpsCallable('recordFinanceAiRecommendationInteraction');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'recommendationId': recommendationId.trim(),
      'interactionType': interactionType.trim(),
      'requestId': requestId.trim(),
      if (clientSurface.trim().isNotEmpty) 'clientSurface': clientSurface.trim(),
      if (targetEntityType != null && targetEntityType.trim().isNotEmpty)
        'targetEntityType': targetEntityType.trim(),
      if (targetEntityId != null && targetEntityId.trim().isNotEmpty)
        'targetEntityId': targetEntityId.trim(),
      if (actionAuditId != null && actionAuditId.trim().isNotEmpty)
        'actionAuditId': actionAuditId.trim(),
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
    final data = response.data;
    if (data is! Map || data['interaction'] is! Map) {
      throw FormatException('Nevaljan odgovor recordFinanceAiRecommendationInteraction');
    }
    return FinanceAiRecommendationInteraction.fromCallableMap(
      Map<String, dynamic>.from(data['interaction'] as Map),
    );
  }

  Future<FinanceAiOutcomeDetail> getOutcome({
    required String companyId,
    String? recommendationId,
    String? outcomeId,
  }) async {
    final callable = _functions.httpsCallable('getFinanceAiOutcome');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (recommendationId != null && recommendationId.trim().isNotEmpty)
        'recommendationId': recommendationId.trim(),
      if (outcomeId != null && outcomeId.trim().isNotEmpty)
        'outcomeId': outcomeId.trim(),
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor getFinanceAiOutcome');
    }
    return FinanceAiOutcomeDetail.fromCallableMap(
      Map<String, dynamic>.from(data),
    );
  }

  Future<FinanceAiOutcomeDetail> listOutcomesForAlert({
    required String companyId,
    required String alertId,
  }) async {
    final callable = _functions.httpsCallable('listFinanceAiOutcomes');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'alertId': alertId.trim(),
      'limit': 10,
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor listFinanceAiOutcomes');
    }
    final outcomesRaw = data['outcomes'];
    final evidenceRaw = data['evidence'];
    FinanceAiOutcome? outcome;
    if (outcomesRaw is List && outcomesRaw.isNotEmpty && outcomesRaw.first is Map) {
      outcome = FinanceAiOutcome.fromCallableMap(
        Map<String, dynamic>.from(outcomesRaw.first as Map),
      );
    }
    final evidence = evidenceRaw is List
        ? evidenceRaw
              .whereType<Map>()
              .map(
                (e) => FinanceAiOutcomeEvidence.fromCallableMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : const <FinanceAiOutcomeEvidence>[];
    return FinanceAiOutcomeDetail(outcome: outcome, evidence: evidence);
  }
}
