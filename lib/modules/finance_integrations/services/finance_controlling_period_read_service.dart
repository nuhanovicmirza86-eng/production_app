import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_ai_insight_doc.dart';
import '../models/finance_kpi_snapshot_model.dart';
import '../models/finance_machine_cost_doc.dart';
import '../models/finance_order_profitability_doc.dart';
import '../models/finance_product_cost_doc.dart';
import '../models/finance_quality_cost_doc.dart';
import '../models/finance_routing_operation_cost_doc.dart';

/// Jedan Callable [fetchFinanceControllingPeriodReads] (legacy, Admin SDK) puni sve
/// što hub treba za period/pogon — bez klijentskih Firestore upita na financijske agregate.
class FinanceControllingPeriodReadBundle {
  const FinanceControllingPeriodReadBundle({
    this.kpi,
    required this.orderProfitability,
    required this.productCosts,
    required this.machineCosts,
    required this.qualityCosts,
    required this.routingOperationCosts,
    required this.aiInsights,
  });

  final FinanceKpiSnapshotModel? kpi;
  final List<FinanceOrderProfitabilityDoc> orderProfitability;
  final List<FinanceProductCostDoc> productCosts;
  final List<FinanceMachineCostDoc> machineCosts;
  final List<FinanceQualityCostDoc> qualityCosts;
  final List<FinanceRoutingOperationCostDoc> routingOperationCosts;
  final List<FinanceAiInsightDoc> aiInsights;
}

class FinanceControllingPeriodReadService {
  FinanceControllingPeriodReadService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static final Map<String, FinanceControllingPeriodReadBundle> _cache = {};

  static String _cacheKey({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    required String plantKey,
    required int aiLimit,
  }) {
    return '${companyId.trim()}|${businessYearId.trim()}|$periodYear|$periodMonth|'
        '${plantKey.trim()}|ai=$aiLimit';
  }

  static void clearCache() => _cache.clear();

  /// Nakon „Preračunaj KPI” ili promjene perioda kad treba sve iznova.
  static void invalidatePeriod({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
  }) {
    final prefix =
        '${companyId.trim()}|${businessYearId.trim()}|$periodYear|$periodMonth|'
        '${plantKey.trim()}|';
    _cache.removeWhere((k, _) => k.startsWith(prefix));
  }

  Future<FinanceControllingPeriodReadBundle> load({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
    int aiInsightsLimit = 12,
    bool force = false,
  }) async {
    final lim = aiInsightsLimit.clamp(1, 50);
    final key = _cacheKey(
      companyId: companyId,
      businessYearId: businessYearId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: plantKey,
      aiLimit: lim,
    );
    if (!force && _cache.containsKey(key)) {
      return _cache[key]!;
    }

    final res = await _functions
        .httpsCallable('fetchFinanceControllingPeriodReads')
        .call(<String, dynamic>{
          'companyId': companyId.trim(),
          'businessYearId': businessYearId.trim(),
          'periodYear': periodYear,
          'periodMonth': periodMonth,
          'plantKey': plantKey.trim(),
          'includeKpi': true,
          'includeDerived': true,
          'includeAiInsights': true,
          'aiInsightsLimit': lim,
        });

    final raw = res.data;
    if (raw is! Map) {
      throw StateError('Neočekivani odgovor poslužitelja.');
    }
    final m = Map<String, dynamic>.from(raw);
    if (m['ok'] != true) {
      throw StateError('Učitavanje financijskih podataka nije uspjelo.');
    }

    FinanceKpiSnapshotModel? kpi;
    final kRaw = m['kpiSnapshot'];
    if (kRaw is Map) {
      final km = Map<String, dynamic>.from(kRaw);
      final id = (km['id'] ?? '').toString();
      final data = km['data'];
      if (id.isNotEmpty && data is Map) {
        kpi = FinanceKpiSnapshotModel.fromFirestore(
          id,
          Map<String, dynamic>.from(data),
        );
      }
    }

    List<FinanceOrderProfitabilityDoc> orders = [];
    List<FinanceProductCostDoc> products = [];
    List<FinanceMachineCostDoc> machines = [];
    List<FinanceQualityCostDoc> quality = [];
    List<FinanceRoutingOperationCostDoc> routing = [];
    final dRaw = m['derived'];
    if (dRaw is Map) {
      final d = Map<String, dynamic>.from(dRaw);
      orders = _mapDocList(
        d['finance_order_profitability'],
        FinanceOrderProfitabilityDoc.fromFirestore,
      );
      products = _mapDocList(
        d['finance_product_costs'],
        FinanceProductCostDoc.fromFirestore,
      );
      machines = _mapDocList(
        d['finance_machine_costs'],
        FinanceMachineCostDoc.fromFirestore,
      );
      quality = _mapDocList(
        d['finance_quality_costs'],
        FinanceQualityCostDoc.fromFirestore,
      );
      routing = _mapDocList(
        d['finance_routing_operation_costs'],
        FinanceRoutingOperationCostDoc.fromFirestore,
      );
    }

    List<FinanceAiInsightDoc> insights = [];
    final aiRaw = m['aiInsights'];
    if (aiRaw is List) {
      insights = _mapDocList(
        aiRaw,
        FinanceAiInsightDoc.fromFirestore,
      );
    }

    final bundle = FinanceControllingPeriodReadBundle(
      kpi: kpi,
      orderProfitability: orders,
      productCosts: products,
      machineCosts: machines,
      qualityCosts: quality,
      routingOperationCosts: routing,
      aiInsights: insights,
    );
    _cache[key] = bundle;
    return bundle;
  }

  static List<T> _mapDocList<T>(
    dynamic raw,
    T Function(String id, Map<String, dynamic> data) fromFirestore,
  ) {
    if (raw is! List) return [];
    final out = <T>[];
    for (final item in raw) {
      if (item is Map) {
        final o = Map<String, dynamic>.from(item);
        final id = (o['id'] ?? '').toString();
        final dat = o['data'];
        if (id.isNotEmpty && dat is Map) {
          out.add(fromFirestore(id, Map<String, dynamic>.from(dat)));
        }
      }
    }
    return out;
  }
}
