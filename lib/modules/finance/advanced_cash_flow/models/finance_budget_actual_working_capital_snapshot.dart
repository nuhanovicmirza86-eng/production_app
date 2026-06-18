import '../../shared/finance_callable_utils.dart';

/// Odgovor Callable [getFinanceBudgetActualAndWorkingCapitalSnapshot] (finance-p5-m2-v1).
class FinanceBudgetActualWorkingCapitalSnapshot {
  const FinanceBudgetActualWorkingCapitalSnapshot({
    required this.success,
    required this.companyId,
    required this.periodFrom,
    required this.periodTo,
    required this.scopePlantKey,
    required this.scopeMode,
    required this.currency,
    required this.budgetActual,
    required this.workingCapital,
    required this.breakdownByPeriod,
    required this.breakdownByCategory,
    required this.breakdownByPlant,
    required this.sourceCoverage,
    required this.warnings,
    required this.calculationVersion,
    this.generatedAt,
  });

  final bool success;
  final String companyId;
  final String periodFrom;
  final String periodTo;
  final String? scopePlantKey;
  final String scopeMode;
  final String currency;
  final FinanceBudgetActualTotals budgetActual;
  final FinanceWorkingCapitalMetrics workingCapital;
  final List<FinanceBudgetActualBreakdownRow> breakdownByPeriod;
  final List<FinanceBudgetActualBreakdownRow> breakdownByCategory;
  final List<FinanceBudgetActualBreakdownRow> breakdownByPlant;
  final FinanceBawcSourceCoverage sourceCoverage;
  final List<FinanceBawcWarning> warnings;
  final String calculationVersion;
  final DateTime? generatedAt;

  factory FinanceBudgetActualWorkingCapitalSnapshot.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    final item = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(item, ['generatedAt']);

    final period = item['period'];
    final scope = item['scope'];
    final breakdowns = item['breakdowns'];

