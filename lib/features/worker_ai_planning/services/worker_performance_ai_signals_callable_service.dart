import 'package:cloud_functions/cloud_functions.dart';

import '../../../features/process_evidence_analytics/models/process_evidence_analytics_models.dart';
import '../models/worker_performance_ai_signals_models.dart';

String workerPerformanceAiSignalsErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final msg = (error.message ?? '').trim();
    if (msg.isNotEmpty) return msg;
    return error.code;
  }
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('[firebase_functions/', '');
}

class WorkerPerformanceAiSignalsCallableService {
  WorkerPerformanceAiSignalsCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<WorkerPerformanceAiSignalsResult> getSignals({
    required String companyId,
    required ProcessEvidenceAnalyticsFilters filters,
    List<String> focusOperatorIds = const [],
    String? planningQuestion,
  }) async {
    final payload = filters.toCallablePayload(companyId);
    if (focusOperatorIds.isNotEmpty) {
      payload['focusOperatorIds'] = focusOperatorIds;
    }
    final q = (planningQuestion ?? '').trim();
    if (q.isNotEmpty) payload['planningQuestion'] = q;

    final res = await _functions
        .httpsCallable('getWorkerPerformanceAiSignals')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje AI preporuka nije uspjelo.');
    }
    return WorkerPerformanceAiSignalsResult.fromMap(data);
  }
}
