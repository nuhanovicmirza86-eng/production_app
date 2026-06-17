import '../../shared/finance_callable_utils.dart';

/// Snapshot banka + fakture iz prijedloga (Callable `sourceSnapshot`).
class FinanceBankMatchSourceSnapshot {
  const FinanceBankMatchSourceSnapshot({
    this.bankAmount,
    this.bankCurrency,
    this.bookingDate,
    this.paymentReference,
    this.counterpartyName,
    this.counterpartyAccount,
    this.rawDescription,
    this.invoiceOpenAmount,
    this.invoiceTotalAmount,
    this.invoiceCurrency,
    this.dueDate,
    this.invoiceNumber,
    this.partnerId,
    this.partnerName,
  });

  final double? bankAmount;
  final String? bankCurrency;
  final DateTime? bookingDate;
  final String? paymentReference;
  final String? counterpartyName;
  final String? counterpartyAccount;
  final String? rawDescription;
  final double? invoiceOpenAmount;
  final double? invoiceTotalAmount;
  final String? invoiceCurrency;
  final DateTime? dueDate;
  final String? invoiceNumber;
  final String? partnerId;
  final String? partnerName;

  factory FinanceBankMatchSourceSnapshot.fromMap(dynamic raw) {
    if (raw is! Map) return const FinanceBankMatchSourceSnapshot();
    final map = Map<String, dynamic>.from(raw);
    final bank = map['bank'] is Map
        ? Map<String, dynamic>.from(map['bank'] as Map)
        : <String, dynamic>{};
    final invoice = map['invoice'] is Map
        ? Map<String, dynamic>.from(map['invoice'] as Map)
        : <String, dynamic>{};

    return FinanceBankMatchSourceSnapshot(
      bankAmount: FinanceCallableUtils.parseAmount(bank['amount']),
      bankCurrency: _opt(bank['currency']),
      bookingDate: FinanceCallableUtils.parseTimestamp(bank['bookingDate']),
      paymentReference: _opt(bank['paymentReference']),
      counterpartyName: _opt(bank['counterpartyName']),
      counterpartyAccount: _opt(bank['counterpartyAccount']),
      rawDescription: _opt(bank['rawDescription']),
      invoiceOpenAmount: FinanceCallableUtils.parseAmount(invoice['openAmount']),
      invoiceTotalAmount: FinanceCallableUtils.parseAmount(invoice['totalAmount']),
      invoiceCurrency: _opt(invoice['currency']),
      dueDate: FinanceCallableUtils.parseTimestamp(invoice['dueDate']),
      invoiceNumber: _opt(invoice['invoiceNumber']),
      partnerId: _opt(invoice['partnerId']),
      partnerName: _opt(invoice['partnerName']),
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
