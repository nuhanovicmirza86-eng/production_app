import 'production_operator_tracking_entry.dart';

/// Sažetak dnevnih unosa po stanicama (1 = pripremna, 2 = prva kontrola, 3 = završna).
class PhaseStationRollup {
  const PhaseStationRollup({
    required this.phase,
    required this.stationTitle,
    required this.entryCount,
    required this.goodQty,
    required this.totalMass,
    required this.scrapMass,
    required this.scrapEntryCount,
    required this.lastEntryAt,
  });

  final String phase;
  final String stationTitle;
  final int entryCount;
  final double goodQty;
  final double totalMass;
  final double scrapMass;
  final int scrapEntryCount;
  final DateTime? lastEntryAt;

  double get defectMassPct =>
      totalMass > 0 ? (scrapMass * 100.0) / totalMass : 0.0;
}

/// Zbroj stanica 1–3 za KPI „danas (uživo)”.
class TrackingTodayRollup {
  const TrackingTodayRollup({
    required this.station1,
    required this.station2,
    required this.station3,
    required this.total,
  });

  final PhaseStationRollup station1;
  final PhaseStationRollup station2;
  final PhaseStationRollup station3;
  final PhaseStationRollup total;

  static TrackingTodayRollup fromEntries(
    List<ProductionOperatorTrackingEntry> entries,
  ) {
    final p = ProductionOperatorTrackingEntry.phasePreparation;
    final f = ProductionOperatorTrackingEntry.phaseFirstControl;
    final z = ProductionOperatorTrackingEntry.phaseFinalControl;

    PhaseStationRollup roll(String phase, String title, Iterable<ProductionOperatorTrackingEntry> it) {
      var ec = 0;
      var good = 0.0;
      var tot = 0.0;
      var scrap = 0.0;
      var scrapLines = 0;
      DateTime? last;
      for (final e in it) {
        ec++;
        tot += e.quantity;
        good += e.effectiveGoodQty;
        scrap += e.scrapTotalQty;
        if (e.scrapTotalQty > 0) scrapLines++;
        final c = e.createdAt;
        if (c != null) {
          if (last == null || c.isAfter(last)) last = c;
        }
      }
      return PhaseStationRollup(
        phase: phase,
        stationTitle: title,
        entryCount: ec,
        goodQty: good,
        totalMass: tot,
        scrapMass: scrap,
        scrapEntryCount: scrapLines,
        lastEntryAt: last,
      );
    }

    final g1 = entries.where((e) => e.phase == p);
    final g2 = entries.where((e) => e.phase == f);
    final g3 = entries.where((e) => e.phase == z);

    final s1 = roll(p, 'Stanica 1 — Pripremna', g1);
    final s2 = roll(f, 'Stanica 2 — Prva kontrola', g2);
    final s3 = roll(z, 'Stanica 3 — Završna kontrola', g3);

    final tall = roll(
      '',
      'Ukupno (stanice 1–3)',
      entries,
    );

    return TrackingTodayRollup(
      station1: s1,
      station2: s2,
      station3: s3,
      total: tall,
    );
  }
}
