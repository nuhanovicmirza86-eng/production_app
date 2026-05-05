import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_downtime_event_cost_doc.dart';
import '../models/finance_machine_cost_doc.dart';
import '../models/finance_order_profitability_doc.dart';
import '../models/finance_product_cost_doc.dart';
import '../models/finance_quality_cost_doc.dart';
import '../models/finance_routing_operation_cost_doc.dart';

/// Čitanje izvedenih agregata iz [finance_kpi_pipeline] (isti period kao KPI).
class FinanceDerivedAggregatesService {
  FinanceDerivedAggregatesService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Query<Map<String, dynamic>> _periodPlantQuery(
    String collection, {
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    required String plantKey,
  }) {
    final cid = companyId.trim();
    final by = businessYearId.trim();
    final pk = plantKey.trim();
    Query<Map<String, dynamic>> q = _db
        .collection(collection)
        .where('companyId', isEqualTo: cid)
        .where('businessYearId', isEqualTo: by)
        .where('periodYear', isEqualTo: periodYear)
        .where('periodMonth', isEqualTo: periodMonth);
    if (pk.isNotEmpty) {
      q = q.where('plantKey', isEqualTo: pk);
    } else {
      q = q.where('plantKey', isEqualTo: '');
    }
    return q;
  }

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
    return _periodPlantQuery(
      'finance_order_profitability',
      companyId: companyId,
      businessYearId: businessYearId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: plantKey,
    ).snapshots().map((snap) {
      final list = snap.docs
          .map(
            (d) => FinanceOrderProfitabilityDoc.fromFirestore(d.id, d.data()),
          )
          .toList();
      list.sort((a, b) => a.margin.compareTo(b.margin));
      return list;
    });
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
    return _periodPlantQuery(
      'finance_product_costs',
      companyId: companyId,
      businessYearId: businessYearId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: plantKey,
    ).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => FinanceProductCostDoc.fromFirestore(d.id, d.data()))
          .toList();
      list.sort((a, b) => a.margin.compareTo(b.margin));
      return list;
    });
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
    return _periodPlantQuery(
      'finance_machine_costs',
      companyId: companyId,
      businessYearId: businessYearId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: plantKey,
    ).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => FinanceMachineCostDoc.fromFirestore(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.totalCost.compareTo(a.totalCost));
      return list;
    });
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
    return _periodPlantQuery(
      'finance_quality_costs',
      companyId: companyId,
      businessYearId: businessYearId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: plantKey,
    ).snapshots().map(
      (snap) => snap.docs
          .map((d) => FinanceQualityCostDoc.fromFirestore(d.id, d.data()))
          .toList(),
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
    return _periodPlantQuery(
      'finance_routing_operation_costs',
      companyId: companyId,
      businessYearId: businessYearId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: plantKey,
    ).snapshots().map((snap) {
      final list = snap.docs
          .map(
            (d) =>
                FinanceRoutingOperationCostDoc.fromFirestore(d.id, d.data()),
          )
          .where((r) => r.isRollup)
          .toList();
      list.sort((a, b) {
        final c = a.routingId.compareTo(b.routingId);
        if (c != 0) return c;
        return a.stepOrder.compareTo(b.stepOrder);
      });
      return list;
    });
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
