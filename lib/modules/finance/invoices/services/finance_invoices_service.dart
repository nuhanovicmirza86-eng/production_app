import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_open_items_summary.dart';
import '../models/finance_purchase_invoice.dart';
import '../models/finance_sales_invoice.dart';

class FinanceInvoicesService {
  FinanceInvoicesService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  static String _dateToCallable(DateTime d) =>
      DateTime(d.year, d.month, d.day, 12).toUtc().toIso8601String();

  List<FinanceSalesInvoice> _parseSalesList(dynamic data) {
    if (data is! Map) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return items.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final id = (map['documentId'] ?? '').toString();
      return FinanceSalesInvoice.fromCallableMap(id, map);
    }).toList();
  }

  List<FinancePurchaseInvoice> _parsePurchaseList(dynamic data) {
    if (data is! Map) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return items.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final id = (map['documentId'] ?? '').toString();
      return FinancePurchaseInvoice.fromCallableMap(id, map);
    }).toList();
  }

  Future<List<FinanceSalesInvoice>> listSalesInvoices({
    required String companyId,
    String? status,
    bool openOnly = false,
    bool overdueOnly = false,
    String? customerId,
    int limit = 200,
  }) async {
    final callable = _functions.httpsCallable('listFinanceSalesInvoices');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (openOnly) 'openOnly': true,
      if (overdueOnly) 'overdueOnly': true,
      if (customerId != null && customerId.trim().isNotEmpty)
        'customerId': customerId.trim(),
      'limit': limit,
    });
    return _parseSalesList(response.data);
  }

  Future<FinanceSalesInvoice> getSalesInvoice({
    required String companyId,
    required String invoiceId,
  }) async {
    final map = await getSalesInvoiceRaw(
      companyId: companyId,
      invoiceId: invoiceId,
    );
    final id = (map['documentId'] ?? invoiceId).toString();
    return FinanceSalesInvoice.fromCallableMap(id, map);
  }

  Future<Map<String, dynamic>> getSalesInvoiceRaw({
    required String companyId,
    required String invoiceId,
  }) async {
    final callable = _functions.httpsCallable('getFinanceSalesInvoice');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> createSalesDraft({
    required String companyId,
    String? customerId,
    String? customerName,
    String? currency,
    double? netAmount,
    double? taxAmount,
    double? totalAmount,
    String? description,
    String? reference,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('createFinanceSalesInvoiceDraft');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (customerId != null && customerId.trim().isNotEmpty)
        'customerId': customerId.trim(),
      if (customerName != null && customerName.trim().isNotEmpty)
        'customerName': customerName.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim().toUpperCase(),
      if (netAmount != null) 'netAmount': netAmount,
      if (taxAmount != null) 'taxAmount': taxAmount,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (reference != null && reference.trim().isNotEmpty)
        'reference': reference.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
    });
    final data = response.data;
    if (data is Map) return (data['invoiceId'] ?? '').toString();
    return '';
  }

  Future<void> updateSalesDraft({
    required String companyId,
    required String invoiceId,
    String? customerId,
    String? customerName,
    String? currency,
    double? netAmount,
    double? taxAmount,
    double? totalAmount,
    String? description,
    String? reference,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('updateFinanceSalesInvoiceDraft');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
      if (customerId != null) 'customerId': customerId.trim(),
      if (customerName != null) 'customerName': customerName.trim(),
      if (currency != null) 'currency': currency.trim().toUpperCase(),
      if (netAmount != null) 'netAmount': netAmount,
      if (taxAmount != null) 'taxAmount': taxAmount,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (description != null) 'description': description.trim(),
      if (reference != null) 'reference': reference.trim(),
      if (plantKey != null) 'plantKey': plantKey.trim(),
    });
  }

  Future<void> issueSalesInvoice({
    required String companyId,
    required String invoiceId,
    required DateTime dueDate,
    DateTime? issueDate,
  }) async {
    final callable = _functions.httpsCallable('issueFinanceSalesInvoice');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
      'dueDate': _dateToCallable(dueDate),
      if (issueDate != null) 'issueDate': _dateToCallable(issueDate),
    });
  }

  Future<void> cancelSalesInvoice({
    required String companyId,
    required String invoiceId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('cancelFinanceSalesInvoice');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<List<FinancePurchaseInvoice>> listPurchaseInvoices({
    required String companyId,
    String? status,
    bool openOnly = false,
    bool overdueOnly = false,
    String? supplierId,
    int limit = 200,
  }) async {
    final callable = _functions.httpsCallable('listFinancePurchaseInvoices');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (openOnly) 'openOnly': true,
      if (overdueOnly) 'overdueOnly': true,
      if (supplierId != null && supplierId.trim().isNotEmpty)
        'supplierId': supplierId.trim(),
      'limit': limit,
    });
    return _parsePurchaseList(response.data);
  }

  Future<FinancePurchaseInvoice> getPurchaseInvoice({
    required String companyId,
    required String invoiceId,
  }) async {
    final map = await getPurchaseInvoiceRaw(
      companyId: companyId,
      invoiceId: invoiceId,
    );
    final id = (map['documentId'] ?? invoiceId).toString();
    return FinancePurchaseInvoice.fromCallableMap(id, map);
  }

  Future<Map<String, dynamic>> getPurchaseInvoiceRaw({
    required String companyId,
    required String invoiceId,
  }) async {
    final callable = _functions.httpsCallable('getFinancePurchaseInvoice');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> createPurchaseDraft({
    required String companyId,
    String? supplierId,
    String? supplierName,
    String? currency,
    double? netAmount,
    double? taxAmount,
    double? totalAmount,
    String? description,
    String? reference,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('createFinancePurchaseInvoiceDraft');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (supplierId != null && supplierId.trim().isNotEmpty)
        'supplierId': supplierId.trim(),
      if (supplierName != null && supplierName.trim().isNotEmpty)
        'supplierName': supplierName.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim().toUpperCase(),
      if (netAmount != null) 'netAmount': netAmount,
      if (taxAmount != null) 'taxAmount': taxAmount,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (reference != null && reference.trim().isNotEmpty)
        'reference': reference.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
    });
    final data = response.data;
    if (data is Map) return (data['invoiceId'] ?? '').toString();
    return '';
  }

  Future<void> updatePurchaseDraft({
    required String companyId,
    required String invoiceId,
    String? supplierId,
    String? supplierName,
    String? currency,
    double? netAmount,
    double? taxAmount,
    double? totalAmount,
    String? description,
    String? reference,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('updateFinancePurchaseInvoiceDraft');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
      if (supplierId != null) 'supplierId': supplierId.trim(),
      if (supplierName != null) 'supplierName': supplierName.trim(),
      if (currency != null) 'currency': currency.trim().toUpperCase(),
      if (netAmount != null) 'netAmount': netAmount,
      if (taxAmount != null) 'taxAmount': taxAmount,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (description != null) 'description': description.trim(),
      if (reference != null) 'reference': reference.trim(),
      if (plantKey != null) 'plantKey': plantKey.trim(),
    });
  }

  Future<void> approvePurchaseInvoice({
    required String companyId,
    required String invoiceId,
    required DateTime dueDate,
  }) async {
    final callable = _functions.httpsCallable('approveFinancePurchaseInvoice');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
      'dueDate': _dateToCallable(dueDate),
    });
  }

  Future<void> cancelPurchaseInvoice({
    required String companyId,
    required String invoiceId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('cancelFinancePurchaseInvoice');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'invoiceId': invoiceId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<FinanceOpenItemsSummary> getOpenReceivablesSummary({
    required String companyId,
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceOpenReceivablesSummary');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
    });
    return FinanceOpenItemsSummary.fromCallableMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<FinanceOpenItemsSummary> getOpenPayablesSummary({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('getFinanceOpenPayablesSummary');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
    });
    return FinanceOpenItemsSummary.fromCallableMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
