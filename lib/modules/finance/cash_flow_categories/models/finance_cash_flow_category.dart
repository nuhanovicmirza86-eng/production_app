/// Read model za `finance_cash_flow_categories`.
class FinanceCashFlowCategory {
  const FinanceCashFlowCategory({
    required this.id,
    required this.companyId,
    required this.categoryCode,
    required this.name,
    required this.cashFlowActivityType,
    required this.active,
    required this.sortOrder,
  });

  final String id;
  final String companyId;
  final String categoryCode;
  final String name;
  final String cashFlowActivityType;
  final bool active;
  final int sortOrder;

  factory FinanceCashFlowCategory.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final sortRaw = data['sortOrder'];
    final sortOrder = sortRaw is num ? sortRaw.toInt() : 0;
    return FinanceCashFlowCategory(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      categoryCode: (data['categoryCode'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      cashFlowActivityType:
          (data['cashFlowActivityType'] ?? '').toString().trim(),
      active: data['active'] != false,
      sortOrder: sortOrder,
    );
  }
}
