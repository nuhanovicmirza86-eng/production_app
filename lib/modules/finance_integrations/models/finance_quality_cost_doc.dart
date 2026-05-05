/// Red COPQ / kvaliteta (`finance_quality_costs`).
class FinanceQualityCostDoc {
  const FinanceQualityCostDoc({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.category,
    required this.amount,
    required this.currency,
    this.scrapQty = 0,
    this.reworkQty = 0,
    this.ncrClosedCount = 0,
    this.sourceModule = '',
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String category;
  final double amount;
  final String currency;
  final double scrapQty;
  final double reworkQty;
  final int ncrClosedCount;
  final String sourceModule;

  factory FinanceQualityCostDoc.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceQualityCostDoc(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      category: (data['category'] ?? '').toString(),
      amount: _d(data['amount'] ?? data['estimatedCost']),
      currency: (data['currency'] ?? 'EUR').toString(),
      scrapQty: _d(data['scrapQty'] ?? data['scrap_qty']),
      reworkQty: _d(data['reworkQty'] ?? data['rework_qty']),
      ncrClosedCount: _i(data['ncrClosedCount'] ?? data['copqQualityNcrClosedCount']),
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
