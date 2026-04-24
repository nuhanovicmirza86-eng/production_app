import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedan zapis u `analytics_downtime_daily` (Callable i/ili noćni Scheduled preračun).
class AnalyticsDowntimeDailyModel {
  const AnalyticsDowntimeDailyModel({
    required this.documentId,
    required this.companyId,
    required this.plantKey,
    required this.summaryDateYmd,
    required this.timeZone,
    required this.totalMinutesClipped,
    required this.eventsWithMinutes,
    required this.minutesOeeLoss,
    required this.minutesOoeLoss,
    required this.minutesTeepLoss,
    required this.plannedMinutes,
    required this.unplannedMinutes,
    required this.paretoTop,
    required this.byWorkCenterTop,
    this.mttrMinutesResolved,
    required this.closedForMttrCount,
    this.calculationVersion,
    this.computedAt,
    this.computedByUid,
    this.recomputeSource,
  });

  final String documentId;
  final String companyId;
  final String plantKey;
  final String summaryDateYmd;
  final String timeZone;
  final int totalMinutesClipped;
  final int eventsWithMinutes;
  final int minutesOeeLoss;
  final int minutesOoeLoss;
  final int minutesTeepLoss;
  final int plannedMinutes;
  final int unplannedMinutes;
  final List<AnalyticsDowntimeParetoItem> paretoTop;
  final List<AnalyticsDowntimeWcItem> byWorkCenterTop;
  final double? mttrMinutesResolved;
  final int closedForMttrCount;
  final String? calculationVersion;
  final DateTime? computedAt;
  final String? computedByUid;

  /// `callable` (ručni Callable) ili `scheduled` (noćni job), ako je u dokumentu.
  final String? recomputeSource;

  static String documentIdFor(
    String companyId,
    String plantKey,
    String summaryDateYmd,
  ) {
    final ymd = summaryDateYmd.trim();
    final base = 'dd_${companyId.trim()}_${plantKey.trim()}_$ymd';
    return base.replaceAll(RegExp(r'[/\\\s]'), '_');
  }

  static AnalyticsDowntimeDailyModel fromDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    return fromMap(d.id, d.data() ?? <String, dynamic>{});
  }

  static AnalyticsDowntimeDailyModel fromMap(
    String id,
    Map<String, dynamic> m,
  ) {
    return AnalyticsDowntimeDailyModel(
      documentId: id,
      companyId: _s(m['companyId']),
      plantKey: _s(m['plantKey']),
      summaryDateYmd: _s(m['summaryDateYmd']),
      timeZone: _s(m['timeZone']),
      totalMinutesClipped: _i(m['totalMinutesClipped']),
      eventsWithMinutes: _i(m['eventsWithMinutes']),
      minutesOeeLoss: _i(m['minutesOeeLoss']),
      minutesOoeLoss: _i(m['minutesOoeLoss']),
      minutesTeepLoss: _i(m['minutesTeepLoss']),
      plannedMinutes: _i(m['plannedMinutes']),
      unplannedMinutes: _i(m['unplannedMinutes']),
      paretoTop: _pareto(m['paretoTop']),
      byWorkCenterTop: _wcList(m['byWorkCenterTop']),
      mttrMinutesResolved: _dOpt(m['mttrMinutesResolved']),
      closedForMttrCount: _i(m['closedForMttrCount']),
      calculationVersion: _n(m['calculationVersion']),
      computedAt: (m['computedAt'] is Timestamp)
          ? (m['computedAt'] as Timestamp).toDate()
          : null,
      computedByUid: _n(m['computedByUid']),
      recomputeSource: _n(m['recomputeSource']),
    );
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();
  static String? _n(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static double? _dOpt(dynamic v) {
    if (v is num) return v.toDouble();
    return null;
  }

  static List<AnalyticsDowntimeParetoItem> _pareto(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is! Map) return null;
          final o = Map<String, dynamic>.from(e);
          return AnalyticsDowntimeParetoItem(
            key: _s(o['key']),
            label: _s(o['label']),
            minutes: _i(o['minutes']),
            count: _i(o['count']),
            pct: (o['pct'] is num) ? (o['pct'] as num).toDouble() : 0,
            cumulativePct: (o['cumulativePct'] is num)
                ? (o['cumulativePct'] as num).toDouble()
                : 0,
          );
        })
        .whereType<AnalyticsDowntimeParetoItem>()
        .toList();
  }

  static List<AnalyticsDowntimeWcItem> _wcList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is! Map) return null;
          final o = Map<String, dynamic>.from(e);
          return AnalyticsDowntimeWcItem(
            key: _s(o['key']),
            label: _s(o['label']),
            events: _i(o['events']),
            minutesClipped: _i(o['minutesClipped']),
            minutesOee: _i(o['minutesOee']),
            minutesOoe: _i(o['minutesOoe']),
            minutesTeep: _i(o['minutesTeep']),
          );
        })
        .whereType<AnalyticsDowntimeWcItem>()
        .toList();
  }
}

class AnalyticsDowntimeParetoItem {
  const AnalyticsDowntimeParetoItem({
    required this.key,
    required this.label,
    required this.minutes,
    required this.count,
    required this.pct,
    required this.cumulativePct,
  });

  final String key;
  final String label;
  final int minutes;
  final int count;
  final double pct;
  final double cumulativePct;
}

class AnalyticsDowntimeWcItem {
  const AnalyticsDowntimeWcItem({
    required this.key,
    required this.label,
    required this.events,
    required this.minutesClipped,
    required this.minutesOee,
    required this.minutesOoe,
    required this.minutesTeep,
  });

  final String key;
  final String label;
  final int events;
  final int minutesClipped;
  final int minutesOee;
  final int minutesOoe;
  final int minutesTeep;
}
