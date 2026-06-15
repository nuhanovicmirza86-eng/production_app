import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_payment_allocation.dart';

class FinancePaymentAllocationsService {
  FinancePaymentAllocationsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  List<FinancePaymentAllocation> _parseItems(dynamic data) {
    if (data is! Map) return const [];
    final raw = data['items'];
    if (raw is! List) return const [];
    return raw.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final id = (map['documentId'] ?? map['allocationId'] ?? '').toString();
      return FinancePaymentAllocation.fromCallableMap(id, map);
    }).toList();
  }

  Future<FinancePaymentAllocationListResult> getInvoiceAllocations({
    required String companyId,
    required String invoiceId,
    required String invoiceType,
    bool activeOnly = false,
    int limit = 50,
  }) async {
    final callable = _functions.httpsCallable('getFinanceInvoiceAllocations');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
      'invoiceType': invoiceType.trim().toLowerCase(),
      'activeOnly': activeOnly,
      'limit': limit,
    });
    final data = response.data;
    return FinancePaymentAllocationListResult(
      items: _parseItems(data),
      activeAllocatedTotal: data is Map
          ? _parseAmount(data['activeAllocatedTotal'])
          : 0,
    );
  }

  Future<FinancePaymentAllocationListResult> getTransactionAllocations({
    required String companyId,
    required String transactionId,
    bool activeOnly = false,
    int limit = 50,
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceTransactionAllocations');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
      'activeOnly': activeOnly,
      'limit': limit,
    });
    final data = response.data;
    return FinancePaymentAllocationListResult(
      items: _parseItems(data),
      activeAllocatedTotal: data is Map
          ? _parseAmount(data['activeAllocatedTotal'])
          : 0,
    );
  }

  Future<Map<String, dynamic>> allocatePayment({
    required String companyId,
    required String transactionId,
    required List<FinanceAllocationLineInput> lines,
    String? requestId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('allocateFinancePayment');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
      'lines': lines
          .map(
            (l) => <String, dynamic>{
              'invoiceType': l.invoiceType,
              'invoiceId': l.invoiceId,
              'allocatedAmount': l.allocatedAmount,
            },
          )
          .toList(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {};
  }

  Future<Map<String, dynamic>> cancelAllocation({
    required String companyId,
    required String allocationId,
    required String cancelReason,
    String? requestId,
  }) async {
    final callable =
        _functions.httpsCallable('cancelFinancePaymentAllocation');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'allocationId': allocationId.trim(),
      'cancelReason': cancelReason.trim(),
      if (requestId != null && requestId.trim().isNotEmpty)
        'requestId': requestId.trim(),
    });
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {};
  }

  static double _parseAmount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class FinanceAllocationLineInput {
  const FinanceAllocationLineInput({
    required this.invoiceType,
    required this.invoiceId,
    required this.allocatedAmount,
  });

  final String invoiceType;
  final String invoiceId;
  final double allocatedAmount;
}
