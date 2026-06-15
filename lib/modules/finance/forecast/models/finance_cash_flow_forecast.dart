import '../../shared/finance_callable_utils.dart';

/// Bucket iz [getFinanceCashFlowForecast] — nominalni i ponderisani tokovi odvojeni.
class FinanceCashFlowForecastBucket {
  const FinanceCashFlowForecastBucket({
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.actualInflows,
    required this.actualOutflows,
    required this.plannedNominalInflows,
    required this.plannedNominalOutflows,
    required this.plannedWeightedInflows,
    required this.plannedWeightedOutflows,
    required this.nominalClosingBalance,
    required this.weightedClosingBalance,
  });

  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double openingBalance;
  final double actualInflows;
  final double actualOutflows;
  final double plannedNominalInflows;
  final double plannedNominalOutflows;
  final double plannedWeightedInflows;
  final double plannedWeightedOutflows;
  final double nominalClosingBalance;
  final double weightedClosingBalance;

  factory FinanceCashFlowForecastBucket.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    final item = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(item, [
      'periodStart',
      'periodEnd',
    ]);
    return FinanceCashFlowForecastBucket(
      periodStart: item['periodStart'] as DateTime?,
      periodEnd: item['periodEnd'] as DateTime?,
      openingBalance: FinanceCallableUtils.parseAmount(item['openingBalance']),
      actualInflows: FinanceCallableUtils.parseAmount(item['actualInflows']),
      actualOutflows: FinanceCallableUtils.parseAmount(item['actualOutflows']),
      plannedNominalInflows:
          FinanceCallableUtils.parseAmount(item['plannedNominalInflows']),
      plannedNominalOutflows:
          FinanceCallableUtils.parseAmount(item['plannedNominalOutflows']),
      plannedWeightedInflows:
          FinanceCallableUtils.parseAmount(item['plannedWeightedInflows']),
      plannedWeightedOutflows:
          FinanceCallableUtils.parseAmount(item['plannedWeightedOutflows']),
      nominalClosingBalance:
          FinanceCallableUtils.parseAmount(item['nominalClosingBalance']),
      weightedClosingBalance:
          FinanceCallableUtils.parseAmount(item['weightedClosingBalance']),
    );
  }
}

/// Prag likvidnosti iz forecast odgovora.
class FinanceLiquidityThreshold {
  const FinanceLiquidityThreshold({
    required this.minimumCashReserve,
    this.firstNominalBelowReserveDate,
    this.firstWeightedBelowReserveDate,
    this.minimumNominalBalance,
    this.minimumNominalBalanceDate,
    this.minimumWeightedBalance,
    this.minimumWeightedBalanceDate,
    required this.nominalNegativeBalanceExpected,
    required this.weightedNegativeBalanceExpected,
  });

  final double minimumCashReserve;
  final String? firstNominalBelowReserveDate;
  final String? firstWeightedBelowReserveDate;
  final double? minimumNominalBalance;
  final String? minimumNominalBalanceDate;
  final double? minimumWeightedBalance;
  final String? minimumWeightedBalanceDate;
  final bool nominalNegativeBalanceExpected;
  final bool weightedNegativeBalanceExpected;

  factory FinanceLiquidityThreshold.fromCallableMap(Map<String, dynamic>? raw) {
    if (raw == null) {
      return const FinanceLiquidityThreshold(
        minimumCashReserve: 0,
        nominalNegativeBalanceExpected: false,
        weightedNegativeBalanceExpected: false,
      );
    }
    return FinanceLiquidityThreshold(
      minimumCashReserve:
          FinanceCallableUtils.parseAmount(raw['minimumCashReserve']),
      firstNominalBelowReserveDate:
          raw['firstNominalBelowReserveDate']?.toString(),
      firstWeightedBelowReserveDate:
          raw['firstWeightedBelowReserveDate']?.toString(),
      minimumNominalBalance: raw['minimumNominalBalance'] != null
          ? FinanceCallableUtils.parseAmount(raw['minimumNominalBalance'])
          : null,
      minimumNominalBalanceDate:
          raw['minimumNominalBalanceDate']?.toString(),
      minimumWeightedBalance: raw['minimumWeightedBalance'] != null
          ? FinanceCallableUtils.parseAmount(raw['minimumWeightedBalance'])
          : null,
      minimumWeightedBalanceDate:
          raw['minimumWeightedBalanceDate']?.toString(),
      nominalNegativeBalanceExpected:
          raw['nominalNegativeBalanceExpected'] == true,
      weightedNegativeBalanceExpected:
          raw['weightedNegativeBalanceExpected'] == true,
    );
  }
}

/// Odgovor Callable [getFinanceCashFlowForecast].
class FinanceCashFlowForecast {
  const FinanceCashFlowForecast({
    required this.companyId,
    required this.baseCurrency,
    required this.bucketType,
    this.periodFrom,
    this.periodTo,
    this.horizonDays,
    required this.accountIds,
    required this.openingBalance,
    required this.buckets,
    required this.liquidityThreshold,
    required this.minimumCashReserve,
  });

  final String companyId;
  final String baseCurrency;
  final String bucketType;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final int? horizonDays;
  final List<String> accountIds;
  final double openingBalance;
  final List<FinanceCashFlowForecastBucket> buckets;
  final FinanceLiquidityThreshold liquidityThreshold;
  final double minimumCashReserve;

  factory FinanceCashFlowForecast.fromCallableMap(Map<String, dynamic> raw) {
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
    final accountIdsRaw = item['accountIds'];
    final accountIds = <String>[];
    if (accountIdsRaw is List) {
      for (final id in accountIdsRaw) {
        final s = id?.toString().trim() ?? '';
        if (s.isNotEmpty) accountIds.add(s);
      }
    }
    return FinanceCashFlowForecast(
      companyId: (item['companyId'] ?? '').toString(),
      baseCurrency: (item['baseCurrency'] ?? '').toString(),
      bucketType: (item['bucketType'] ?? '').toString(),
      periodFrom: item['periodFrom'] as DateTime?,
      periodTo: item['periodTo'] as DateTime?,
      horizonDays: item['horizonDays'] is num
          ? (item['horizonDays'] as num).toInt()
          : int.tryParse(item['horizonDays']?.toString() ?? ''),
      accountIds: accountIds,
      openingBalance: FinanceCallableUtils.parseAmount(item['openingBalance']),
      buckets: buckets,
      liquidityThreshold: FinanceLiquidityThreshold.fromCallableMap(
        item['liquidityThreshold'] is Map
            ? Map<String, dynamic>.from(item['liquidityThreshold'] as Map)
            : null,
      ),
      minimumCashReserve:
          FinanceCallableUtils.parseAmount(item['minimumCashReserve']),
    );
  }
}
