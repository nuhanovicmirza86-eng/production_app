import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_ai_alert.dart';
import '../models/finance_ai_analysis_result.dart';

class FinanceAiAdvisoryService {
  FinanceAiAdvisoryService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  Future<List<FinanceAiAlert>> listAlerts({
    required String companyId,
    List<String>? status,
    String? severityMin,
    String? plantKey,
    int limit = 50,
  }) async {
    final callable = _functions.httpsCallable('listFinanceAiAlerts');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (severityMin != null && severityMin.trim().isNotEmpty)
        'severityMin': severityMin.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      'limit': limit,
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor listFinanceAiAlerts');
    }
    final alertsRaw = data['alerts'];
    if (alertsRaw is! List) return const [];
    return alertsRaw
        .whereType<Map>()
        .map((e) => FinanceAiAlert.fromCallableMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<FinanceAiAlert> getAlert({
    required String companyId,
    required String alertId,
  }) async {
    final callable = _functions.httpsCallable('getFinanceAiAlert');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'alertId': alertId.trim(),
    });
    final data = response.data;
    if (data is! Map || data['alert'] is! Map) {
      throw FormatException('Nevaljan odgovor getFinanceAiAlert');
    }
    return FinanceAiAlert.fromCallableMap(
      Map<String, dynamic>.from(data['alert'] as Map),
    );
  }

  Future<FinanceAiAnalysisResult> runAdvisoryAnalysis({
    required String companyId,
    String? plantKey,
    String? businessYearId,
    List<String>? ruleIds,
    String? requestId,
  }) async {
    final callable = _functions.httpsCallable('runFinanceAiAdvisoryAnalysis');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      if (businessYearId != null && businessYearId.trim().isNotEmpty)
        'businessYearId': businessYearId.trim(),
      if (ruleIds != null && ruleIds.isNotEmpty) 'ruleIds': ruleIds,
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor runFinanceAiAdvisoryAnalysis');
    }
    return FinanceAiAnalysisResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> acknowledgeAlert({
    required String companyId,
    required String alertId,
    String? requestId,
  }) async {
    final callable = _functions.httpsCallable('acknowledgeFinanceAiAlert');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'alertId': alertId.trim(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
  }

  Future<void> dismissAlert({
    required String companyId,
    required String alertId,
    required String dismissReason,
    String? requestId,
  }) async {
    final callable = _functions.httpsCallable('dismissFinanceAiAlert');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'alertId': alertId.trim(),
      'dismissReason': dismissReason.trim(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
  }

  Future<String> submitFeedback({
    required String companyId,
    required String alertId,
    required String feedbackKind,
    String comment = '',
    String? requestId,
  }) async {
    final callable = _functions.httpsCallable('submitFinanceAiFeedback');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'alertId': alertId.trim(),
      'feedbackKind': feedbackKind.trim(),
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
    final data = response.data;
    if (data is Map) {
      return (data['feedbackId'] ?? '').toString();
    }
    return '';
  }
}
