import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_downtime_event_cost_doc.dart';
import '../models/finance_machine_cost_doc.dart';
import '../models/finance_order_profitability_doc.dart';
import '../models/finance_product_cost_doc.dart';
import '../models/finance_quality_cost_doc.dart';
import '../models/finance_routing_operation_cost_doc.dart';
import 'finance_controlling_period_read_service.dart';

/// Čitanje izvedenih agregata: period + pogon preko Callable [fetchFinanceControllingPeriodReads].
class FinanceDerivedAggregatesService {
  FinanceDerivedAggregatesService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  final FinanceControllingPeriodReadService _reads =
      FinanceControllingPeriodReadService();

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

  /// Troškovi zastoja za jedan događaj (više redaka ako postoji više KPI perioda).
  Stream<List<FinanceDowntimeEventCostDoc>> watchDowntimeEventCosts({
    required String companyId,
    required String downtimeEventId,
  }) {
    final cid = companyId.trim();
    final eid = downtimeEventId.trim();
    if (cid.isEmpty || eid.isEmpty) {
      return Stream<List<FinanceDowntimeEventCostDoc>>.value(const []);
    }
    return _db
        .collection('finance_downtime_event_costs')
        .where('companyId', isEqualTo: cid)
        .where('downtimeEventId', isEqualTo: eid)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map(
                (d) =>
                    FinanceDowntimeEventCostDoc.fromFirestore(d.id, d.data()),
              )
              .toList();
          list.sort((a, b) {
            if (b.periodYear != a.periodYear) {
              return b.periodYear.compareTo(a.periodYear);
            }
            return b.periodMonth.compareTo(a.periodMonth);
          });
          return list;
        });
  }
}
