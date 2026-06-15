import '../../shared/finance_callable_utils.dart';

/// Planirana Cash Flow stavka — Callable sloj P3-M1.
class FinancePlannedCashItem {
  const FinancePlannedCashItem({
    required this.id,
    required this.companyId,
    required this.status,
    required this.direction,
    required this.cashFlowCategoryId,
    required this.nominalAmount,
    required this.currency,
    required this.expectedDate,
    required this.probabilityPercent,
    required this.probabilitySource,
    required this.description,
    this.weightedAmount = 0,
    this.plantKey,
    this.accountId,
    this.createdBy,
    this.createdByEmail,
    this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
  });

  final String id;
  final String companyId;
  final String status;
  final String direction;
  final String cashFlowCategoryId;
  final double nominalAmount;
  final String currency;
  final DateTime? expectedDate;
  final double probabilityPercent;
  final String probabilitySource;
  final String description;
  final double weightedAmount;
  final String? plantKey;
  final String? accountId;
  final String? createdBy;
  final String? createdByEmail;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelReason;

  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  factory FinancePlannedCashItem.fromCallableMap(Map<String, dynamic> raw) {
    final item = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(item, [
      'expectedDate',
      'createdAt',
      'updatedAt',
      'approvedAt',
      'cancelledAt',
    ]);
    final id = (item['documentId'] ?? item['id'] ?? '').toString();
    return FinancePlannedCashItem(
      id: id,
      companyId: (item['companyId'] ?? '').toString(),
      status: (item['status'] ?? '').toString(),
      direction: (item['direction'] ?? '').toString(),
      cashFlowCategoryId: (item['cashFlowCategoryId'] ?? '').toString(),
      nominalAmount: FinanceCallableUtils.parseAmount(item['nominalAmount']),
      currency: (item['currency'] ?? '').toString(),
      expectedDate: item['expectedDate'] as DateTime?,
      probabilityPercent:
          FinanceCallableUtils.parseAmount(item['probabilityPercent']),
      probabilitySource: (item['probabilitySource'] ?? '').toString(),
      description: (item['description'] ?? '').toString(),
      weightedAmount: FinanceCallableUtils.parseAmount(item['weightedAmount']),
      plantKey: item['plantKey']?.toString(),
      accountId: item['accountId']?.toString(),
      createdBy: item['createdBy']?.toString(),
      createdByEmail: item['createdByEmail']?.toString(),
      createdAt: item['createdAt'] as DateTime?,
      approvedAt: item['approvedAt'] as DateTime?,
      approvedBy: item['approvedBy']?.toString(),
      cancelledAt: item['cancelledAt'] as DateTime?,
      cancelledBy: item['cancelledBy']?.toString(),
      cancelReason: item['cancelReason']?.toString(),
    );
  }
}
