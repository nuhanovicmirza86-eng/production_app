import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_planned_cash_item.dart';

class FinancePlannedCashItemsService {
  FinancePlannedCashItemsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  static String _dateToCallable(DateTime d) => d.toUtc().toIso8601String();

  Future<List<FinancePlannedCashItem>> listItems({
    required String companyId,
    String? status,
    String? direction,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 200,
  }) async {
    final callable = _functions.httpsCallable('listFinancePlannedCashItems');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (direction != null && direction.trim().isNotEmpty)
        'direction': direction.trim(),
      if (dateFrom != null) 'dateFrom': _dateToCallable(dateFrom),
      if (dateTo != null) 'dateTo': _dateToCallable(dateTo),
      'limit': limit,
    });
    return _parseList(response.data);
  }

  Future<FinancePlannedCashItem> getItem({
    required String companyId,
    required String plannedCashItemId,
  }) async {
    final callable = _functions.httpsCallable('getFinancePlannedCashItem');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'plannedCashItemId': plannedCashItemId.trim(),
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor getFinancePlannedCashItem');
    }
    return FinancePlannedCashItem.fromCallableMap(
      Map<String, dynamic>.from(data),
    );
  }

  Future<String> createItem({
    required String companyId,
    required String direction,
    required String cashFlowCategoryId,
    required double nominalAmount,
    required String currency,
    required DateTime expectedDate,
    required double probabilityPercent,
    required String probabilitySource,
    required String description,
    String? requestId,
    String? plantKey,
    String? accountId,
  }) async {
    final callable = _functions.httpsCallable('createFinancePlannedCashItem');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'direction': direction.trim().toLowerCase(),
      'cashFlowCategoryId': cashFlowCategoryId.trim(),
      'nominalAmount': nominalAmount,
      'currency': currency.trim().toUpperCase(),
      'expectedDate': _dateToCallable(expectedDate),
      'probabilityPercent': probabilityPercent,
      'probabilitySource': probabilitySource.trim().toLowerCase(),
      'description': description.trim(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      if (accountId != null && accountId.trim().isNotEmpty)
        'accountId': accountId.trim(),
    });
    final data = response.data;
    if (data is Map) {
      return (data['plannedCashItemId'] ?? '').toString();
    }
    return '';
  }

  Future<void> updateItem({
    required String companyId,
    required String plannedCashItemId,
    required String direction,
    required String cashFlowCategoryId,
    required double nominalAmount,
    required String currency,
    required DateTime expectedDate,
    required double probabilityPercent,
    required String probabilitySource,
    required String description,
    String? reason,
    String? plantKey,
    String? accountId,
  }) async {
    final callable = _functions.httpsCallable('updateFinancePlannedCashItem');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'plannedCashItemId': plannedCashItemId.trim(),
      'direction': direction.trim().toLowerCase(),
      'cashFlowCategoryId': cashFlowCategoryId.trim(),
      'nominalAmount': nominalAmount,
      'currency': currency.trim().toUpperCase(),
      'expectedDate': _dateToCallable(expectedDate),
      'probabilityPercent': probabilityPercent,
      'probabilitySource': probabilitySource.trim().toLowerCase(),
      'description': description.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      if (accountId != null && accountId.trim().isNotEmpty)
        'accountId': accountId.trim(),
    });
  }

  Future<void> approveItem({
    required String companyId,
    required String plannedCashItemId,
    String? reason,
    String? requestId,
  }) async {
    final callable = _functions.httpsCallable('approveFinancePlannedCashItem');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'plannedCashItemId': plannedCashItemId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
  }

  Future<void> cancelItem({
    required String companyId,
    required String plannedCashItemId,
    String? reason,
    String? requestId,
  }) async {
    final callable = _functions.httpsCallable('cancelFinancePlannedCashItem');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'plannedCashItemId': plannedCashItemId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
  }

  List<FinancePlannedCashItem> _parseList(dynamic data) {
    if (data is! Map) return const [];
    final itemsRaw = data['items'];
    if (itemsRaw is! List) return const [];
    return itemsRaw
        .whereType<Map>()
        .map(
          (m) => FinancePlannedCashItem.fromCallableMap(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList();
  }
}
