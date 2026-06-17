import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_bank_audit_trail_entry.dart';
import '../models/finance_bank_match_confirmation.dart';
import '../models/finance_bank_match_suggestion.dart';
import '../models/finance_bank_statement_transaction.dart';

class FinanceBankReconciliationService {
  FinanceBankReconciliationService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> runBankStatementImport({
    required String companyId,
    required String connectionId,
    required String bankAccountId,
    int? batchLimit,
  }) async {
    final callable =
        _functions.httpsCallable('runFinanceBankStatementImport');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'connectionId': connectionId.trim(),
      'bankAccountId': bankAccountId.trim(),
      if (batchLimit != null && batchLimit > 0) 'batchLimit': batchLimit,
    });
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getImportStatus({
    required String companyId,
    required String syncRunId,
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceBankStatementImportStatus');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'syncRunId': syncRunId.trim(),
    });
    return _asMap(response.data);
  }

  Future<List<FinanceBankStatementTransaction>> listBankTransactions({
    required String companyId,
    String? status,
    String? connectionId,
    String? bankAccountId,
    int limit = 100,
  }) async {
    final callable =
        _functions.httpsCallable('listFinanceBankStatementTransactions');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'limit': limit,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (connectionId != null && connectionId.trim().isNotEmpty)
        'connectionId': connectionId.trim(),
      if (bankAccountId != null && bankAccountId.trim().isNotEmpty)
        'bankAccountId': bankAccountId.trim(),
    });
    return _parseBankList(response.data);
  }

  Future<FinanceBankStatementTransaction> getBankTransaction({
    required String companyId,
    required String transactionId,
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceBankStatementTransaction');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
    });
    final data = _asMap(response.data);
    final txn = data['transaction'];
    if (txn is! Map) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Neispravan odgovor servera.',
      );
    }
    final map = Map<String, dynamic>.from(txn);
    final id = (map['transactionId'] ?? transactionId).toString();
    map.remove('transactionId');
    return FinanceBankStatementTransaction.fromCallableMap(id, map);
  }

  Future<void> ignoreBankTransaction({
    required String companyId,
    required String transactionId,
    required String reason,
  }) async {
    final callable =
        _functions.httpsCallable('ignoreFinanceBankStatementTransaction');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
      'reason': reason.trim(),
    });
  }

  Future<void> restoreBankTransaction({
    required String companyId,
    required String transactionId,
  }) async {
    final callable =
        _functions.httpsCallable('restoreFinanceBankStatementTransaction');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'transactionId': transactionId.trim(),
    });
  }

  Future<Map<String, dynamic>> generateMatchSuggestions({
    required String companyId,
    String? bankStatementTransactionId,
    String? plantKey,
  }) async {
    final callable =
        _functions.httpsCallable('generateFinanceBankMatchSuggestions');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (bankStatementTransactionId != null &&
          bankStatementTransactionId.trim().isNotEmpty)
        'bankStatementTransactionId': bankStatementTransactionId.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
    });
    return _asMap(response.data);
  }

  Future<List<FinanceBankMatchSuggestion>> listMatchSuggestions({
    required String companyId,
    String? bankStatementTransactionId,
    String? status,
    String? invoiceType,
    int limit = 50,
  }) async {
    final callable =
        _functions.httpsCallable('listFinanceBankMatchSuggestions');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'limit': limit,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (bankStatementTransactionId != null &&
          bankStatementTransactionId.trim().isNotEmpty)
        'bankStatementTransactionId': bankStatementTransactionId.trim(),
      if (invoiceType != null && invoiceType.trim().isNotEmpty)
        'invoiceType': invoiceType.trim(),
    });
    return _parseSuggestionList(response.data);
  }

  Future<FinanceBankMatchSuggestion> getMatchSuggestion({
    required String companyId,
    required String suggestionId,
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceBankMatchSuggestion');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'suggestionId': suggestionId.trim(),
    });
    final data = _asMap(response.data);
    final sug = data['suggestion'];
    if (sug is! Map) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Neispravan odgovor servera.',
      );
    }
    final map = Map<String, dynamic>.from(sug);
    final id = (map['suggestionId'] ?? suggestionId).toString();
    map.remove('suggestionId');
    return FinanceBankMatchSuggestion.fromCallableMap(id, map);
  }

  Future<void> dismissMatchSuggestion({
    required String companyId,
    required String suggestionId,
    required String reason,
  }) async {
    final callable =
        _functions.httpsCallable('dismissFinanceBankMatchSuggestion');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'suggestionId': suggestionId.trim(),
      'reason': reason.trim(),
    });
  }

  Future<void> restoreMatchSuggestion({
    required String companyId,
    required String suggestionId,
  }) async {
    final callable =
        _functions.httpsCallable('restoreFinanceBankMatchSuggestion');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'suggestionId': suggestionId.trim(),
    });
  }

  Future<Map<String, dynamic>> confirmBankMatch({
    required String companyId,
    required String bankStatementTransactionId,
    required String requestId,
    required String cashFlowCategoryId,
    required String expectedBankRevision,
    required List<Map<String, dynamic>> expectedInvoiceRevisions,
    String? suggestionId,
    String? accountId,
    String? expectedSuggestionSourceStateHash,
    List<Map<String, dynamic>>? lines,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('confirmFinanceBankMatch');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'bankStatementTransactionId': bankStatementTransactionId.trim(),
      'requestId': requestId.trim(),
      'cashFlowCategoryId': cashFlowCategoryId.trim(),
      'expectedBankRevision': expectedBankRevision.trim(),
      'expectedInvoiceRevisions': expectedInvoiceRevisions,
      if (suggestionId != null && suggestionId.trim().isNotEmpty)
        'suggestionId': suggestionId.trim(),
      if (accountId != null && accountId.trim().isNotEmpty)
        'accountId': accountId.trim(),
      if (expectedSuggestionSourceStateHash != null &&
          expectedSuggestionSourceStateHash.trim().isNotEmpty)
        'expectedSuggestionSourceStateHash':
            expectedSuggestionSourceStateHash.trim(),
      if (lines != null && lines.isNotEmpty) 'lines': lines,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return _asMap(response.data);
  }

  Future<FinanceBankMatchConfirmation> getMatchConfirmation({
    required String companyId,
    required String confirmationId,
  }) async {
    final callable =
        _functions.httpsCallable('getFinanceBankMatchConfirmation');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'confirmationId': confirmationId.trim(),
    });
    final data = _asMap(response.data);
    final conf = data['confirmation'];
    if (conf is! Map) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Neispravan odgovor servera.',
      );
    }
    final map = Map<String, dynamic>.from(conf);
    final id = (map['confirmationId'] ?? confirmationId).toString();
    map.remove('confirmationId');
    return FinanceBankMatchConfirmation.fromCallableMap(id, map);
  }

  Future<List<FinanceBankMatchConfirmation>> listMatchConfirmations({
    required String companyId,
    String? bankStatementTransactionId,
    String? cashTransactionId,
    String? status,
    int limit = 50,
  }) async {
    final callable =
        _functions.httpsCallable('listFinanceBankMatchConfirmations');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'limit': limit,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (bankStatementTransactionId != null &&
          bankStatementTransactionId.trim().isNotEmpty)
        'bankStatementTransactionId': bankStatementTransactionId.trim(),
      if (cashTransactionId != null && cashTransactionId.trim().isNotEmpty)
        'cashTransactionId': cashTransactionId.trim(),
    });
    return _parseConfirmationList(response.data);
  }

  /// Aktivne i otkazane potvrde za jednu bankovnu stavku (trajna historija).
  Future<List<FinanceBankMatchConfirmation>> listMatchConfirmationHistory({
    required String companyId,
    required String bankStatementTransactionId,
    int limit = 50,
  }) {
    return listMatchConfirmations(
      companyId: companyId,
      bankStatementTransactionId: bankStatementTransactionId,
      status: 'all',
      limit: limit,
    );
  }

  Future<List<FinanceBankAuditTrailEntry>> listBankStatementAuditTrail({
    required String companyId,
    required String bankStatementTransactionId,
  }) async {
    final callable =
        _functions.httpsCallable('listFinanceBankStatementAuditTrail');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'bankStatementTransactionId': bankStatementTransactionId.trim(),
    });
    return _parseAuditTrailList(response.data);
  }

  Future<Map<String, dynamic>> cancelMatchConfirmation({
    required String companyId,
    required String confirmationId,
    required String requestId,
    required String cancelReason,
  }) async {
    final callable =
        _functions.httpsCallable('cancelFinanceBankMatchConfirmation');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'confirmationId': confirmationId.trim(),
      'requestId': requestId.trim(),
      'cancelReason': cancelReason.trim(),
    });
    return _asMap(response.data);
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  static List<FinanceBankStatementTransaction> _parseBankList(dynamic data) {
    if (data is! Map) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    final out = <FinanceBankStatementTransaction>[];
    for (final e in items) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final id = (map['transactionId'] ?? '').toString();
      if (id.isEmpty) continue;
      map.remove('transactionId');
      out.add(FinanceBankStatementTransaction.fromCallableMap(id, map));
    }
    return out;
  }

  static List<FinanceBankMatchSuggestion> _parseSuggestionList(dynamic data) {
    if (data is! Map) return const [];
    final items = data['suggestions'];
    if (items is! List) return const [];
    final out = <FinanceBankMatchSuggestion>[];
    for (final e in items) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final id = (map['suggestionId'] ?? '').toString();
      if (id.isEmpty) continue;
      map.remove('suggestionId');
      out.add(FinanceBankMatchSuggestion.fromCallableMap(id, map));
    }
    return out;
  }

  static List<FinanceBankMatchConfirmation> _parseConfirmationList(
    dynamic data,
  ) {
    if (data is! Map) return const [];
    final items = data['confirmations'];
    if (items is! List) return const [];
    final out = <FinanceBankMatchConfirmation>[];
    for (final e in items) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final id = (map['confirmationId'] ?? '').toString();
      if (id.isEmpty) continue;
      map.remove('confirmationId');
      out.add(FinanceBankMatchConfirmation.fromCallableMap(id, map));
    }
    return out;
  }

  static List<FinanceBankAuditTrailEntry> _parseAuditTrailList(dynamic data) {
    if (data is! Map) return const [];
    final items = data['timeline'];
    if (items is! List) return const [];
    final out = <FinanceBankAuditTrailEntry>[];
    for (final e in items) {
      if (e is! Map) continue;
      out.add(FinanceBankAuditTrailEntry.fromCallableMap(
        Map<String, dynamic>.from(e),
      ));
    }
    return out;
  }
}
