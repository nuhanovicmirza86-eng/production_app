import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/analytics_downtime_daily_model.dart';

/// Čitanje [analytics_downtime_daily] serverskog dnevnog sažetka zastoja.
///
/// M2-C smjer:
/// - primarni produkcijski read ide preko Callable proxyja
///   [listAnalyticsDowntimeDaily],
/// - Callable na backendu provjerava users/{uid} i RBAC u `(default)` bazi,
/// - Callable čita `analytics_downtime_daily` iz `operonix-analytics`,
/// - fallback ostaje postojeći Firestore read iz `(default)` baze dok traje
///   migracioni period.
///
/// Direktni client read iz `operonix-analytics` nije primarni put jer
/// analytics baza nema cross-DB pristup ka users/{uid} iz `(default)`.
class AnalyticsDowntimeDailyService {
  AnalyticsDowntimeDailyService({
    FirebaseFunctions? functions,
    FirebaseFirestore? fallbackFirestore,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: functionsRegion),
        _fallbackDb = fallbackFirestore ?? FirebaseFirestore.instance;

  static const String functionsRegion = 'europe-west1';
  static const String listCallableName = 'listAnalyticsDowntimeDaily';

  final FirebaseFunctions _functions;
  final FirebaseFirestore _fallbackDb;

  CollectionReference<Map<String, dynamic>> get _fallbackCol {
    return _fallbackDb.collection('analytics_downtime_daily');
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

  Future<List<AnalyticsDowntimeDailyModel>> _fetchFromCallable({
    required String companyId,
    required String plantKey,
    required String startYmd,
    required String endYmd,
  }) async {
    final callable = _functions.httpsCallable(listCallableName);

    final response = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'startYmd': startYmd,
      'endYmd': endYmd,
    });

    final data = response.data;
    if (data is! Map) {
      return const [];
    }

    final rawItems = data['items'];

    if (rawItems is! List) {
      return const [];
    }

    return rawItems
        .map((raw) {
          if (raw is! Map) return null;

          final item = Map<String, dynamic>.from(raw);
          final documentId = _s(item['documentId']);

          if (documentId.isEmpty) {
            return null;
          }

          return AnalyticsDowntimeDailyModel.fromMap(documentId, item);
        })
        .whereType<AnalyticsDowntimeDailyModel>()
        .toList();
  }

  Future<List<AnalyticsDowntimeDailyModel>> _fetchFromDefaultDb({
    required String companyId,
    required String plantKey,
    required String startYmd,
    required String endYmd,
  }) async {
    final snap = await _fallbackCol
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
  /// Primarni izvor je Callable proxy prema `operonix-analytics`.
  /// Ako Callable vrati prazno ili padne, fallback ostaje `(default)` Firestore.
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
      final callableRows = await _fetchFromCallable(
        companyId: cid,
        plantKey: pk,
        startYmd: startY,
        endYmd: endY,
      );

      if (callableRows.isNotEmpty) {
        return callableRows;
      }
    } on FirebaseFunctionsException {
      // Fallback ostaje namjeran tokom M2-C:
      // - Callable proxy može odbiti pristup,
      // - indeks može biti u tranziciji,
      // - analytics baza možda još nema historijske podatke.
    } on FirebaseException {
      // Zaštita ako fallback/SDK sloj vrati FirebaseException kroz plugin.
    }

    return _fetchFromDefaultDb(
      companyId: cid,
      plantKey: pk,
      startYmd: startY,
      endYmd: endY,
    );
  }
}
