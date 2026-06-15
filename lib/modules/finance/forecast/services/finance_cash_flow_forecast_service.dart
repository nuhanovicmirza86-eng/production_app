import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_cash_flow_forecast.dart';

class FinanceCashFlowForecastService {
  FinanceCashFlowForecastService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  static String _dateToCallable(DateTime d) => d.toUtc().toIso8601String();

  Future<FinanceCashFlowForecast> getForecast({
    required String companyId,
    required String bucketType,
    int? horizonDays,
    DateTime? periodFrom,
    DateTime? periodTo,
    List<String>? accountIds,
  }) async {
    final callable = _functions.httpsCallable('getFinanceCashFlowForecast');
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'bucketType': bucketType.trim().toLowerCase(),
    };
    if (horizonDays != null) {
      payload['horizonDays'] = horizonDays;
    } else if (periodFrom != null && periodTo != null) {
      payload['periodFrom'] = _dateToCallable(periodFrom);
      payload['periodTo'] = _dateToCallable(periodTo);
    }
    if (accountIds != null && accountIds.isNotEmpty) {
      payload['accountIds'] = accountIds.map((e) => e.trim()).toList();
    }
    final response = await callable.call(payload);
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor getFinanceCashFlowForecast');
    }
    return FinanceCashFlowForecast.fromCallableMap(
      Map<String, dynamic>.from(data),
    );
  }
}
