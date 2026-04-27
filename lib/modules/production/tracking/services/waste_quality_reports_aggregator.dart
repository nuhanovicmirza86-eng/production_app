import '../config/platform_defect_codes.dart';
import '../models/production_operator_tracking_entry.dart';
import 'production_tracking_analytics_service.dart';

/// Sažetak količina za cijeli odabrani period (sve faze, jedan pogon).
class WasteQualityPeriodSummary {
  const WasteQualityPeriodSummary({
    required this.totalQty,
    required this.goodQty,
    required this.scrapQty,
    required this.entryCount,
  });

  final double totalQty;
  final double goodQty;
  final double scrapQty;
  final int entryCount;

  double get yieldPct => totalQty > 0 ? (goodQty * 100) / totalQty : 0;
  double get defectPct => totalQty > 0 ? (scrapQty * 100) / totalQty : 0;
}

WasteQualityPeriodSummary summarizeWasteQualityPeriod(
  List<ProductionOperatorTrackingEntry> entries,
) {
  var t = 0.0;
  var g = 0.0;
  var s = 0.0;
  for (final e in entries) {
    t += e.quantity;
    g += e.effectiveGoodQty;
    s += e.scrapTotalQty;
  }
  return WasteQualityPeriodSummary(
    totalQty: t,
    goodQty: g,
    scrapQty: s,
    entryCount: entries.length,
  );
}

/// Red izvještaja „Otpad po tipu škarta“.
class WasteByScrapTypeRow {
  const WasteByScrapTypeRow({
    required this.code,
    required this.label,
    required this.qty,
    required this.pctOfTotalScrap,
  });

  final String code;
  final String label;
  final double qty;
  final double pctOfTotalScrap;
}

List<WasteByScrapTypeRow> aggregateWasteByScrapType({
  required List<ProductionOperatorTrackingEntry> entries,
  required Map<String, String> defectDisplayNames,
}) {
  final byCode = <String, double>{};
  for (final e in entries) {
    for (final s in e.scrapBreakdown) {
      final c = s.code.trim().isEmpty ? s.label : s.code;
      byCode[c] = (byCode[c] ?? 0) + s.qty;
    }
  }
  if (byCode.isEmpty) return const [];
  final total = byCode.values.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return const [];
  final rows = <WasteByScrapTypeRow>[];
  for (final e in byCode.entries) {
    final label = displayLabelForScrapCode(e.key, defectDisplayNames);
    final pct = (e.value * 100) / total;
    rows.add(
      WasteByScrapTypeRow(
        code: e.key,
        label: label,
        qty: e.value,
        pctOfTotalScrap: pct,
      ),
    );
  }
  rows.sort((a, b) => b.qty.compareTo(a.qty));
  return rows;
}

/// Red: jedan proizvod na jedan radni dan.
class WasteByProductRow {
  const WasteByProductRow({
    required this.workDateKey,
    required this.productLine,
    required this.subLine,
    required this.goodQty,
    required this.scrapQty,
    required this.totalQty,
  });

  final String workDateKey;
  final String productLine;
  final String? subLine;
  final double goodQty;
  final double scrapQty;
  final double totalQty;

  double get defectPct => totalQty > 0 ? (scrapQty * 100) / totalQty : 0;
}

String _productSortKey(ProductionOperatorTrackingEntry e) {
  final c = e.itemCode.trim();
  final n = e.itemName.trim();
  if (c.isNotEmpty) return c;
  return n.isNotEmpty ? n : '—';
}

List<WasteByProductRow> aggregateWasteByProductPerDay(
  List<ProductionOperatorTrackingEntry> entries,
) {
  final acc = <String, _DayProductAcc>{};
  for (final e in entries) {
    final pk = _productSortKey(e);
    final k = '${e.workDate}\x1E$pk';
    acc.putIfAbsent(
      k,
      () => _DayProductAcc(
        workDate: e.workDate,
        productLine: e.itemName.trim().isNotEmpty
            ? e.itemName.trim()
            : (e.itemCode.trim().isNotEmpty ? e.itemCode.trim() : 'Nije navedeno'),
        subLine: e.itemCode.trim().isNotEmpty && e.itemName.trim().isNotEmpty
            ? e.itemCode.trim()
            : null,
      ),
    );
    final a = acc[k]!;
    a.totalQty += e.quantity;
    a.goodQty += e.effectiveGoodQty;
    a.scrapQty += e.scrapTotalQty;
  }
  final rows = <WasteByProductRow>[];
  for (final a in acc.values) {
    rows.add(
      WasteByProductRow(
        workDateKey: a.workDate,
        productLine: a.productLine,
        subLine: a.subLine,
        goodQty: a.goodQty,
        scrapQty: a.scrapQty,
        totalQty: a.totalQty,
      ),
    );
  }
  int cmpDate(String a, String b) => a.compareTo(b);
  rows.sort((x, y) {
    final d = -cmpDate(x.workDateKey, y.workDateKey);
    if (d != 0) return d;
    return x.productLine.toLowerCase().compareTo(y.productLine.toLowerCase());
  });
  return rows;
}

