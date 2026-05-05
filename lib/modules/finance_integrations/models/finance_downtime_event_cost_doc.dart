/// Trošak zastoja u periodu KPI pipeline-a (`finance_downtime_event_costs`).
class FinanceDowntimeEventCostDoc {
  const FinanceDowntimeEventCostDoc({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.downtimeEventId,
    required this.estimatedDowntimeCost,
    required this.oeeMinutesInPeriod,
    required this.baseCurrency,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String downtimeEventId;
  final double estimatedDowntimeCost;
  final int oeeMinutesInPeriod;
  final String baseCurrency;

  factory FinanceDowntimeEventCostDoc.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceDowntimeEventCostDoc(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      downtimeEventId: (data['downtimeEventId'] ?? '').toString(),
      estimatedDowntimeCost: _d(
        data['estimatedDowntimeCost'] ?? data['estimated_downtime_cost'],
      ),
      oeeMinutesInPeriod: _i(data['oeeMinutesInPeriod']),
      baseCurrency: (data['baseCurrency'] ?? data['currency'] ?? 'EUR')
          .toString(),
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
