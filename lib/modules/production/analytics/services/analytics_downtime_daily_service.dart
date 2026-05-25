import 'package:cloud_functions/cloud_functions.dart';

import '../models/analytics_downtime_daily_model.dart';

/// Čitanje [analytics_downtime_daily] serverskog dnevnog sažetka zastoja.
///
/// M3-A smjer:
/// - produkcijski read ide samo preko Callable proxyja [listAnalyticsDowntimeDaily],
/// - Callable na backendu provjerava users/{uid} i RBAC u `(default)` bazi,
/// - Callable čita `analytics_downtime_daily` iz `operonix-analytics`,
/// - direktni Firestore fallback na `(default)` je uklonjen da bi se kasnije
///   mogao smanjiti monolitni `(default)` ruleset.
///
/// Ako Callable vrati grešku ili nema redova, servis vraća praznu listu.
/// Dashboard ne smije pucati zbog odsustva downtime analytics podataka.
class AnalyticsDowntimeDailyService {
  AnalyticsDowntimeDailyService({
    FirebaseFunctions? functions,
  }) : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  static const String functionsRegion = 'europe-west1';
  static const String listCallableName = 'listAnalyticsDowntimeDaily';

  final FirebaseFunctions _functions;

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

  /// Sažetci u periodu.
  ///
  /// [summaryDateYmd] je string uključen u raspon lokalnih dana.
  ///
  /// Jedini produkcijski izvor je Callable proxy prema `operonix-analytics`.
  /// Direktni Firestore read iz `(default)` više nije fallback jer je cilj
  /// M3-A uklanjanje zavisnosti dashboarda od monolitnog default ruleseta.
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
      return await _fetchFromCallable(
        companyId: cid,
        plantKey: pk,
        startYmd: startY,
        endYmd: endY,
      );
    } on FirebaseFunctionsException {
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