    return FinanceBudgetActualWorkingCapitalSnapshot(
      success: item['success'] == true,
      companyId: (item['companyId'] ?? '').toString(),
      periodFrom: period is Map
          ? (period['from'] ?? '').toString()
          : '',
      periodTo: period is Map ? (period['to'] ?? '').toString() : '',
      scopePlantKey: scope is Map
          ? _nullableString(scope['plantKey'])
          : null,
      scopeMode: scope is Map ? (scope['mode'] ?? '').toString() : '',
      currency: (item['currency'] ?? '').toString(),
      budgetActual: FinanceBudgetActualTotals.fromCallableMap(
        item['budgetActual'] is Map
            ? Map<String, dynamic>.from(item['budgetActual'] as Map)
            : const {},
      ),
      workingCapital: FinanceWorkingCapitalMetrics.fromCallableMap(
        item['workingCapital'] is Map
            ? Map<String, dynamic>.from(item['workingCapital'] as Map)
            : const {},
      ),
      breakdownByPeriod: _parseBreakdownList(
        breakdowns is Map ? breakdowns['byPeriod'] : null,
      ),
      breakdownByCategory: _parseBreakdownList(
        breakdowns is Map ? breakdowns['byCategory'] : null,
      ),
      breakdownByPlant: _parseBreakdownList(
        breakdowns is Map ? breakdowns['byPlant'] : null,
      ),
      sourceCoverage: FinanceBawcSourceCoverage.fromCallableMap(
        item['sourceCoverage'] is Map
            ? Map<String, dynamic>.from(item['sourceCoverage'] as Map)
            : const {},
      ),
      warnings: _parseWarnings(item['warnings']),
      calculationVersion: (item['calculationVersion'] ?? '').toString(),
      generatedAt: item['generatedAt'] is DateTime
          ? item['generatedAt'] as DateTime
          : FinanceCallableUtils.parseTimestamp(item['generatedAt']),
    );
  }

  static String? _nullableString(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<FinanceBudgetActualBreakdownRow> _parseBreakdownList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => FinanceBudgetActualBreakdownRow.fromCallableMap(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  static List<FinanceBawcWarning> _parseWarnings(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => FinanceBawcWarning.fromCallableMap(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }
}

class FinanceBudgetActualTotals {
  const FinanceBudgetActualTotals({
    required this.plannedInflow,
    required this.actualInflow,
    required this.inflowVarianceAmount,
    required this.inflowVariancePercent,
    required this.plannedOutflow,
    required this.actualOutflow,
    required this.outflowVarianceAmount,
    required this.outflowVariancePercent,
    required this.plannedNetCashFlow,
    required this.actualNetCashFlow,
    required this.netVarianceAmount,
    required this.netVariancePercent,
  });

  final double plannedInflow;
  final double actualInflow;
  final double inflowVarianceAmount;
  final double? inflowVariancePercent;
  final double plannedOutflow;
  final double actualOutflow;
  final double outflowVarianceAmount;
  final double? outflowVariancePercent;
  final double plannedNetCashFlow;
  final double actualNetCashFlow;
  final double netVarianceAmount;
  final double? netVariancePercent;

  factory FinanceBudgetActualTotals.fromCallableMap(Map<String, dynamic> raw) {
    return FinanceBudgetActualTotals(
      plannedInflow: FinanceCallableUtils.parseAmount(raw['plannedInflow']),
      actualInflow: FinanceCallableUtils.parseAmount(raw['actualInflow']),
      inflowVarianceAmount:
          FinanceCallableUtils.parseAmount(raw['inflowVarianceAmount']),
      inflowVariancePercent: _nullablePercent(raw['inflowVariancePercent']),
      plannedOutflow: FinanceCallableUtils.parseAmount(raw['plannedOutflow']),
      actualOutflow: FinanceCallableUtils.parseAmount(raw['actualOutflow']),
      outflowVarianceAmount:
          FinanceCallableUtils.parseAmount(raw['outflowVarianceAmount']),
      outflowVariancePercent: _nullablePercent(raw['outflowVariancePercent']),
      plannedNetCashFlow:
          FinanceCallableUtils.parseAmount(raw['plannedNetCashFlow']),
      actualNetCashFlow:
          FinanceCallableUtils.parseAmount(raw['actualNetCashFlow']),
      netVarianceAmount:
          FinanceCallableUtils.parseAmount(raw['netVarianceAmount']),
      netVariancePercent: _nullablePercent(raw['netVariancePercent']),
    );
  }

  static double? _nullablePercent(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class FinanceWorkingCapitalMetrics {
  const FinanceWorkingCapitalMetrics({
    required this.dsoPeriodEnd,
    required this.dsoCollectionDaysAverage,
    required this.dpoPeriodEnd,
    required this.dpoPaymentDaysAverage,
    required this.dio,
    required this.ccc,
    required this.dioAvailability,
    required this.cccAvailability,
    this.dsoCollectionDaysAverageReason,
    this.dpoPaymentDaysAverageReason,
  });

  final double? dsoPeriodEnd;
  final double? dsoCollectionDaysAverage;
  final double? dpoPeriodEnd;
  final double? dpoPaymentDaysAverage;
  final double? dio;
  final double? ccc;
  final String? dioAvailability;
  final String? cccAvailability;
  final String? dsoCollectionDaysAverageReason;
  final String? dpoPaymentDaysAverageReason;

  factory FinanceWorkingCapitalMetrics.fromCallableMap(Map<String, dynamic> raw) {
    return FinanceWorkingCapitalMetrics(
      dsoPeriodEnd: _nullableNum(raw['dsoPeriodEnd']),
      dsoCollectionDaysAverage:
          _nullableNum(raw['dsoCollectionDaysAverage']),
      dpoPeriodEnd: _nullableNum(raw['dpoPeriodEnd']),
      dpoPaymentDaysAverage: _nullableNum(raw['dpoPaymentDaysAverage']),
      dio: _nullableNum(raw['dio']),
      ccc: _nullableNum(raw['ccc']),
      dioAvailability: FinanceBudgetActualWorkingCapitalSnapshot._nullableString(
        raw['dioAvailability'],
      ),
      cccAvailability: FinanceBudgetActualWorkingCapitalSnapshot._nullableString(
        raw['cccAvailability'],
      ),
      dsoCollectionDaysAverageReason:
          FinanceBudgetActualWorkingCapitalSnapshot._nullableString(
        raw['dsoCollectionDaysAverageReason'],
      ),
      dpoPaymentDaysAverageReason:
          FinanceBudgetActualWorkingCapitalSnapshot._nullableString(
        raw['dpoPaymentDaysAverageReason'],
      ),
    );
  }

  static double? _nullableNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

class FinanceBudgetActualBreakdownRow {
  const FinanceBudgetActualBreakdownRow({
    required this.key,
    required this.totals,
    this.categoryId,
    this.categoryName,
    this.plantKey,
  });

  final String key;
  final FinanceBudgetActualTotals totals;
  final String? categoryId;
  final String? categoryName;
  final String? plantKey;

  factory FinanceBudgetActualBreakdownRow.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    return FinanceBudgetActualBreakdownRow(
      key: (raw['key'] ?? '').toString(),
      totals: FinanceBudgetActualTotals.fromCallableMap(raw),
      categoryId: FinanceBudgetActualWorkingCapitalSnapshot._nullableString(
        raw['categoryId'],
      ),
      categoryName: FinanceBudgetActualWorkingCapitalSnapshot._nullableString(
        raw['categoryName'],
      ),
      plantKey: FinanceBudgetActualWorkingCapitalSnapshot._nullableString(
        raw['plantKey'],
      ),
    );
  }
}

class FinanceBawcSourceCoverage {
  const FinanceBawcSourceCoverage({
    required this.budgetLinesIncluded,
    required this.budgetLinesExcluded,
    required this.cashTransactionsIncluded,
    required this.salesInvoicesIncluded,
    required this.purchaseInvoicesIncluded,
    required this.allocationsIncluded,
  });

  final int budgetLinesIncluded;
  final int budgetLinesExcluded;
  final int cashTransactionsIncluded;
  final int salesInvoicesIncluded;
  final int purchaseInvoicesIncluded;
  final int allocationsIncluded;

  factory FinanceBawcSourceCoverage.fromCallableMap(Map<String, dynamic> raw) {
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return FinanceBawcSourceCoverage(
      budgetLinesIncluded: i(raw['budgetLinesIncluded']),
      budgetLinesExcluded: i(raw['budgetLinesExcluded']),
      cashTransactionsIncluded: i(raw['cashTransactionsIncluded']),
      salesInvoicesIncluded: i(raw['salesInvoicesIncluded']),
      purchaseInvoicesIncluded: i(raw['purchaseInvoicesIncluded']),
      allocationsIncluded: i(raw['allocationsIncluded']),
    );
  }
}

class FinanceBawcWarning {
  const FinanceBawcWarning({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final String severity;

  factory FinanceBawcWarning.fromCallableMap(Map<String, dynamic> raw) {
    return FinanceBawcWarning(
      code: (raw['code'] ?? '').toString(),
      message: (raw['message'] ?? '').toString(),
      severity: (raw['severity'] ?? '').toString(),
    );
  }
}
