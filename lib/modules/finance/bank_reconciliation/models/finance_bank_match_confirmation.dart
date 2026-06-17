import '../../shared/finance_callable_utils.dart';

class FinanceBankMatchAllocationLine {
  const FinanceBankMatchAllocationLine({
    required this.allocationId,
    required this.invoiceType,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.allocatedAmount,
    required this.currency,
    this.allocationCode,
  });

  final String allocationId;
  final String invoiceType;
  final String invoiceId;
  final String invoiceNumber;
  final double allocatedAmount;
  final String currency;
  final String? allocationCode;

  factory FinanceBankMatchAllocationLine.fromMap(Map<String, dynamic> map) {
    return FinanceBankMatchAllocationLine(
      allocationId: (map['allocationId'] ?? '').toString(),
      invoiceType: (map['invoiceType'] ?? '').toString().trim().toLowerCase(),
      invoiceId: (map['invoiceId'] ?? '').toString(),
      invoiceNumber: (map['invoiceNumber'] ?? '').toString().trim(),
      allocatedAmount:
          FinanceCallableUtils.parseAmount(map['allocatedAmount']),
      currency: (map['currency'] ?? '').toString().trim().toUpperCase(),
      allocationCode: _opt(map['allocationCode']),
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}

class FinanceBankMatchConfirmation {
  const FinanceBankMatchConfirmation({
    required this.id,
    required this.companyId,
    required this.status,
    required this.bankStatementTransactionId,
    required this.cashTransactionId,
    required this.totalBankAmount,
    required this.totalAllocatedAmount,
    required this.unallocatedAmount,
    required this.currency,
    required this.direction,
    required this.reconciliationStatus,
    required this.allocationLines,
    this.confirmationCode,
    this.suggestionId,
    this.confirmedBy,
    this.confirmedByEmail,
    this.confirmedAt,
    this.confirmReason,
    this.cancelReason,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelledByEmail,
    this.reversalCashTransactionId,
    this.cashTransactionCode,
    this.cashTransactionDisplay,
    this.reversalTransactionCode,
    this.reversalTransactionDisplay,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String status;
  final String bankStatementTransactionId;
  final String cashTransactionId;
  final double totalBankAmount;
  final double totalAllocatedAmount;
  final double unallocatedAmount;
  final String currency;
  final String direction;
  final String reconciliationStatus;
  final List<FinanceBankMatchAllocationLine> allocationLines;
  final String? confirmationCode;
  final String? suggestionId;
  final String? confirmedBy;
  final String? confirmedByEmail;
  final DateTime? confirmedAt;
  final String? confirmReason;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelledByEmail;
  final String? reversalCashTransactionId;
  final String? cashTransactionCode;
  final String? cashTransactionDisplay;
  final String? reversalTransactionCode;
  final String? reversalTransactionDisplay;
  final DateTime? createdAt;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isFullyReconciled =>
      reconciliationStatus.toLowerCase() == 'reconciled';
  bool get isPartiallyReconciled =>
      reconciliationStatus.toLowerCase() == 'partially_reconciled';

  String? get displayTitle {
    if (confirmationCode != null && confirmationCode!.isNotEmpty) {
      return confirmationCode;
    }
    return null;
  }

  String? get cashTransactionLabel {
    if (cashTransactionDisplay != null && cashTransactionDisplay!.isNotEmpty) {
      return cashTransactionDisplay;
    }
    if (cashTransactionCode != null && cashTransactionCode!.isNotEmpty) {
      return cashTransactionCode;
    }
    return null;
  }

  String? get reversalTransactionLabel {
    if (reversalTransactionDisplay != null &&
        reversalTransactionDisplay!.isNotEmpty) {
      return reversalTransactionDisplay;
    }
    if (reversalTransactionCode != null && reversalTransactionCode!.isNotEmpty) {
      return reversalTransactionCode;
    }
    return null;
  }

  factory FinanceBankMatchConfirmation.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final map = Map<String, dynamic>.from(data);
    FinanceCallableUtils.normalizeTimestampFields(map, [
      'confirmedAt',
      'cancelledAt',
      'createdAt',
      'updatedAt',
    ]);
    final rawLines = map['allocationLines'];
    final lines = <FinanceBankMatchAllocationLine>[];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map) {
          lines.add(
            FinanceBankMatchAllocationLine.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    return FinanceBankMatchConfirmation(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      status: (map['status'] ?? '').toString().trim().toLowerCase(),
      bankStatementTransactionId:
          (map['bankStatementTransactionId'] ?? '').toString(),
      cashTransactionId: (map['cashTransactionId'] ?? '').toString(),
      totalBankAmount: FinanceCallableUtils.parseAmount(map['totalBankAmount']),
      totalAllocatedAmount:
          FinanceCallableUtils.parseAmount(map['totalAllocatedAmount']),
      unallocatedAmount:
          FinanceCallableUtils.parseAmount(map['unallocatedAmount']),
      currency: (map['currency'] ?? '').toString().trim().toUpperCase(),
      direction: (map['direction'] ?? '').toString().trim().toLowerCase(),
      reconciliationStatus:
          (map['reconciliationStatus'] ?? '').toString().trim().toLowerCase(),
      allocationLines: lines,
      confirmationCode: _opt(map['confirmationCode']),
      suggestionId: _opt(map['suggestionId']),
      confirmedBy: _opt(map['confirmedBy']),
      confirmedByEmail: _opt(map['confirmedByEmail']),
      confirmedAt: FinanceCallableUtils.parseTimestamp(map['confirmedAt']),
      confirmReason: _opt(map['confirmReason']),
      cancelReason: _opt(map['cancelReason']),
      cancelledAt: FinanceCallableUtils.parseTimestamp(map['cancelledAt']),
      cancelledBy: _opt(map['cancelledBy']),
      cancelledByEmail: _opt(map['cancelledByEmail']),
      reversalCashTransactionId: _opt(
        map['reversalCashTransactionId'] ?? map['reversalTransactionId'],
      ),
      cashTransactionCode: _opt(map['cashTransactionCode']),
      cashTransactionDisplay: _opt(map['cashTransactionDisplay']),
      reversalTransactionCode: _opt(map['reversalTransactionCode']),
      reversalTransactionDisplay: _opt(map['reversalTransactionDisplay']),
      createdAt: FinanceCallableUtils.parseTimestamp(map['createdAt']),
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
