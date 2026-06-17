import '../../shared/finance_callable_utils.dart';
import 'finance_bank_match_source_snapshot.dart';

class FinanceBankMatchSuggestion {
  const FinanceBankMatchSuggestion({
    required this.id,
    required this.companyId,
    required this.bankStatementTransactionId,
    required this.invoiceType,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.status,
    required this.matchScore,
    required this.confidenceLevel,
    required this.invoiceOpenAmount,
    required this.bankAmount,
    required this.currency,
    required this.direction,
    required this.matchedSignals,
    required this.blockingReasons,
    this.partnerId,
    this.partnerName,
    this.sourceStateHash,
    this.dismissReason,
    this.updatedAt,
    this.sourceSnapshot,
  });

  final String id;
  final String companyId;
  final String bankStatementTransactionId;
  final String invoiceType;
  final String invoiceId;
  final String invoiceNumber;
  final String status;
  final int matchScore;
  final String confidenceLevel;
  final double invoiceOpenAmount;
  final double bankAmount;
  final String currency;
  final String direction;
  final List<String> matchedSignals;
  final List<String> blockingReasons;
  final String? partnerId;
  final String? partnerName;
  final String? sourceStateHash;
  final String? dismissReason;
  final DateTime? updatedAt;
  final FinanceBankMatchSourceSnapshot? sourceSnapshot;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isDismissed => status.toLowerCase() == 'dismissed';
  bool get isBlocked => blockingReasons.isNotEmpty;
  bool get isSales => invoiceType.toLowerCase() == 'sales';
  bool get isPurchase => invoiceType.toLowerCase() == 'purchase';

  String get displayPartnerName {
    final name = (partnerName ?? '').trim();
    if (name.isNotEmpty) return name;
    final snapName = sourceSnapshot?.partnerName?.trim();
    if (snapName != null && snapName.isNotEmpty) return snapName;
    return '—';
  }

  factory FinanceBankMatchSuggestion.fromCallableMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final map = Map<String, dynamic>.from(data);
    FinanceCallableUtils.normalizeTimestampFields(map, [
      'createdAt',
      'updatedAt',
      'dismissedAt',
    ]);
    final snapshot = map['sourceSnapshot'] is Map
        ? FinanceBankMatchSourceSnapshot.fromMap(map['sourceSnapshot'])
        : null;
    final parsedPartnerName = _opt(map['partnerName']) ?? snapshot?.partnerName;

    return FinanceBankMatchSuggestion(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      bankStatementTransactionId:
          (map['bankStatementTransactionId'] ?? '').toString(),
      invoiceType: (map['invoiceType'] ?? '').toString().trim().toLowerCase(),
      invoiceId: (map['invoiceId'] ?? '').toString(),
      invoiceNumber: (map['invoiceNumber'] ?? '').toString().trim(),
      status: (map['status'] ?? '').toString().trim().toLowerCase(),
      matchScore: (map['matchScore'] is num)
          ? (map['matchScore'] as num).toInt()
          : int.tryParse('${map['matchScore']}') ?? 0,
      confidenceLevel:
          (map['confidenceLevel'] ?? '').toString().trim().toLowerCase(),
      invoiceOpenAmount:
          FinanceCallableUtils.parseAmount(map['invoiceOpenAmount']),
      bankAmount: FinanceCallableUtils.parseAmount(map['bankAmount']),
      currency: (map['currency'] ?? '').toString().trim().toUpperCase(),
      direction: (map['direction'] ?? '').toString().trim().toLowerCase(),
      matchedSignals: _stringList(map['matchedSignals']),
      blockingReasons: _stringList(map['blockingReasons']),
      partnerId: _opt(map['partnerId']),
      partnerName: parsedPartnerName,
      sourceStateHash: _opt(map['sourceStateHash']),
      dismissReason: _opt(map['dismissReason']),
      updatedAt: FinanceCallableUtils.parseTimestamp(map['updatedAt']),
      sourceSnapshot: snapshot,
    );
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
