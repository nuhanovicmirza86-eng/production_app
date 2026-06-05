import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../ooe/models/ooe_shift_summary.dart';
import '../../ooe/models/teep_summary.dart';
import '../../ooe/models/utilization_summary.dart';
import 'analytics_callable_parse.dart';

/// Callable read proxija za OOE/TEEP/utilization summary kolekcije (M3/M4).
///
/// Backend: `listOoeShiftSummaries`, `listTeepSummaries`, `listUtilizationSummaries`
/// (čitanje iz `operonix-analytics`).
class AnalyticsSummaryReadsCallableService {
  AnalyticsSummaryReadsCallableService({
    FirebaseFunctions? functions,
  }) : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  static const String functionsRegion = 'europe-west1';
  static const Duration callablePollInterval = Duration(seconds: 30);

  static const String listOoeShiftSummariesName = 'listOoeShiftSummaries';
  static const String listTeepSummariesName = 'listTeepSummaries';
  static const String listUtilizationSummariesName = 'listUtilizationSummaries';

  final FirebaseFunctions _functions;

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<List<Map<String, dynamic>>> _callListItems({
    required String callableName,
    required Map<String, dynamic> body,
  }) async {
    final callable = _functions.httpsCallable(callableName);
    final response = await callable.call(body);
    final data = response.data;

    if (data is! Map) {
      return const [];
    }

    return AnalyticsCallableParse.parseCallableItems(data['items']);
  }

  Future<List<OoeShiftSummary>> listOoeShiftSummaries({
    required String companyId,
    required String plantKey,
    String? machineId,
    String? startShiftDateYmd,
    String? endShiftDateYmd,
    int limit = 100,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (cid.isEmpty || pk.isEmpty) return const [];

    final body = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'limit': limit,
      if (_s(machineId).isNotEmpty) 'machineId': _s(machineId),
      if (_s(startShiftDateYmd).isNotEmpty)
        'startShiftDateYmd': _s(startShiftDateYmd),
      if (_s(endShiftDateYmd).isNotEmpty) 'endShiftDateYmd': _s(endShiftDateYmd),
    };

    final rows = await _callListItems(
      callableName: listOoeShiftSummariesName,
      body: body,
    );

    return rows
        .map((item) {
          final documentId = _s(item['documentId']);
          if (documentId.isEmpty) return null;

          return OoeShiftSummary.fromMap(documentId, item);
        })
        .whereType<OoeShiftSummary>()
        .toList();
  }

  Future<List<TeepSummary>> listTeepSummaries({
    required String companyId,
    required String plantKey,
    String scopeType = 'plant',
    String scopeId = '',
    String periodType = 'day',
    String? periodStartYmd,
    String? periodEndYmd,
    int limit = 100,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (cid.isEmpty || pk.isEmpty) return const [];

    final st = _s(scopeType).toLowerCase();
    final sid = st == 'plant' ? '' : _s(scopeId);
    final pt = _s(periodType).toLowerCase();

    final body = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'scopeType': st.isEmpty ? 'plant' : st,
      'scopeId': sid,
      'periodType': pt.isEmpty ? 'day' : pt,
      'limit': limit,
      if (_s(periodStartYmd).isNotEmpty) 'periodStartYmd': _s(periodStartYmd),
      if (_s(periodEndYmd).isNotEmpty) 'periodEndYmd': _s(periodEndYmd),
    };

    final rows = await _callListItems(
      callableName: listTeepSummariesName,
      body: body,
    );

    return rows
        .map((item) {
          final documentId = _s(item['documentId']);
          if (documentId.isEmpty) return null;

          return TeepSummary.fromMap(documentId, item);
        })
        .whereType<TeepSummary>()
        .toList();
  }

  Future<List<UtilizationSummary>> listUtilizationSummaries({
    required String companyId,
    required String plantKey,
    String scopeType = 'plant',
    String scopeId = '',
    String periodType = 'day',
    String? periodStartYmd,
    String? periodEndYmd,
    int limit = 100,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (cid.isEmpty || pk.isEmpty) return const [];

    final st = _s(scopeType).toLowerCase();
    final sid = st == 'plant' ? '' : _s(scopeId);
    final pt = _s(periodType).toLowerCase();

    final body = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'scopeType': st.isEmpty ? 'plant' : st,
      'scopeId': sid,
      'periodType': pt.isEmpty ? 'day' : pt,
      'limit': limit,
      if (_s(periodStartYmd).isNotEmpty) 'periodStartYmd': _s(periodStartYmd),
      if (_s(periodEndYmd).isNotEmpty) 'periodEndYmd': _s(periodEndYmd),
    };

    final rows = await _callListItems(
      callableName: listUtilizationSummariesName,
      body: body,
    );

    return rows
        .map((item) {
          final documentId = _s(item['documentId']);
          if (documentId.isEmpty) return null;

          return UtilizationSummary.fromMap(documentId, item);
        })
        .whereType<UtilizationSummary>()
        .toList();
  }

  /// Callable primarno; Firestore [firestoreFallback] samo kad Callable padne (M4).
  static Stream<List<T>> watchWithCallablePrimary<T>({
    required Future<List<T>> Function() fetchPrimary,
    required Stream<List<T>> Function() firestoreFallback,
    Duration pollInterval = callablePollInterval,
  }) {
    return Stream<List<T>>.multi((controller) {
      var usingFirestore = false;
      Timer? timer;
      StreamSubscription<List<T>>? fsSub;

      void switchToFirestore() {
        if (usingFirestore) return;
        usingFirestore = true;
        timer?.cancel();
        fsSub = firestoreFallback().listen(
          controller.add,
          onError: controller.addError,
        );
      }

      Future<void> refresh() async {
        if (usingFirestore) return;
        try {
          controller.add(await fetchPrimary());
        } on FirebaseFunctionsException {
          switchToFirestore();
        } catch (_) {
          switchToFirestore();
        }
      }

      refresh();
      timer = Timer.periodic(pollInterval, (_) => refresh());

      controller.onCancel = () async {
        timer?.cancel();
        await fsSub?.cancel();
      };
    });
  }
}
