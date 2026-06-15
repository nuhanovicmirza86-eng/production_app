import '../../shared/finance_callable_utils.dart';

class FinanceCashTransaction {
  const FinanceCashTransaction({
    required this.id,
    required this.companyId,
    required this.transactionCode,
    required this.status,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.baseCurrencyAmount,
    required this.accountId,
    required this.cashFlowCategoryId,
    this.cashFlowCategoryCode,
    this.cashFlowActivityType,
    this.exchangeRate = 1,
    this.transactionDate,
    this.valueDate,
    this.description,
    this.reference,
    this.sourceType,
    this.plantKey,
    this.isActual = false,
    this.isForecast = false,
    this.reversalTransactionId,
    this.reversalOfTransactionId,
    this.createdBy,
    this.createdByEmail,
    this.postedBy,
    this.postedByEmail,
    this.reconciledBy,
    this.reconciledByEmail,
    this.postedAt,
    this.reconciledAt,
    this.allocatedAmount = 0,
    this.unallocatedAmount,
  });

  final String id;
  final String companyId;
  final String transactionCode;
  final String status;
  final String direction;
  final double amount;
  final String currency;
  final double baseCurrencyAmount;
  final double exchangeRate;
  final String accountId;
  final String cashFlowCategoryId;
  final String? cashFlowCategoryCode;
  final String? cashFlowActivityType;
  final DateTime? transactionDate;
  final DateTime? valueDate;
  final String? description;
  final String? reference;
  final String? sourceType;
  final String? plantKey;
  final bool isActual;
  final bool isForecast;
  final String? reversalTransactionId;
  final String? reversalOfTransactionId;
  final String? createdBy;
  final String? createdByEmail;
  final String? postedBy;
  final String? postedByEmail;
  final String? reconciledBy;
  final String? reconciledByEmail;
  final DateTime? postedAt;
  final DateTime? reconciledAt;
  final double allocatedAmount;
  final double? unallocatedAmount;

  bool get isDraft => status == 'draft' || status == 'planned';
  bool get isPosted => status == 'posted';
  bool get isReconciled => status == 'reconciled';
  bool get isCancelled => status == 'cancelled';
  bool get isPostedLike => isPosted || isReconciled;
  bool get hasReversal => (reversalTransactionId ?? '').isNotEmpty;
  bool get isReversal => (reversalOfTransactionId ?? '').isNotEmpty;

  double get effectiveUnallocatedAmount {
    if (unallocatedAmount != null) return unallocatedAmount!;
    return FinanceCallableUtils.parseAmount(amount) -
        FinanceCallableUtils.parseAmount(allocatedAmount);
  }

  bool get canAllocateToInvoices =>
      isPostedLike &&
      isActual &&
      !isReversal &&
      effectiveUnallocatedAmount > 0.005;

  factory FinanceCashTransaction.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    FinanceCallableUtils.normalizeTimestampFields(data, [
      'transactionDate',
      'valueDate',
      'postedAt',
      'reconciledAt',
      'createdAt',
      'updatedAt',
    ]);
    return FinanceCashTransaction(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      transactionCode: (data['transactionCode'] ?? '').toString().trim(),
      status: (data['status'] ?? '').toString().trim().toLowerCase(),
      direction: (data['direction'] ?? '').toString().trim().toLowerCase(),
      amount: FinanceCallableUtils.parseAmount(data['amount']),
      currency: (data['currency'] ?? '').toString().trim().toUpperCase(),
      baseCurrencyAmount:
          FinanceCallableUtils.parseAmount(data['baseCurrencyAmount']),
      exchangeRate: FinanceCallableUtils.parseAmount(data['exchangeRate'] ?? 1),
      accountId: (data['accountId'] ?? '').toString(),
      cashFlowCategoryId: (data['cashFlowCategoryId'] ?? '').toString(),
      cashFlowCategoryCode: _opt(data['cashFlowCategoryCode']),
      cashFlowActivityType: _opt(data['cashFlowActivityType']),
      transactionDate: data['transactionDate'] as DateTime?,
      valueDate: data['valueDate'] as DateTime?,
      description: _opt(data['description']),
      reference: _opt(data['reference']),
      sourceType: _opt(data['sourceType']),
      plantKey: _opt(data['plantKey']),
      isActual: data['isActual'] == true,
      isForecast: data['isForecast'] == true,
      reversalTransactionId: _opt(data['reversalTransactionId']),
      reversalOfTransactionId: _opt(data['reversalOfTransactionId']),
      createdBy: _opt(data['createdBy']),
      createdByEmail: _opt(data['createdByEmail']),
      postedBy: _opt(data['postedBy']),
      postedByEmail: _opt(data['postedByEmail']),
      reconciledBy: _opt(data['reconciledBy']),
      reconciledByEmail: _opt(data['reconciledByEmail']),
      postedAt: data['postedAt'] as DateTime?,
      reconciledAt: data['reconciledAt'] as DateTime?,
      allocatedAmount: FinanceCallableUtils.parseAmount(data['allocatedAmount']),
      unallocatedAmount: data.containsKey('unallocatedAmount')
          ? FinanceCallableUtils.parseAmount(data['unallocatedAmount'])
          : null,
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
