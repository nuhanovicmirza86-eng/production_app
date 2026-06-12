import '../../shared/finance_callable_utils.dart';

/// Read model za `finance_accounts` (Callable [listFinanceAccounts]).
class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.companyId,
    required this.accountCode,
    required this.name,
    required this.accountType,
    required this.currency,
    required this.openingBalance,
    required this.currentBalance,
    required this.availableBalance,
    required this.active,
    this.bankName,
    this.iban,
    this.plantKey,
  });

  final String id;
  final String companyId;
  final String accountCode;
  final String name;
  final String accountType;
  final String currency;
  final double openingBalance;
  final double currentBalance;
  final double availableBalance;
  final bool active;
  final String? bankName;
  final String? iban;
  final String? plantKey;

  factory FinanceAccount.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceAccount(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      accountCode: (data['accountCode'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      accountType: (data['accountType'] ?? '').toString().trim(),
      currency: (data['currency'] ?? '').toString().trim().toUpperCase(),
      openingBalance: FinanceCallableUtils.parseAmount(data['openingBalance']),
      currentBalance: FinanceCallableUtils.parseAmount(data['currentBalance']),
      availableBalance: FinanceCallableUtils.parseAmount(
        data['availableBalance'] ?? data['currentBalance'],
      ),
      active: data['active'] != false,
      bankName: _opt(data['bankName']),
      iban: _opt(data['iban']),
      plantKey: _opt(data['plantKey']),
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
