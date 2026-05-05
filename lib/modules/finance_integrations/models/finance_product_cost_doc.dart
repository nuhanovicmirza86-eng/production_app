/// Agregat troška po proizvodu (`finance_product_costs`).
class FinanceProductCostDoc {
  const FinanceProductCostDoc({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.productId,
    required this.productCode,
    required this.quantityProduced,
    required this.totalCost,
    required this.costPerUnit,
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
  final String productId;
  final String productCode;
  final double quantityProduced;
  final double totalCost;
  final double costPerUnit;
  final double margin;
  final String currency;
  final String baseCurrency;
  final String sourceModule;

  factory FinanceProductCostDoc.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceProductCostDoc(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      productId: (data['productId'] ?? '').toString(),
      productCode: (data['productCode'] ?? '').toString(),
      quantityProduced: _d(data['quantityProduced'] ?? data['quantity']),
      totalCost: _d(data['totalCost'] ?? data['total_cost']),
      costPerUnit: _d(data['costPerUnit'] ?? data['cost_per_unit']),
      margin: _d(data['margin']),
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
