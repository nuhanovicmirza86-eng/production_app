/// Trošak rute / koraka (`finance_routing_operation_costs`).
class FinanceRoutingOperationCostDoc {
  const FinanceRoutingOperationCostDoc({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.aggregationLevel,
    required this.productionOrderId,
    required this.routingId,
    required this.stepOrder,
    required this.operationCode,
    required this.operationName,
    required this.routingMachineCost,
    required this.standardMinutesInPeriod,
    required this.baseCurrency,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String aggregationLevel;
  final String productionOrderId;
  final String routingId;
  final int stepOrder;
  final String operationCode;
  final String operationName;
  final double routingMachineCost;
  final double standardMinutesInPeriod;
  final String baseCurrency;

  bool get isRollup => aggregationLevel == 'routing_step_rollup';

  factory FinanceRoutingOperationCostDoc.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceRoutingOperationCostDoc(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      aggregationLevel: (data['aggregationLevel'] ?? '').toString(),
      productionOrderId: (data['productionOrderId'] ?? '').toString(),
      routingId: (data['routingId'] ?? '').toString(),
      stepOrder: _i(data['stepOrder']),
      operationCode: (data['operationCode'] ?? '').toString(),
      operationName: (data['operationName'] ?? '').toString(),
      routingMachineCost: _d(
        data['routingMachineCost'] ?? data['routing_machine_cost'],
      ),
      standardMinutesInPeriod: _d(data['standardMinutesInPeriod']),
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
