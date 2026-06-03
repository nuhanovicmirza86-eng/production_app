import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_downtime_event_cost_doc.dart';
import '../models/finance_machine_cost_doc.dart';
import '../models/finance_order_profitability_doc.dart';
import '../models/finance_product_cost_doc.dart';
import '../models/finance_quality_cost_doc.dart';
import '../models/finance_routing_operation_cost_doc.dart';
import 'finance_controlling_period_read_service.dart';

/// Čitanje izvedenih agregata: period + pogon preko Callable [fetchFinanceControllingPeriodReads].
class FinanceDerivedAggregatesService {
  FinanceDerivedAggregatesService({
    FirebaseFunctions? functions,
    FinanceControllingPeriodReadService? periodReads,
  })  : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion),
        _reads = periodReads ?? FinanceControllingPeriodReadService();

  static const String _functionsRegion = 'europe-west1';
  static const String _listDowntimeCostsCallable =
      'listFinanceDowntimeEventCosts';
  static const int _downtimeEventCostsLimit = 100;

  final FirebaseFunctions _functions;
  final FinanceControllingPeriodReadService _reads;

  Stream<List<FinanceOrderProfitabilityDoc>> watchOrderProfitability({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    required String plantKey,
  }) {
    if (companyId.trim().isEmpty || businessYearId.trim().isEmpty) {
      return Stream<List<FinanceOrderProfitabilityDoc>>.value(const []);
    }
    final pk = plantKey.trim();
    return Stream.fromFuture(
      _reads
          .load(
            companyId: companyId.trim(),
            businessYearId: businessYearId.trim(),
            periodYear: periodYear,
            periodMonth: periodMonth,
            plantKey: pk,
          )
          .then((b) {
            final list = List<FinanceOrderProfitabilityDoc>.of(
              b.orderProfitability,
            );
            list.sort((a, c) => a.margin.compareTo(c.margin));
            return list;
          }),
    );
  }

  Stream<List<FinanceProductCostDoc>> watchProductCosts({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    required String plantKey,
  }) {
    if (companyId.trim().isEmpty || businessYearId.trim().isEmpty) {
      return Stream<List<FinanceProductCostDoc>>.value(const []);
    }
    final pk = plantKey.trim();
    return Stream.fromFuture(
      _reads
          .load(
            companyId: companyId.trim(),
            businessYearId: businessYearId.trim(),
            periodYear: periodYear,
            periodMonth: periodMonth,
            plantKey: pk,
          )
          .then((b) {
            final list = List<FinanceProductCostDoc>.of(b.productCosts);
            list.sort((a, c) => a.margin.compareTo(c.margin));
            return list;
          }),
    );
  }

  Stream<List<FinanceMachineCostDoc>> watchMachineCosts({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    required String plantKey,
  }) {
    if (companyId.trim().isEmpty || businessYearId.trim().isEmpty) {
      return Stream<List<FinanceMachineCostDoc>>.value(const []);
    }
    final pk = plantKey.trim();
    return Stream.fromFuture(
      _reads
          .load(
            companyId: companyId.trim(),
            businessYearId: businessYearId.trim(),
            periodYear: periodYear,
            periodMonth: periodMonth,
            plantKey: pk,
          )
          .then((b) {
            final list = List<FinanceMachineCostDoc>.of(b.machineCosts);
            list.sort((a, c) => c.totalCost.compareTo(a.totalCost));
            return list;
          }),
    );
  }

  Stream<List<FinanceQualityCostDoc>> watchQualityCosts({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    required String plantKey,
  }) {
    if (companyId.trim().isEmpty || businessYearId.trim().isEmpty) {
      return Stream<List<FinanceQualityCostDoc>>.value(const []);
    }
    final pk = plantKey.trim();
    return Stream.fromFuture(
      _reads
          .load(
            companyId: companyId.trim(),
            businessYearId: businessYearId.trim(),
            periodYear: periodYear,
            periodMonth: periodMonth,
            plantKey: pk,
          )
          .then((b) => List<FinanceQualityCostDoc>.of(b.qualityCosts)),
    );
  }

  Stream<List<FinanceRoutingOperationCostDoc>> watchRoutingRollups({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    required String plantKey,
  }) {
    if (companyId.trim().isEmpty || businessYearId.trim().isEmpty) {
      return Stream<List<FinanceRoutingOperationCostDoc>>.value(const []);
    }
    final pk = plantKey.trim();
    return Stream.fromFuture(
      _reads
          .load(
            companyId: companyId.trim(),
            businessYearId: businessYearId.trim(),
            periodYear: periodYear,
            periodMonth: periodMonth,
            plantKey: pk,
          )
          .then((b) {
            final list = b.routingOperationCosts
                .where((r) => r.isRollup)
                .toList();
            list.sort((a, c) {
              final cmp = a.routingId.compareTo(c.routingId);
              if (cmp != 0) return cmp;
              return a.stepOrder.compareTo(c.stepOrder);
            });
            return list;
          }),
    );
  }

  /// Troškovi zastoja za jedan događaj (Callable, jednokratno učitavanje).
  Future<List<FinanceDowntimeEventCostDoc>> fetchDowntimeEventCosts({
    required String companyId,
    required String downtimeEventId,
  }) {
    final cid = companyId.trim();
    final eid = downtimeEventId.trim();
    if (cid.isEmpty || eid.isEmpty) {
      return Future<List<FinanceDowntimeEventCostDoc>>.value(const []);
    }
    return _fetchDowntimeEventCosts(cid, eid);
  }

  Future<List<FinanceDowntimeEventCostDoc>> _fetchDowntimeEventCosts(
    String companyId,
    String downtimeEventId,
  ) async {
    final callable = _functions.httpsCallable(_listDowntimeCostsCallable);
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'downtimeEventId': downtimeEventId,
      'limit': _downtimeEventCostsLimit,
    });

    final data = response.data;
    if (data is! Map) {
      return const [];
    }

    final rawItems = data['items'];
    if (rawItems is! List) {
      return const [];
    }

    final list = <FinanceDowntimeEventCostDoc>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      list.add(FinanceDowntimeEventCostDoc.fromFirestore(id, item));
    }

    list.sort((a, b) {
      if (b.periodYear != a.periodYear) {
        return b.periodYear.compareTo(a.periodYear);
      }
      return b.periodMonth.compareTo(a.periodMonth);
    });
    return list;
  }
}
