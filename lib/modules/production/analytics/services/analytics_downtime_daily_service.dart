import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/analytics_downtime_daily_model.dart';

/// Čitanje [analytics_downtime_daily] serverskog dnevnog sažetka zastoja.
///
/// M2-C smjer:
/// - primarno čitanje iz sekundarne Firestore baze `operonix-analytics`,
/// - fallback na postojeću `(default)` bazu dok traje migracioni period.
///
/// Napomena:
/// Ako `operonix-analytics` pravila još ne dopuštaju klijentski read,
/// primarni upit će pasti s permission-denied i servis će se vratiti
/// na postojeći `(default)` read bez pucanja dashboarda.
class AnalyticsDowntimeDailyService {
  AnalyticsDowntimeDailyService({
    FirebaseFirestore? firestore,
    FirebaseFirestore? fallbackFirestore,
  })  : _primaryDb = firestore ?? _analyticsFirestore(),
        _fallbackDb = fallbackFirestore ?? FirebaseFirestore.instance;

  static const String analyticsDatabaseId = 'operonix-analytics';

  final FirebaseFirestore _primaryDb;
  final FirebaseFirestore _fallbackDb;

  static FirebaseFirestore _analyticsFirestore() {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: analyticsDatabaseId,
    );
  }

  CollectionReference<Map<String, dynamic>> _col(FirebaseFirestore db) {
    return db.collection('analytics_downtime_daily');
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  static String dateYmd(DateTime localDay) {
    final d = DateTime(localDay.year, localDay.month, localDay.day);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');

    return '$y-$m-$day';
  }

  static DateTime _dayStart(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  /// Zadnji lokalni dan u [rangeStart, rangeEndExclusive).
  static DateTime _lastIncludedLocalDay(DateTime rangeEndExclusive) {
    final t = rangeEndExclusive.toLocal().subtract(
      const Duration(milliseconds: 1),
    );

    return _dayStart(t);
  }

  Future<List<AnalyticsDowntimeDailyModel>> _fetchFromDb({
    required FirebaseFirestore db,
    required String companyId,
    required String plantKey,
    required String startYmd,
    required String endYmd,
  }) async {
    final snap = await _col(db)
        .where('companyId', isEqualTo: companyId)
        .where('plantKey', isEqualTo: plantKey)
        .where('summaryDateYmd', isGreaterThanOrEqualTo: startYmd)
        .where('summaryDateYmd', isLessThanOrEqualTo: endYmd)
        .orderBy('summaryDateYmd', descending: false)
        .get();

    return snap.docs.map(AnalyticsDowntimeDailyModel.fromDoc).toList();
  }

  /// Sažetci u periodu.
  ///
  /// [summaryDateYmd] je string uključen u raspon lokalnih dana.
  ///
  /// Primarni izvor je `operonix-analytics`; ako nema podataka ili read
  /// još nije dozvoljen pravilima, servis koristi fallback na `(default)`.
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

    try {
      final primaryRows = await _fetchFromDb(
        db: _primaryDb,
        companyId: cid,
        plantKey: pk,
        startYmd: startY,
        endYmd: endY,
      );

      if (primaryRows.isNotEmpty) {
        return primaryRows;
      }
    } on FirebaseException {
      // Fallback ostaje namjeran tokom M2-C migracije:
      // - analytics DB može još imati deny read pravila,
      // - historical backfill možda nije potpun,
      // - dashboard ne smije ostati prazan zbog tranzicije.
    }

    return _fetchFromDb(
      db: _fallbackDb,
      companyId: cid,
      plantKey: pk,
      startYmd: startY,
      endYmd: endY,
    );
  }
}
