import '../models/production_operator_tracking_entry.dart';
import 'production_operator_tracking_service.dart';

/// Agregacija KPI i trenda iz `production_operator_tracking` (sve tri faze).
class ProductionTrackingAnalyticsService {
  ProductionTrackingAnalyticsService({
    ProductionOperatorTrackingService? tracking,
  }) : _tracking = tracking ?? ProductionOperatorTrackingService();

  final ProductionOperatorTrackingService _tracking;

  static String workDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Ponedjeljak–nedjelja kalendarskog tjedna koji sadrži [anchor].
  static (DateTime monday, DateTime sunday) currentWeekRange(DateTime anchor) {
    final d = _dateOnly(anchor);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return (monday, sunday);
  }

  /// Početak mjeseca do [anchor] (datum uključivo).
  static (DateTime start, DateTime end) monthToDateRange(DateTime anchor) {
    final d = _dateOnly(anchor);
    final start = DateTime(d.year, d.month, 1);
    return (start, d);
  }

  Future<ProductionTrackingAnalyticsSnapshot> load({
    required String companyId,
    required String plantKey,
    required ProductionTrackingRangeMode mode,
    DateTime? now,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final clock = _dateOnly(now ?? DateTime.now());

    if (cid.isEmpty || pk.isEmpty) {
      return ProductionTrackingAnalyticsSnapshot.empty(mode);
    }

    late final DateTime start;
    late final DateTime end;
    late final List<DateTime> chartDays;

    switch (mode) {
      case ProductionTrackingRangeMode.thisWeek:
        final w = currentWeekRange(clock);
        start = w.$1;
        end = w.$2;
        chartDays = List.generate(
          7,
          (i) => w.$1.add(Duration(days: i)),
        );
      case ProductionTrackingRangeMode.thisMonth:
        final m = monthToDateRange(clock);
        start = m.$1;
        end = m.$2;
        chartDays = [];
        for (var x = m.$1; !x.isAfter(m.$2); x = x.add(const Duration(days: 1))) {
          chartDays.add(x);
        }
    }

    final startKey = workDateKey(start);
    final endKey = workDateKey(end);

    final phases = [
      ProductionOperatorTrackingEntry.phasePreparation,
      ProductionOperatorTrackingEntry.phaseFirstControl,
      ProductionOperatorTrackingEntry.phaseFinalControl,
    ];

    final phaseLists = await Future.wait(
      phases.map(
        (phase) => _tracking.fetchPhaseDateRange(
          companyId: cid,
          plantKey: pk,
          phase: phase,
          startWorkDate: startKey,
          endWorkDate: endKey,
        ),
      ),
    );

    final all = phaseLists.expand((e) => e).toList();

    final byDay = <String, List<ProductionOperatorTrackingEntry>>{};
    for (final e in all) {
      byDay.putIfAbsent(e.workDate, () => []).add(e);
    }

    final trend = <DailyProductionMetric>[];
    for (final day in chartDays) {
      final key = workDateKey(day);
      final entries = byDay[key] ?? const [];
      trend.add(_rollupDay(key, entries));
    }

    final rollup = _rollupDay('period', all);

    final scrapEntries = all.where((e) => e.scrapTotalQty > 0).length;

    return ProductionTrackingAnalyticsSnapshot(
      mode: mode,
      periodStart: start,
      periodEnd: end,
      trend: trend,
      periodYieldPct: rollup.yieldPct,
      periodDefectPct: rollup.defectPct,
      periodGoodQty: rollup.goodQty,
      periodTotalQty: rollup.totalQty,
      scrapEntryCount: scrapEntries,
      totalEntryCount: all.length,
    );
  }

  DailyProductionMetric _rollupDay(
    String key,
    List<ProductionOperatorTrackingEntry> entries,
  ) {
    var totalQty = 0.0;
    var good = 0.0;
    var scrap = 0.0;
    for (final e in entries) {
      totalQty += e.quantity;
      good += e.effectiveGoodQty;
      scrap += e.scrapTotalQty;
    }
    final yieldPct = totalQty > 0 ? (good * 100.0) / totalQty : 0.0;
    final defectPct = totalQty > 0 ? (scrap * 100.0) / totalQty : 0.0;
    return DailyProductionMetric(
      workDateKey: key,
      goodQty: good,
      totalQty: totalQty,
      yieldPct: yieldPct,
      defectPct: defectPct,
    );
  }
}

enum ProductionTrackingRangeMode { thisWeek, thisMonth }

class DailyProductionMetric {
  const DailyProductionMetric({
    required this.workDateKey,
    required this.goodQty,
    required this.totalQty,
    required this.yieldPct,
    required this.defectPct,
  });

  final String workDateKey;
  final double goodQty;
  final double totalQty;
  final double yieldPct;
  final double defectPct;
}

class ProductionTrackingAnalyticsSnapshot {
  const ProductionTrackingAnalyticsSnapshot({
    required this.mode,
    required this.periodStart,
    required this.periodEnd,
    required this.trend,
    required this.periodYieldPct,
    required this.periodDefectPct,
    required this.periodGoodQty,
    required this.periodTotalQty,
    required this.scrapEntryCount,
    required this.totalEntryCount,
  });

  factory ProductionTrackingAnalyticsSnapshot.empty(ProductionTrackingRangeMode mode) {
    final now = DateTime.now();
    return ProductionTrackingAnalyticsSnapshot(
      mode: mode,
      periodStart: now,
      periodEnd: now,
      trend: const [],
      periodYieldPct: 0,
      periodDefectPct: 0,
      periodGoodQty: 0,
      periodTotalQty: 0,
      scrapEntryCount: 0,
      totalEntryCount: 0,
    );
  }

  final ProductionTrackingRangeMode mode;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<DailyProductionMetric> trend;
  final double periodYieldPct;
  final double periodDefectPct;
  final double periodGoodQty;
  final double periodTotalQty;
  final int scrapEntryCount;
  final int totalEntryCount;
}
