import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_cash_transaction.dart';
import '../models/finance_realized_cash_flow_summary.dart';

class FinanceCashTransactionsService {
  FinanceCashTransactionsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  static String _dateToCallable(DateTime d) => d.toUtc().toIso8601String();

  Future<List<FinanceCashTransaction>> listTransactions({
    required String companyId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
    String? status,
    String? direction,
    bool realizedOnly = false,
    int limit = 200,
  }) async {
    final callable = _functions.httpsCallable('listFinanceCashTransactions');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'dateFrom': _dateToCallable(dateFrom),
      'dateTo': _dateToCallable(dateTo),
      if (accountId != null && accountId.trim().isNotEmpty)
        'accountId': accountId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (direction != null && direction.trim().isNotEmpty)
        'direction': direction.trim(),
      if (realizedOnly) 'realizedOnly': true,
      'limit': limit,
    });
    return _parseTransactionList(response.data);
  }

  Future<String> createDraft({
    required String companyId,
    required String accountId,
    required String cashFlowCategoryId,
    required String direction,
    required double amount,
    required String currency,
    required DateTime transactionDate,
    String? description,
    String? reference,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('createFinanceCashTransactionDraft');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'accountId': accountId.trim(),
      'cashFlowCategoryId': cashFlowCategoryId.trim(),
      'direction': direction.trim().toLowerCase(),
      'amount': amount,
      'currency': currency.trim().toUpperCase(),
      'transactionDate': _dateToCallable(transactionDate),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (reference != null && reference.trim().isNotEmpty)
        'reference': reference.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
    });
    final data = response.data;
    if (data is Map) {
      return (data['transactionId'] ?? '').toString();
    }
    return '';
  }

  Future<void> updateDraft({
    required String companyId,
    required String transactionId,
    String? accountId,
    String? cashFlowCategoryId,
    String? direction,
    double? amount,
    String? currency,
    DateTime? transactionDate,
    String? description,
    String? reference,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('updateFinanceCashTransactionDraft');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
      if (accountId != null) 'accountId': accountId.trim(),
      if (cashFlowCategoryId != null)
        'cashFlowCategoryId': cashFlowCategoryId.trim(),
      if (direction != null) 'direction': direction.trim().toLowerCase(),
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency.trim().toUpperCase(),
      if (transactionDate != null)
        'transactionDate': _dateToCallable(transactionDate),
      if (description != null) 'description': description.trim(),
      if (reference != null) 'reference': reference.trim(),
      if (plantKey != null) 'plantKey': plantKey.trim(),
    });
  }

  Future<Map<String, dynamic>> postTransaction({
    required String companyId,
    required String transactionId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('postFinanceCashTransaction');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {};
  }

  Future<void> reconcileTransaction({
    required String companyId,
    required String transactionId,
    String? reason,
  }) async {
    final callable =
        _functions.httpsCallable('reconcileFinanceCashTransaction');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<Map<String, dynamic>> cancelTransaction({
    required String companyId,
    required String transactionId,
    String? reason,
  }) async {
    final callable =
        _functions.httpsCallable('cancelFinanceCashTransaction');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {};
  }

  Future<FinanceRealizedCashFlowSummary> getRealizedSummary({
    required String companyId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final callable = _functions.httpsCallable('getRealizedCashFlowSummary');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'dateFrom': _dateToCallable(dateFrom),
      'dateTo': _dateToCallable(dateTo),
      if (accountId != null && accountId.trim().isNotEmpty)
        'accountId': accountId.trim(),
    });
    return FinanceRealizedCashFlowSummary.fromCallable(response.data);
  }

  /// Učitava jednu transakciju po ID-u (širok period) — za vezu original ↔ storno.
  Future<FinanceCashTransaction?> findTransactionById({
    required String companyId,
    required String transactionId,
  }) async {
    final now = DateTime.now();
    final items = await listTransactions(
      companyId: companyId,
      dateFrom: DateTime(2000),
      dateTo: DateTime(now.year + 1, 12, 31),
      limit: 500,
    );
    for (final tx in items) {
      if (tx.id == transactionId) return tx;
    }
    return null;
  }

  List<FinanceCashTransaction> _parseTransactionList(dynamic data) {
    if (data is! Map) return const [];
    final rawItems = data['items'];
    if (rawItems is! List) return const [];

    final list = <FinanceCashTransaction>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      list.add(FinanceCashTransaction.fromCallableMap(id, item));
    }
    return list;
  }
}
