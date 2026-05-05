/// Trošak po radnom centru / zastoju (`finance_machine_costs`).
class FinanceMachineCostDoc {
  const FinanceMachineCostDoc({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.workCenterId,
    required this.workCenterCode,
    required this.workCenterName,
    required this.downtimeOeeMinutes,
    required this.totalCost,
    required this.downtimeCost,
    required this.maintenanceCost,
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
  final String workCenterId;
  final String workCenterCode;
  final String workCenterName;
  final int downtimeOeeMinutes;
  final double totalCost;
  final double downtimeCost;
  final double maintenanceCost;
  final String currency;
  final String baseCurrency;
  final String sourceModule;

  factory FinanceMachineCostDoc.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceMachineCostDoc(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      workCenterId: (data['workCenterId'] ?? '').toString(),
      workCenterCode: (data['workCenterCode'] ?? '').toString(),
      workCenterName: (data['workCenterName'] ?? '').toString(),
      downtimeOeeMinutes: _i(data['downtimeOeeMinutes'] ?? data['downtimeMinutes']),
      totalCost: _d(data['totalCost'] ?? data['total_cost']),
      downtimeCost: _d(data['downtimeCost'] ?? data['downtime_cost']),
      maintenanceCost: _d(data['maintenanceCost'] ?? data['maintenance_cost']),
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
