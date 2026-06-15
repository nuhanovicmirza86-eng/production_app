import '../../shared/finance_callable_utils.dart';

class FinancePaymentAllocation {
  const FinancePaymentAllocation({
    required this.id,
    required this.companyId,
    required this.allocationCode,
    required this.transactionId,
    required this.invoiceType,
    required this.invoiceId,
    required this.allocatedAmount,
    required this.currency,
    required this.status,
    this.baseCurrencyAmount = 0,
    this.allocatedAt,
    this.allocatedBy,
    this.allocatedByEmail,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelledByEmail,
    this.cancelReason,
    this.transactionCode,
    this.invoiceNumber,
    this.partnerId,
    this.partnerName,
    this.createdBy,
    this.createdByEmail,
  });

  final String id;
  final String companyId;
  final String allocationCode;
  final String transactionId;
  final String invoiceType;
  final String invoiceId;
  final double allocatedAmount;
  final String currency;
  final double baseCurrencyAmount;
  final String status;
  final DateTime? allocatedAt;
  final String? allocatedBy;
  final String? allocatedByEmail;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelledByEmail;
  final String? cancelReason;
  final String? transactionCode;
  final String? invoiceNumber;
  final String? partnerId;
  final String? partnerName;
  final String? createdBy;
  final String? createdByEmail;

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';

  factory FinancePaymentAllocation.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    FinanceCallableUtils.normalizeTimestampFields(data, [
      'allocatedAt',
      'cancelledAt',
      'createdAt',
      'updatedAt',
    ]);
    final docId = (data['documentId'] ?? id).toString().trim();
    return FinancePaymentAllocation(
      id: docId.isNotEmpty ? docId : id,
      companyId: (data['companyId'] ?? '').toString(),
      allocationCode: (data['allocationCode'] ?? '').toString(),
      transactionId: (data['transactionId'] ?? '').toString(),
      invoiceType: (data['invoiceType'] ?? '').toString().trim().toLowerCase(),
      invoiceId: (data['invoiceId'] ?? '').toString(),
      allocatedAmount:
          FinanceCallableUtils.parseAmount(data['allocatedAmount']),
      currency: (data['currency'] ?? '').toString().trim().toUpperCase(),
      baseCurrencyAmount:
          FinanceCallableUtils.parseAmount(data['baseCurrencyAmount']),
      status: (data['status'] ?? '').toString().trim().toLowerCase(),
      allocatedAt: data['allocatedAt'] as DateTime?,
      allocatedBy: _opt(data['allocatedBy']),
      allocatedByEmail: _opt(data['allocatedByEmail']),
      cancelledAt: data['cancelledAt'] as DateTime?,
      cancelledBy: _opt(data['cancelledBy']),
      cancelledByEmail: _opt(data['cancelledByEmail']),
      cancelReason: _opt(data['cancelReason']),
      transactionCode: _opt(data['transactionCode']),
      invoiceNumber: _opt(data['invoiceNumber']),
      partnerId: _opt(data['partnerId']),
      partnerName: _opt(data['partnerName']),
      createdBy: _opt(data['createdBy']),
      createdByEmail: _opt(data['createdByEmail']),
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}

class FinancePaymentAllocationListResult {
  const FinancePaymentAllocationListResult({
    required this.items,
    required this.activeAllocatedTotal,
  });

  final List<FinancePaymentAllocation> items;
  final double activeAllocatedTotal;
}