class _DayProductAcc {
  _DayProductAcc({
    required this.workDate,
    required this.productLine,
    this.subLine,
  });

  final String workDate;
  final String productLine;
  final String? subLine;
  double goodQty = 0;
  double scrapQty = 0;
  double totalQty = 0;
}

/// Točka trenda (jedan dan u nizu za jednu proizvodnu liniju / RC).
class QualityLineDayPoint {
  const QualityLineDayPoint({
    required this.workDateKey,
    required this.defectPct,
    required this.goodQty,
    required this.scrapQty,
  });

  final String workDateKey;
  final double defectPct;
  final double goodQty;
  final double scrapQty;
}

class QualityLineSeries {
  const QualityLineSeries({
    required this.workCenterId,
    required this.lineTitle,
    required this.points,
  });

  final String? workCenterId;
  final String lineTitle;
  final List<QualityLineDayPoint> points;

  double get periodAvgDefect {
    if (points.isEmpty) return 0;
    final withData = points.where((p) => p.goodQty + p.scrapQty > 0).toList();
    if (withData.isEmpty) return 0;
    return withData.map((p) => p.defectPct).reduce((a, b) => a + b) /
        withData.length;
  }

  static bool isDeviation({
    required double dayDefectPct,
    required double periodAvg,
  }) {
    if (dayDefectPct <= 0) return false;
    return dayDefectPct >= 5 && dayDefectPct > periodAvg * 1.2 && periodAvg >= 0;
  }
}

/// [workCenterIdToLineTitle] = prikazni naslov (šifra — naziv), bez sirovih id-ova u UI.
List<QualityLineSeries> aggregateQualityTrendByLine({
  required List<ProductionOperatorTrackingEntry> entries,
  required List<String> workDateKeysChronological,
  required String Function(String? workCenterId) resolveLineTitle,
}) {
  if (workDateKeysChronological.isEmpty) return const [];

  final byWc = <String, List<ProductionOperatorTrackingEntry>>{};
  for (final e in entries) {
    final id = (e.workCenterId ?? '').trim();
    final k = id.isEmpty ? _wcNoneKey : id;
    byWc.putIfAbsent(k, () => []).add(e);
  }

  final out = <QualityLineSeries>[];
  for (final we in byWc.entries) {
    final rawId = we.key == _wcNoneKey ? null : we.key;
    final title = resolveLineTitle(rawId);
    final byDay = <String, List<ProductionOperatorTrackingEntry>>{};
    for (final e in we.value) {
      byDay.putIfAbsent(e.workDate, () => []).add(e);
    }
    final points = <QualityLineDayPoint>[];
    for (final d in workDateKeysChronological) {
      final list = byDay[d] ?? const [];
      var g = 0.0;
      var s = 0.0;
      for (final e in list) {
        g += e.effectiveGoodQty;
        s += e.scrapTotalQty;
      }
      final t = g + s;
      final dPct = t > 0 ? (s * 100) / t : 0.0;
      points.add(
        QualityLineDayPoint(
          workDateKey: d,
          defectPct: dPct,
          goodQty: g,
          scrapQty: s,
        ),
      );
    }
    out.add(
      QualityLineSeries(
        workCenterId: rawId,
        lineTitle: title,
        points: points,
      ),
    );
  }
  out.sort(
    (a, b) => a.lineTitle.toLowerCase().compareTo(b.lineTitle.toLowerCase()),
  );
  return out;
}

const String _wcNoneKey = '__none__';

/// Generira sve `workDate` ključeve od [start] do [end] (uključivo), po danu.
List<String> enumerateWorkDateKeysInRange(DateTime start, DateTime end) {
  final a = DateTime(start.year, start.month, start.day);
  final b = DateTime(end.year, end.month, end.day);
  final out = <String>[];
  for (var d = a; !d.isAfter(b); d = d.add(const Duration(days: 1))) {
    out.add(ProductionTrackingAnalyticsService.workDateKey(d));
  }
  return out;
}
