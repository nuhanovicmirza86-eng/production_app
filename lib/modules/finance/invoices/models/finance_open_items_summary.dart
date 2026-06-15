import '../../shared/finance_callable_utils.dart';

/// Agregat iz [getFinanceOpenReceivablesSummary] / [getFinanceOpenPayablesSummary].
class FinanceOpenItemsSummary {
  const FinanceOpenItemsSummary({
    required this.companyId,
    required this.invoiceCount,
    required this.totalOpenAmount,
    required this.overdueCount,
    required this.overdueAmount,
  });

  final String companyId;
  final int invoiceCount;
  final double totalOpenAmount;
  final int overdueCount;
  final double overdueAmount;

  factory FinanceOpenItemsSummary.fromCallableMap(Map<String, dynamic> data) {
    return FinanceOpenItemsSummary(
      companyId: (data['companyId'] ?? '').toString(),
      invoiceCount: (data['invoiceCount'] as num?)?.toInt() ?? 0,
      totalOpenAmount: FinanceCallableUtils.parseAmount(data['totalOpenAmount']),
      overdueCount: (data['overdueCount'] as num?)?.toInt() ?? 0,
      overdueAmount: FinanceCallableUtils.parseAmount(data['overdueAmount']),
    );
  }
}
