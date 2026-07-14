import 'package:cloud_firestore/cloud_firestore.dart';

/// Parsira timestamp iz Callable odgovora (Firestore Timestamp serializacija).
DateTime? parseApsCallableTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
        .toLocal();
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  if (value is Map) {
    final seconds = value['seconds'] ?? value['_seconds'];
    if (seconds is num) {
      final nanos = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
      final ms = seconds.toInt() * 1000 + (nanos is num ? nanos ~/ 1000000 : 0);
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
  }
  return null;
}
