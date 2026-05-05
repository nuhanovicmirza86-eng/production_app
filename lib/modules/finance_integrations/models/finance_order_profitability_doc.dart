/// Jedan red profitabilnosti PN-a (`finance_order_profitability`).
class FinanceOrderProfitabilityDoc {
  const FinanceOrderProfitabilityDoc({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.productionOrderId,
    required this.orderCode,
    required this.revenue,
    required this.totalCost,
    required this.margin,
    required this.currency,
    required this.baseCurrency,
    this.sourceModule = '',
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String productionOrderId;
  final String orderCode;
  final double revenue;
  final double totalCost;
  final double margin;
  final String currency;
  final String baseCurrency;
  final String sourceModule;

  factory FinanceOrderProfitabilityDoc.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceOrderProfitabilityDoc(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      productionOrderId: (data['productionOrderId'] ?? '').toString(),
      orderCode: (data['orderCode'] ?? '').toString(),
      revenue: _d(data['revenue']),
      totalCost: _d(data['totalCost'] ?? data['total_cost']),
      margin: _d(data['margin'] ?? data['grossMargin']),
      currency: (data['currency'] ?? 'EUR').toString(),
      baseCurrency: (data['baseCurrency'] ?? data['currency'] ?? 'EUR').toString(),
      sourceModule: (data['sourceModule'] ?? '').toString(),
    );
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0;
  }
}
