import '../../shared/finance_callable_utils.dart';
import '../utils/finance_bank_reconciliation_revision.dart';

class FinanceBankStatementTransaction {
  const FinanceBankStatementTransaction({
    required this.id,
    required this.companyId,
    required this.status,
    required this.direction,
    required this.amount,
    required this.currency,
    this.bookingDate,
    this.valueDate,
    this.bankAccountId,
    this.connectionId,
    this.counterpartyName,
    this.paymentReference,
    this.rawDescription,
    this.plantKey,
    this.ignoreReason,
    this.confirmedCashTransactionId,
    this.bankMatchConfirmationId,
    this.updatedAt,
    this.bankRevision,
    this.raw,
  });

  final String id;
  final String companyId;
  final String status;
  final String direction;
  final double amount;
  final String currency;
  final DateTime? bookingDate;
  final DateTime? valueDate;
  final String? bankAccountId;
  final String? connectionId;
  final String? counterpartyName;
  final String? paymentReference;
  final String? rawDescription;
  final String? plantKey;
  final String? ignoreReason;
  final String? confirmedCashTransactionId;
  final String? bankMatchConfirmationId;
  final DateTime? updatedAt;

  /// Server-side revision hash za optimistic concurrency pri potvrdi uparivanja.
  final String? bankRevision;

  /// Izvorni Callable map za revision hash (ne prikazivati u UI).
  final Map<String, dynamic>? raw;

  bool get isInflow => direction.toLowerCase() == 'inflow';
  bool get isOutflow => direction.toLowerCase() == 'outflow';
  bool get isIgnored => status.toLowerCase() == 'ignored';

  /// Usklađeno / knjiženo — ignore nije dozvoljen (M2_POSTED_LIKE na backendu).
  bool get isPostedLike {
    switch (status.toLowerCase()) {
      case 'posted':
      case 'reconciled':
      case 'partially_reconciled':
        return true;
      default:
        return false;
    }
  }

  /// Ignore samo za imported/unmatched/suggested/confirmed (M2_IGNORE_ALLOWED).
  bool get canIgnore {
    if (isIgnored || isPostedLike) return false;
    switch (status.toLowerCase()) {
      case 'imported':
      case 'unmatched':
      case 'suggested':
      case 'confirmed':
        return true;
      default:
        return false;
    }
  }

  /// Potvrda uparivanja prije postinga (M4_CONFIRM_ALLOWED).
  bool get canConfirmMatch {
    if (isIgnored || isPostedLike) return false;
    switch (status.toLowerCase()) {
      case 'imported':
      case 'unmatched':
      case 'suggested':
        return true;
      default:
        return false;
    }
  }

  /// Generisanje prijedloga — ne za ignored niti knjižene/usklađene.
  bool get canGenerateSuggestions => !isIgnored && !isPostedLike;

  factory FinanceBankStatementTransaction.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final map = Map<String, dynamic>.from(data);
    FinanceCallableUtils.normalizeTimestampFields(map, [
      'bookingDate',
      'valueDate',
      'importedAt',
      'updatedAt',
      'ignoredAt',
      'reconciledAt',
    ]);
    return FinanceBankStatementTransaction(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      status: (map['status'] ?? '').toString().trim(),
      direction: (map['direction'] ?? '').toString().trim().toLowerCase(),
      amount: FinanceCallableUtils.parseAmount(map['amount']),
      currency: (map['currency'] ?? '').toString().trim().toUpperCase(),
      bookingDate: FinanceCallableUtils.parseTimestamp(map['bookingDate']),
      valueDate: FinanceCallableUtils.parseTimestamp(map['valueDate']),
      bankAccountId: _opt(map['bankAccountId']),
      connectionId: _opt(map['connectionId']),
      counterpartyName: _opt(map['counterpartyName']),
      paymentReference: _opt(map['paymentReference']),
      rawDescription: _opt(map['rawDescription']),
      plantKey: _opt(map['plantKey']),
      ignoreReason: _opt(map['ignoreReason']),
      confirmedCashTransactionId: _opt(map['confirmedCashTransactionId']),
      bankMatchConfirmationId: _opt(map['bankMatchConfirmationId']),
      updatedAt: FinanceCallableUtils.parseTimestamp(map['updatedAt']),
      bankRevision: FinanceBankReconciliationRevision.revisionFromMap(
        map,
        'bankRevision',
      ),
      raw: map,
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
