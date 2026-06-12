import '../../shared/finance_callable_utils.dart';

class FinanceActivityCashFlow {
  const FinanceActivityCashFlow({
    required this.inflows,
    required this.outflows,
  });

  final double inflows;
  final double outflows;

  double get net => inflows - outflows;

  factory FinanceActivityCashFlow.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const FinanceActivityCashFlow(inflows: 0, outflows: 0);
    return FinanceActivityCashFlow(
      inflows: FinanceCallableUtils.parseAmount(data['inflows']),
      outflows: FinanceCallableUtils.parseAmount(data['outflows']),
    );
  }
}

/// Odgovor Callable [getRealizedCashFlowSummary] — jedini izvor istine za UI.
class FinanceRealizedCashFlowSummary {
  const FinanceRealizedCashFlowSummary({
    required this.companyId,
    required this.currency,
    required this.openingBalance,
    required this.totalInflows,
    required this.totalOutflows,
    required this.netCashFlow,
    required this.closingBalance,
    required this.transactionCount,
    required this.operating,
    required this.investing,
    required this.financing,
    this.accountId,
    this.dateFrom,
    this.dateTo,
  });

  final String companyId;
  final String? currency;
  final String? accountId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double openingBalance;
  final double totalInflows;
  final double totalOutflows;
  final double netCashFlow;
  final double closingBalance;
  final int transactionCount;
  final FinanceActivityCashFlow operating;
  final FinanceActivityCashFlow investing;
  final FinanceActivityCashFlow financing;

  factory FinanceRealizedCashFlowSummary.fromCallable(dynamic data) {
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor getRealizedCashFlowSummary');
    }
    final m = Map<String, dynamic>.from(data);
    final byActivity = m['byActivity'];
    Map<String, dynamic> act = {};
    if (byActivity is Map) {
      act = Map<String, dynamic>.from(byActivity);
    }
    return FinanceRealizedCashFlowSummary(
      companyId: (m['companyId'] ?? '').toString(),
      currency: _optString(m['currency']),
      accountId: _optString(m['accountId']),
      dateFrom: FinanceCallableUtils.parseTimestamp(m['dateFrom']),
      dateTo: FinanceCallableUtils.parseTimestamp(m['dateTo']),
      openingBalance: FinanceCallableUtils.parseAmount(m['openingBalance']),
      totalInflows: FinanceCallableUtils.parseAmount(m['totalInflows']),
      totalOutflows: FinanceCallableUtils.parseAmount(m['totalOutflows']),
      netCashFlow: FinanceCallableUtils.parseAmount(m['netCashFlow']),
      closingBalance: FinanceCallableUtils.parseAmount(m['closingBalance']),
      transactionCount: (m['transactionCount'] is num)
          ? (m['transactionCount'] as num).toInt()
          : 0,
      operating: FinanceActivityCashFlow.fromMap(
        act['operating'] is Map
            ? Map<String, dynamic>.from(act['operating'] as Map)
            : null,
      ),
      investing: FinanceActivityCashFlow.fromMap(
        act['investing'] is Map
            ? Map<String, dynamic>.from(act['investing'] as Map)
            : null,
      ),
      financing: FinanceActivityCashFlow.fromMap(
        act['financing'] is Map
            ? Map<String, dynamic>.from(act['financing'] as Map)
            : null,
      ),
    );
  }
}

String? _optString(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}
