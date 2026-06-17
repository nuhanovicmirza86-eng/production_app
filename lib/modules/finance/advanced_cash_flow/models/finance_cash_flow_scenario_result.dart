import '../../forecast/models/finance_cash_flow_forecast.dart';
import '../../shared/finance_callable_utils.dart';

/// Stavka računa u snapshot-u (iz backend [accountBreakdown]).
class FinanceCashFlowAccountBreakdownLine {
  const FinanceCashFlowAccountBreakdownLine({
    required this.accountId,
    required this.sourceCurrency,
    required this.sourceAmount,
    required this.baseCurrency,
    required this.baseCurrencyAmount,
    this.exchangeRate,
  });

  final String accountId;
  final String sourceCurrency;
  final double sourceAmount;
  final String baseCurrency;
  final double baseCurrencyAmount;
  final double? exchangeRate;

  factory FinanceCashFlowAccountBreakdownLine.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    return FinanceCashFlowAccountBreakdownLine(
      accountId: (raw['accountId'] ?? '').toString(),
      sourceCurrency: (raw['sourceCurrency'] ?? '').toString(),
      sourceAmount: FinanceCallableUtils.parseAmount(raw['sourceAmount']),
      baseCurrency: (raw['baseCurrency'] ?? '').toString(),
      baseCurrencyAmount:
          FinanceCallableUtils.parseAmount(raw['baseCurrencyAmount']),
      exchangeRate: raw['exchangeRate'] != null
          ? FinanceCallableUtils.parseAmount(raw['exchangeRate'])
          : null,
    );
  }
}

/// Snapshot prognoze ili izračunatog scenarija — samo parsiranje backend odgovora.
class FinanceCashFlowScenarioSnapshot {
  const FinanceCashFlowScenarioSnapshot({
    required this.baseCurrency,
    required this.bucketType,
    this.periodFrom,
    this.periodTo,
    required this.openingBalance,
    required this.minimumCashReserve,
    required this.buckets,
    required this.liquidityThreshold,
    required this.accountBreakdown,
  });

  final String baseCurrency;
  final String bucketType;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final double openingBalance;
  final double minimumCashReserve;
  final List<FinanceCashFlowForecastBucket> buckets;
  final FinanceLiquidityThreshold liquidityThreshold;
  final List<FinanceCashFlowAccountBreakdownLine> accountBreakdown;

  factory FinanceCashFlowScenarioSnapshot.fromCallableMap(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) {
      return FinanceCashFlowScenarioSnapshot(
        baseCurrency: '',
        bucketType: 'day',
        openingBalance: 0,
        minimumCashReserve: 0,
        buckets: const [],
        liquidityThreshold: FinanceLiquidityThreshold.fromCallableMap(null),
        accountBreakdown: const [],
      );
    }
    final item = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(item, [
      'periodFrom',
      'periodTo',
    ]);
    final bucketRaw = item['buckets'];
    final buckets = <FinanceCashFlowForecastBucket>[];
    if (bucketRaw is List) {
      for (final b in bucketRaw) {
        if (b is Map) {
          buckets.add(
            FinanceCashFlowForecastBucket.fromCallableMap(
              Map<String, dynamic>.from(b),
            ),
          );
        }
      }
    }
    final breakdownRaw = item['accountBreakdown'];
    final breakdown = <FinanceCashFlowAccountBreakdownLine>[];
    if (breakdownRaw is List) {
      for (final row in breakdownRaw) {
        if (row is Map) {
          breakdown.add(
            FinanceCashFlowAccountBreakdownLine.fromCallableMap(
              Map<String, dynamic>.from(row),
            ),
          );
        }
      }
    }
    return FinanceCashFlowScenarioSnapshot(
      baseCurrency: (item['baseCurrency'] ?? '').toString(),
      bucketType: (item['bucketType'] ?? 'day').toString(),
      periodFrom: item['periodFrom'] as DateTime?,
      periodTo: item['periodTo'] as DateTime?,
      openingBalance: FinanceCallableUtils.parseAmount(item['openingBalance']),
      minimumCashReserve:
          FinanceCallableUtils.parseAmount(item['minimumCashReserve']),
      buckets: buckets,
      liquidityThreshold: FinanceLiquidityThreshold.fromCallableMap(
        item['liquidityThreshold'] is Map
            ? Map<String, dynamic>.from(item['liquidityThreshold'] as Map)
            : null,
      ),
      accountBreakdown: breakdown,
    );
  }

  double get nominalClosingBalance {
    if (buckets.isEmpty) return openingBalance;
    return buckets.last.nominalClosingBalance;
  }

  double? get minimumNominalBalance =>
      liquidityThreshold.minimumNominalBalance;

  String? get minimumNominalBalanceDate =>
      liquidityThreshold.minimumNominalBalanceDate;

  bool get belowReserveWarning =>
      liquidityThreshold.firstNominalBelowReserveDate != null ||
      liquidityThreshold.nominalNegativeBalanceExpected;

  int get periodsBelowThreshold {
    final reserve = minimumCashReserve;
    if (reserve <= 0) return 0;
    var count = 0;
    for (final b in buckets) {
      if (b.nominalClosingBalance < reserve) count++;
    }
    return count;
  }

  double get totalProjectedInflows {
    var sum = 0.0;
    for (final b in buckets) {
      sum += b.actualInflows + b.plannedNominalInflows;
    }
    return sum;
  }

  double get totalProjectedOutflows {
    var sum = 0.0;
    for (final b in buckets) {
      sum += b.actualOutflows + b.plannedNominalOutflows;
    }
    return sum;
  }

  double get totalActualInflows {
    var sum = 0.0;
    for (final b in buckets) {
      sum += b.actualInflows;
    }
    return sum;
  }

  double get totalActualOutflows {
    var sum = 0.0;
    for (final b in buckets) {
      sum += b.actualOutflows;
    }
    return sum;
  }

  double get totalPlannedNominalInflows {
    var sum = 0.0;
    for (final b in buckets) {
      sum += b.plannedNominalInflows;
    }
    return sum;
  }

  double get totalPlannedNominalOutflows {
    var sum = 0.0;
    for (final b in buckets) {
      sum += b.plannedNominalOutflows;
    }
    return sum;
  }
}
