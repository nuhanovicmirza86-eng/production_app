import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_ai_recommendation_kpi_snapshot.dart';

/// Callable-only read servis za Finance AI KPI snapshot (bez Firestore pristupa).
class FinanceAiRecommendationKpiService {
  FinanceAiRecommendationKpiService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  Future<FinanceAiRecommendationKpiSnapshot> loadSnapshot({
    required String companyId,
    required DateTime periodFrom,
    required DateTime periodTo,
    String plantKey = '',
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceAiRecommendationKpiSnapshot');
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'periodFrom': periodFrom.toUtc().toIso8601String(),
      'periodTo': periodTo.toUtc().toIso8601String(),
    };
    final pk = plantKey.trim();
    if (pk.isNotEmpty) {
      payload['plantKey'] = pk;
    }
    final response = await callable.call(payload);
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor getFinanceAiRecommendationKpiSnapshot');
    }
    return FinanceAiRecommendationKpiSnapshot.fromCallableMap(
      Map<String, dynamic>.from(data),
    );
  }
}
