import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/teep_summary.dart';

/// Čitanje agregata [teep_summaries] (OEE + OOE + TEEP u istom dokumentu).
class TeepSummaryService {
  TeepSummaryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('teep_summaries');

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Pronalazi dnevni sažetak za stroj iz stream liste (isti kalendar dan lokalno).
  TeepSummary? pickMachineDaySummary({
    required List<TeepSummary> recent,
    required String machineId,
    required DateTime calendarDayLocal,
  }) {
    final mid = _s(machineId);
    if (mid.isEmpty) return null;
    final y = calendarDayLocal.year;
    final m = calendarDayLocal.month;
    final d = calendarDayLocal.day;
    TeepSummary? best;
    for (final s in recent) {
      if (_s(s.scopeType) != 'machine' || _s(s.scopeId) != mid) continue;
      if (_s(s.periodType) != 'day') continue;
      final pd = s.periodDate.toLocal();
      if (pd.year != y || pd.month != m || pd.day != d) continue;
      if (best == null ||
          s.lastCalculatedAt.isAfter(best.lastCalculatedAt)) {
        best = s;
      }
    }
    return best;
  }

  /// Zadnji sažeci za pogon (svi opsezi: plant, line, machine × day, week, month).
  Stream<List<TeepSummary>> watchRecentForPlant({
    required String companyId,
    required String plantKey,
    int limit = 48,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('periodDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(TeepSummary.fromDoc).toList());
  }

  /// Jednokratno učitavanje zadnjih dokumenata za pogon (isti upit kao [watchRecentForPlant]).
  /// Filtriraj u kodu na [scopeType]==`plant` i [periodType]==`day` te lokalni datum u periodu.
  Future<List<TeepSummary>> fetchRecentForPlantOnce({
    required String companyId,
    required String plantKey,
    int limit = 200,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (cid.isEmpty || pk.isEmpty) return const [];

    final snap = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('periodDate', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(TeepSummary.fromDoc).toList();
  }

  static DateTime _localDayStart(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Sidro u `teep_summaries` kao u backendu (`YYYY-MM-DDT12:00:00.000Z` po kalendaru).
  static DateTime _anchorUtcNoonForLocalCalendarDay(DateTime localDay) {
    final d = _localDayStart(localDay);
    return DateTime.utc(d.year, d.month, d.day, 12);
  }

  /// Zadnji lokalni kalendar-dan uključen u [[rangeStartLocal], [rangeEndExclusiveLocal)>.
  static DateTime _lastIncludedLocalDay(DateTime rangeEndExclusive) {
    final t = rangeEndExclusive.toLocal().subtract(const Duration(milliseconds: 1));
    return _localDayStart(t);
  }

  /// Dnevni sažetak za cijeli pogon: točan upit po datumu (zahtijeva Firestore indeks,
  /// vidi [maintenance_app]/firestore.indexes.json). Za plant je [scopeId] prazan.
  Future<List<TeepSummary>> fetchPlantDaySummariesInDateRange({
    required String companyId,
    required String plantKey,
    required DateTime rangeStartLocal,
    required DateTime rangeEndExclusiveLocal,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (cid.isEmpty || pk.isEmpty) return const [];

    final first = _localDayStart(rangeStartLocal.toLocal());
    final last = _lastIncludedLocalDay(rangeEndExclusiveLocal);
    if (last.isBefore(first)) return const [];

    final startTs = Timestamp.fromDate(_anchorUtcNoonForLocalCalendarDay(first));
    final endTs = Timestamp.fromDate(_anchorUtcNoonForLocalCalendarDay(last));

    final snap = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('scopeType', isEqualTo: 'plant')
        .where('scopeId', isEqualTo: '')
        .where('periodType', isEqualTo: 'day')
        .where('periodDate', isGreaterThanOrEqualTo: startTs)
        .where('periodDate', isLessThanOrEqualTo: endTs)
        .orderBy('periodDate', descending: false)
        .get();
    return snap.docs.map(TeepSummary.fromDoc).toList();
  }
}
