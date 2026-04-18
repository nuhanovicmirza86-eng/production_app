import 'package:cloud_firestore/cloud_firestore.dart';

import '../../production_orders/models/production_order_model.dart';
import '../../tracking/models/production_operator_tracking_entry.dart';
import '../../tracking/services/production_operator_tracking_service.dart';
import '../ai_analysis_payloads.dart';

/// Gradi strukturirane [payload] mape za [runAiAnalysis] iz stvarnih Firestore podataka.
///
/// „SCADA” ovdje = agregat operativnog praćenja (faze, dnevni volumeni), ne PLC telemetrija.
class AiAnalysisSnapshotService {
  AiAnalysisSnapshotService({
    ProductionOperatorTrackingService? tracking,
    FirebaseFirestore? firestore,
  })  : _tracking = tracking ?? ProductionOperatorTrackingService(),
        _db = firestore ?? FirebaseFirestore.instance;

  final ProductionOperatorTrackingService _tracking;
  final FirebaseFirestore _db;

  static String ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static double _scrapSum(ProductionOperatorTrackingEntry e) {
    var s = 0.0;
    for (final line in e.scrapBreakdown) {
      s += line.qty;
    }
    return s;
  }

  /// KPI iz operativnog praćenja: dobro / škart, po fazama, približni „quality %”.
  Future<Map<String, dynamic>> buildOeeStyleFromTracking({
    required String companyId,
    required String plantKey,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = ymd(DateTime(start.year, start.month, start.day));
    final endStr = ymd(DateTime(end.year, end.month, end.day));
    final entries = await _tracking.fetchAllPhasesDateRangeMerged(
      companyId: companyId,
      plantKey: plantKey,
      startWorkDate: startStr,
      endWorkDate: endStr,
    );

    var totalGood = 0.0;
    var totalScrap = 0.0;
    final byPhase = <String, Map<String, dynamic>>{};

    for (final e in entries) {
      totalGood += e.quantity;
      totalScrap += _scrapSum(e);
      final p = e.phase;
      byPhase[p] ??= <String, dynamic>{
        'entryCount': 0,
        'goodQty': 0.0,
        'scrapQty': 0.0,
      };
      byPhase[p]!['entryCount'] = (byPhase[p]!['entryCount'] as int) + 1;
      byPhase[p]!['goodQty'] =
          (byPhase[p]!['goodQty'] as double) + e.quantity;
      byPhase[p]!['scrapQty'] =
          (byPhase[p]!['scrapQty'] as double) + _scrapSum(e);
    }

    final denom = totalGood + totalScrap;
    final qualityPct = denom > 0 ? 100.0 * totalGood / denom : null;

    return <String, dynamic>{
      ...AiAnalysisPayloads.oeeBlock(
        periodLabel: '$startStr – $endStr',
        qualityPct: qualityPct,
        oeePct: null,
        availabilityPct: null,
        performancePct: null,
        losses: <String, dynamic>{
          'totalScrapQty': totalScrap,
          'totalGoodQty': totalGood,
          'byPhase': byPhase,
          'entryCount': entries.length,
        },
        downtimeSummary: <String, dynamic>{
          'note':
              'Planirani zastoji nisu dio ovog izvora; A/P komponente OEE nisu izračunate.',
        },
      ),
      'source': 'production_operator_tracking',
      'plantKey': plantKey,
      'methodologyNote':
          'Agregat iz operativnog praćenja (tri faze). Nije puni MES OEE.',
    };
  }

  /// „SCADA” snimak: dnevni volumeni i aktivnost po fazama (bez PLC tagova).
  Future<Map<String, dynamic>> buildScadaStyleFromTracking({
    required String companyId,
    required String plantKey,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = ymd(DateTime(start.year, start.month, start.day));
    final endStr = ymd(DateTime(end.year, end.month, end.day));
    final entries = await _tracking.fetchAllPhasesDateRangeMerged(
      companyId: companyId,
      plantKey: plantKey,
      startWorkDate: startStr,
      endWorkDate: endStr,
    );

    final byDay = <String, double>{};
    final byPhaseCount = <String, int>{};
    for (final e in entries) {
      byDay[e.workDate] =
          (byDay[e.workDate] ?? 0) + e.quantity + _scrapSum(e);
      byPhaseCount[e.phase] = (byPhaseCount[e.phase] ?? 0) + 1;
    }

    final telemetryPoints = <Map<String, dynamic>>[];
    final days = byDay.keys.toList()..sort();
    for (final day in days) {
      telemetryPoints.add(<String, dynamic>{
        'tag': 'volume_$day',
        'label': 'Ukupno (dobro+škart) za $day',
        'value': byDay[day],
        'unit': 'kom',
      });
    }

    return <String, dynamic>{
      ...AiAnalysisPayloads.scadaSnapshot(
        source: 'production_operator_tracking_aggregate',
        capturedAt: DateTime.now(),
        windowLabel: '$startStr – $endStr',
        deviceStates: <String, dynamic>{
          'phase_activity_entries': byPhaseCount,
          'interpretation':
              'Broj unosa po fazi (preparation / first_control / final_control).',
        },
        telemetryPoints: telemetryPoints,
        alarms: entries.isEmpty
            ? <String, dynamic>{'note': 'Nema unosa u odabranom periodu.'}
            : <String, dynamic>{
                'note':
                    'Nema stvarnih PLC alarma; podaci su iz operativnog praćenja.',
              },
      ),
      'plantKey': plantKey,
      'methodologyNote':
          'Operativni snimak volumena/faza; nije zamjena za SCADA uređaje.',
    };
  }

  /// Tok proizvodnje: uzorak proizvodnih naloga u periodu (createdAt).
  Future<Map<String, dynamic>> buildProductionFlowFromOrders({
    required String companyId,
    required String plantKey,
    required DateTime start,
    required DateTime end,
  }) async {
    final startDt = DateTime(start.year, start.month, start.day);
    final endDt = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
      999,
    );

    final list = await _fetchOrdersLimited(
      companyId: companyId,
      plantKey: plantKey,
      limit: 400,
    );

    final inRange = list.where((o) {
      final c = o.createdAt;
      return !c.isBefore(startDt) && !c.isAfter(endDt);
    }).toList();

    final orders = inRange
        .map(
          (o) => <String, dynamic>{
            'productionOrderCode': o.productionOrderCode,
            'status': o.status,
            'productCode': o.productCode,
            'productName': o.productName,
            'plannedQty': o.plannedQty,
            'producedGoodQty': o.producedGoodQty,
            'producedScrapQty': o.producedScrapQty,
            'unit': o.unit,
            'createdAt': o.createdAt.toIso8601String(),
          },
        )
        .toList();

    double plannedSum = 0;
    double goodSum = 0;
    double scrapSum = 0;
    for (final o in inRange) {
      plannedSum += o.plannedQty;
      goodSum += o.producedGoodQty;
      scrapSum += o.producedScrapQty;
    }

    return <String, dynamic>{
      ...AiAnalysisPayloads.productionFlow(
        label: 'production_orders',
        orders: orders,
        totals: <String, dynamic>{
          'ordersInPeriod': inRange.length,
          'ordersSampledFromFirestore': list.length,
          'sumPlannedQty': plannedSum,
          'sumGoodQty': goodSum,
          'sumScrapQty': scrapSum,
        },
      ),
      'source': 'production_orders',
      'plantKey': plantKey,
      'period': <String, String>{
        'start': startDt.toIso8601String(),
        'end': endDt.toIso8601String(),
      },
      'methodologyNote':
          'Filtrirano po createdAt naloga; uzorak do 400 najnovijih naloga iz Firestorea.',
    };
  }

  Future<List<ProductionOrderModel>> _fetchOrdersLimited({
    required String companyId,
    required String plantKey,
    required int limit,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final snap = await _db
        .collection('production_orders')
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((d) => ProductionOrderModel.fromMap(d.id, d.data()))
        .toList();
  }
}
