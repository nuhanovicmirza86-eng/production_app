/// Normalizacija datuma/vremena za structured evidenciju (lokalni UI → UTC payload).
class StructuredDateTimeValue {
  StructuredDateTimeValue._();

  static DateTime? parse(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is Map) {
      final seconds = raw['seconds'] ?? raw['_seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000).round(),
          isUtc: true,
        ).toLocal();
      }
    }
    final parsed = DateTime.tryParse(raw.toString());
    return parsed?.toLocal();
  }

  static String toPayload(DateTime local) => local.toUtc().toIso8601String();

  static bool isEndAfterStart(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    return end.isAfter(start);
  }
}
