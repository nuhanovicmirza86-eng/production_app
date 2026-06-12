import 'package:cloud_firestore/cloud_firestore.dart';

/// Parsiranje Callable odgovora (timestamp map → DateTime).
class FinanceCallableUtils {
  FinanceCallableUtils._();

  static DateTime? parseTimestamp(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is Map) {
      final sec = v['seconds'];
      final ns = v['nanoseconds'];
      if (sec is num) {
        final millis =
            sec.toInt() * 1000 + ((ns is num ? ns.toInt() : 0) ~/ 1000000);
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
            .toLocal();
      }
    }
    return null;
  }

  static void normalizeTimestampFields(
    Map<String, dynamic> item,
    List<String> keys,
  ) {
    for (final key in keys) {
      final dt = parseTimestamp(item[key]);
      if (dt != null) {
        item[key] = dt;
      }
    }
  }

  static double parseAmount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
