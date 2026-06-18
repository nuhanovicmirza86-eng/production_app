import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_budget_actual_working_capital_snapshot.dart';

class FinanceBudgetActualWorkingCapitalService {
  FinanceBudgetActualWorkingCapitalService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  static String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<FinanceBudgetActualWorkingCapitalSnapshot> getSnapshot({
    required String companyId,
    required DateTime periodFrom,
    required DateTime periodTo,
    required String currency,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceBudgetActualAndWorkingCapitalSnapshot');
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'periodFrom': _ymd(periodFrom),
      'periodTo': _ymd(periodTo),
      'currency': currency.trim().toUpperCase(),
      'plantKey': () {
        final pk = plantKey?.trim();
        return (pk == null || pk.isEmpty) ? null : pk;
      }(),
    };
    final response = await callable.call(payload);
    final data = response.data;
    if (data is! Map) {
      throw FormatException(
        'Nevaljan odgovor getFinanceBudgetActualAndWorkingCapitalSnapshot',
      );
    }
    return FinanceBudgetActualWorkingCapitalSnapshot.fromCallableMap(
      Map<String, dynamic>.from(data),
    );
  }
}
