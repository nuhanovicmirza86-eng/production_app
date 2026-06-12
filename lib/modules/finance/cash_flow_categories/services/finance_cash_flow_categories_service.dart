import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_cash_flow_category.dart';

class FinanceCashFlowCategoriesService {
  FinanceCashFlowCategoriesService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  Future<List<FinanceCashFlowCategory>> listCategories({
    required String companyId,
    bool activeOnly = false,
    String? cashFlowActivityType,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final callable = _functions.httpsCallable('listFinanceCashFlowCategories');
    final response = await callable.call(<String, dynamic>{
      'companyId': cid,
      if (activeOnly) 'activeOnly': true,
      if (cashFlowActivityType != null && cashFlowActivityType.trim().isNotEmpty)
        'cashFlowActivityType': cashFlowActivityType.trim().toLowerCase(),
    });

    return _parseList(response.data);
  }

  Future<String> createCategory({
    required String companyId,
    required String categoryCode,
    required String name,
    required String cashFlowActivityType,
    int sortOrder = 0,
  }) async {
    final callable = _functions.httpsCallable('createFinanceCashFlowCategory');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'categoryCode': categoryCode.trim().toUpperCase(),
      'name': name.trim(),
      'cashFlowActivityType': cashFlowActivityType.trim().toLowerCase(),
      'sortOrder': sortOrder,
    });
    final data = response.data;
    if (data is Map) {
      return (data['categoryId'] ?? '').toString();
    }
    return '';
  }

  Future<void> updateCategory({
    required String companyId,
    required String categoryId,
    String? name,
    String? cashFlowActivityType,
    int? sortOrder,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('updateFinanceCashFlowCategory');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'categoryId': categoryId.trim(),
      if (name != null) 'name': name.trim(),
      if (cashFlowActivityType != null)
        'cashFlowActivityType': cashFlowActivityType.trim().toLowerCase(),
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<void> deactivateCategory({
    required String companyId,
    required String categoryId,
    String? reason,
  }) async {
    final callable =
        _functions.httpsCallable('deactivateFinanceCashFlowCategory');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'categoryId': categoryId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  List<FinanceCashFlowCategory> _parseList(dynamic data) {
    if (data is! Map) return const [];
    final rawItems = data['items'];
    if (rawItems is! List) return const [];

    final list = <FinanceCashFlowCategory>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      list.add(FinanceCashFlowCategory.fromCallableMap(id, item));
    }
    return list;
  }
}
