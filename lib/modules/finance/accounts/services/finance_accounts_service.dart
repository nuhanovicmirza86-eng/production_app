import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_account.dart';
import '../../shared/finance_callable_utils.dart';

/// Finance računi — isključivo Callable (bez Firestore pristupa).
class FinanceAccountsService {
  FinanceAccountsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  Future<List<FinanceAccount>> listAccounts({
    required String companyId,
    bool activeOnly = false,
    String? plantKey,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final callable = _functions.httpsCallable('listFinanceAccounts');
    final response = await callable.call(<String, dynamic>{
      'companyId': cid,
      if (activeOnly) 'activeOnly': true,
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
    });

    return _parseList(response.data);
  }

  Future<String> createAccount({
    required String companyId,
    required String accountCode,
    required String name,
    required String accountType,
    required String currency,
    double openingBalance = 0,
    String? bankName,
    String? iban,
    String? plantKey,
  }) async {
    final callable = _functions.httpsCallable('createFinanceAccount');
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'accountCode': accountCode.trim(),
      'name': name.trim(),
      'accountType': accountType.trim(),
      'currency': currency.trim().toUpperCase(),
      'openingBalance': openingBalance,
      if (bankName != null && bankName.trim().isNotEmpty)
        'bankName': bankName.trim(),
      if (iban != null && iban.trim().isNotEmpty) 'iban': iban.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
    });
    final data = response.data;
    if (data is Map) {
      return (data['accountId'] ?? '').toString();
    }
    return '';
  }

  Future<void> updateAccount({
    required String companyId,
    required String accountId,
    String? name,
    String? bankName,
    String? iban,
    String? plantKey,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('updateFinanceAccount');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'accountId': accountId.trim(),
      if (name != null) 'name': name.trim(),
      if (bankName != null) 'bankName': bankName.trim(),
      if (iban != null) 'iban': iban.trim(),
      if (plantKey != null) 'plantKey': plantKey.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<void> deactivateAccount({
    required String companyId,
    required String accountId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('deactivateFinanceAccount');
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'accountId': accountId.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  List<FinanceAccount> _parseList(dynamic data) {
    if (data is! Map) return const [];
    final rawItems = data['items'];
    if (rawItems is! List) return const [];

    final list = <FinanceAccount>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      FinanceCallableUtils.normalizeTimestampFields(item, [
        'createdAt',
        'updatedAt',
        'deactivatedAt',
      ]);
      list.add(FinanceAccount.fromCallableMap(id, item));
    }
    return list;
  }
}
