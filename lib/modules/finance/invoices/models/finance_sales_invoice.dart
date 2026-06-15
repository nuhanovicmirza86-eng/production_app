import '../../shared/finance_callable_utils.dart';

class FinanceSalesInvoice {
  const FinanceSalesInvoice({
    required this.id,
    required this.companyId,
    required this.invoiceNumber,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.openAmount,
    required this.currency,
    this.customerId,
    this.customerName,
    this.netAmount,
    this.taxAmount,
    this.issueDate,
    this.dueDate,
    this.description,
    this.reference,
    this.plantKey,
    this.syncStatus,
    this.erpSyncKey,
    this.externalSystem,
    this.isOverdue = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String invoiceNumber;
  final String status;
  final double totalAmount;
  final double paidAmount;
  final double openAmount;
  final String currency;
  final String? customerId;
  final String? customerName;
  final double? netAmount;
  final double? taxAmount;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String? description;
  final String? reference;
  final String? plantKey;
  final String? syncStatus;
  final String? erpSyncKey;
  final String? externalSystem;
  final bool isOverdue;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDraft => status == 'draft';
  bool get isCancelled => status == 'cancelled';
  bool get isErpSynced =>
      (erpSyncKey ?? '').isNotEmpty ||
      ((syncStatus ?? '').trim().isNotEmpty &&
          (syncStatus ?? '').toLowerCase() != 'local');

  bool get canCancelDraftOrOpen =>
      (status == 'draft' || status == 'open') && paidAmount <= 0.005;

  factory FinanceSalesInvoice.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final map = Map<String, dynamic>.from(data);
    FinanceCallableUtils.normalizeTimestampFields(map, [
      'issueDate',
      'dueDate',
      'createdAt',
      'updatedAt',
      'issuedAt',
      'cancelledAt',
    ]);
    final docId = (map['documentId'] ?? id).toString();
    return FinanceSalesInvoice(
      id: docId,
      companyId: (map['companyId'] ?? '').toString(),
      invoiceNumber: (map['invoiceNumber'] ?? '').toString(),
      status: (map['status'] ?? '').toString().toLowerCase(),
      totalAmount: FinanceCallableUtils.parseAmount(map['totalAmount']),
      paidAmount: FinanceCallableUtils.parseAmount(map['paidAmount']),
      openAmount: FinanceCallableUtils.parseAmount(map['openAmount']),
      currency: (map['currency'] ?? '').toString(),
      customerId: map['customerId']?.toString(),
      customerName: map['customerName']?.toString(),
      netAmount: map['netAmount'] != null
          ? FinanceCallableUtils.parseAmount(map['netAmount'])
          : null,
      taxAmount: map['taxAmount'] != null
          ? FinanceCallableUtils.parseAmount(map['taxAmount'])
          : null,
      issueDate: map['issueDate'] as DateTime?,
      dueDate: map['dueDate'] as DateTime?,
      description: map['description']?.toString(),
      reference: map['reference']?.toString(),
      plantKey: map['plantKey']?.toString(),
      syncStatus: map['syncStatus']?.toString(),
      erpSyncKey: map['erpSyncKey']?.toString(),
      externalSystem: map['externalSystem']?.toString(),
      isOverdue: map['isOverdue'] == true,
      createdBy: map['createdBy']?.toString(),
      createdAt: map['createdAt'] as DateTime?,
      updatedAt: map['updatedAt'] as DateTime?,
    );
  }
}
