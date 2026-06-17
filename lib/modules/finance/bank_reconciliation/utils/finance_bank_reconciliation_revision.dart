import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../shared/finance_callable_utils.dart';

/// Revision hashovi usklađeni s backend `finance_bank_match_confirmation_helpers.js`.
class FinanceBankReconciliationRevision {
  FinanceBankReconciliationRevision._();

  static String computeBankRevision(Map<String, dynamic> bank) {
    final updatedSeconds = _updatedAtSeconds(bank['updatedAt']);
    final payload = jsonEncode({
      'updatedAt': updatedSeconds,
      'sourceHash': _asString(bank['sourceHash']),
      'status': _asString(bank['status']).toLowerCase(),
      'amount': _revisionAmount(bank['amount']),
      'currency': _clip(_asString(bank['currency']), 8).toUpperCase(),
    });
    return _hash32(payload);
  }

  static String computeInvoiceRevision(Map<String, dynamic> invoice) {
    final updatedSeconds = _updatedAtSeconds(invoice['updatedAt']);
    final payload = jsonEncode({
      'updatedAt': updatedSeconds,
      'openAmount': _revisionAmount(invoice['openAmount']),
      'canonicalOpenAmount': _resolveCanonicalOpenAmount(invoice),
      'paidAmount': _revisionAmount(invoice['paidAmount']),
      'status': _asString(invoice['status']).toLowerCase(),
      'syncConflictStatus': _asString(invoice['syncConflictStatus']),
    });
    return _hash32(payload);
  }

  static String? revisionFromMap(Map<String, dynamic> map, String key) {
    final value = _asString(map[key]);
    return value.isEmpty ? null : value;
  }

  static double _resolveCanonicalOpenAmount(Map<String, dynamic> invoice) {
    final canonical = FinanceCallableUtils.parseAmount(invoice['canonicalOpenAmount']);
    if (canonical >= 0) return canonical;
    final open = FinanceCallableUtils.parseAmount(invoice['openAmount']);
    if (open >= 0) return open;
    return 0;
  }

  /// Isti smisao kao backend `updatedAtSeconds` + ISO/DateTime fallback.
  static int? _updatedAtSeconds(dynamic updatedAt) {
    if (updatedAt == null) return null;
    if (updatedAt is Map) {
      final sec = updatedAt['seconds'] ?? updatedAt['_seconds'];
      if (sec is num) return sec.toInt();
    }
    if (updatedAt is num) {
      final n = updatedAt.toInt();
      if (n > 100000000000) return n ~/ 1000;
      return n;
    }
    final dt = FinanceCallableUtils.parseTimestamp(updatedAt);
    if (dt != null) return dt.toUtc().millisecondsSinceEpoch ~/ 1000;
    return null;
  }

  /// Usklađeno s `Number(v) || 0` na backendu (cijeli brojevi bez .0 u JSON-u).
  static num _revisionAmount(dynamic v) {
    final amount = FinanceCallableUtils.parseAmount(v);
    if (amount == 0 && (v == null || _asString(v).isEmpty)) return 0;
    if (amount == amount.roundToDouble()) return amount.round();
    return amount;
  }

  static String _hash32(String payload) {
    return sha256.convert(utf8.encode(payload)).toString().substring(0, 32);
  }

  static String _asString(dynamic v) => (v ?? '').toString().trim();

  static String _clip(String s, int max) {
    if (s.length <= max) return s;
    return s.substring(0, max);
  }
}
