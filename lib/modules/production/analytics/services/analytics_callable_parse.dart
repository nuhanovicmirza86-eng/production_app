import 'package:cloud_firestore/cloud_firestore.dart';

/// Zajedničko parsiranje Callable odgovora (Timestamp → `{seconds,nanoseconds}`).
class AnalyticsCallableParse {
  AnalyticsCallableParse._();

  static String dateYmd(DateTime localDay) {
    final d = DateTime(localDay.year, localDay.month, localDay.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');

    return '$y-$m-$day';
  }

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Zadnji lokalni dan u [rangeStart, rangeEndExclusive).
  static DateTime lastIncludedLocalDay(DateTime rangeEndExclusive) {
    final t = rangeEndExclusive.toLocal().subtract(
      const Duration(milliseconds: 1),
    );

    return dayStart(t);
  }

  static DateTime? dateTimeFromTimestampLike(dynamic v) {
    if (v is Timestamp) {
      return v.toDate();
    }

    if (v is Map) {
      final rawSeconds = v['seconds'];
      final rawNanoseconds = v['nanoseconds'];

      if (rawSeconds is num) {
        final seconds = rawSeconds.toInt();
        final nanoseconds = rawNanoseconds is num ? rawNanoseconds.toInt() : 0;

        return Timestamp(seconds, nanoseconds).toDate();
      }
    }

    return null;
  }

  static List<Map<String, dynamic>> parseCallableItems(dynamic rawItems) {
    if (rawItems is! List) return const [];

    return rawItems
        .map((raw) {
          if (raw is! Map) return null;

          return Map<String, dynamic>.from(raw);
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}
