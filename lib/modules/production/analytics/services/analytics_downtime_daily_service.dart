import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analytics_downtime_daily_model.dart';

/// Čitanje [analytics_downtime_daily] (serverski dnevni sažetak zastoja).
class AnalyticsDowntimeDailyService {
  AnalyticsDowntimeDailyService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('analytics_downtime_daily');

  String _s(dynamic v) => (v ?? '').toString().trim();

  static String dateYmd(DateTime localDay) {
    final d = DateTime(localDay.year, localDay.month, localDay.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime _dayStart(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Zadnji lokalni dan u [rangeStart, rangeEndExclusive).
  static DateTime _lastIncludedLocalDay(DateTime rangeEndExclusive) {
    final t = rangeEndExclusive.toLocal()
        .subtract(const Duration(milliseconds: 1));
    return _dayStart(t);
  }

  /// Sažetci u periodu (string [summaryDateYmd] uključen u raspon dana lokalno).
  Future<List<AnalyticsDowntimeDailyModel>> fetchInDateRangeLocal({
    required String companyId,
    required String plantKey,
    required DateTime rangeStartLocal,
    required DateTime rangeEndExclusiveLocal,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (cid.isEmpty || pk.isEmpty) return const [];

    final first = _dayStart(rangeStartLocal.toLocal());
    final last = _lastIncludedLocalDay(rangeEndExclusiveLocal);
    if (last.isBefore(first)) return const [];

    final startY = dateYmd(first);
    final endY = dateYmd(last);

    final snap = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('summaryDateYmd', isGreaterThanOrEqualTo: startY)
        .where('summaryDateYmd', isLessThanOrEqualTo: endY)
        .orderBy('summaryDateYmd', descending: false)
        .get();
    return snap.docs.map(AnalyticsDowntimeDailyModel.fromDoc).toList();
  }
}
