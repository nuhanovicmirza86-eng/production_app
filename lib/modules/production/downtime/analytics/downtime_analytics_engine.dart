import '../models/downtime_event_model.dart';

/// Jedan dan u vremenskoj seriji (lokalni kalendar).
class DowntimeDailyBucket {
  final DateTime dayLocal;
  final int eventCount;
  final int minutesClipped;
  final int minutesOee;
  final int minutesOoe;
  final int minutesTeep;

  const DowntimeDailyBucket({
    required this.dayLocal,
    required this.eventCount,
    required this.minutesClipped,
    required this.minutesOee,
    required this.minutesOoe,
    required this.minutesTeep,
  });
}

/// Stavka Pareto analize (npr. kategorija).
class DowntimeParetoRow {
  final String key;
  final String label;
  final int minutes;
  final int count;
  final double pctOfTotalMinutes;
  final double cumulativePct;

  const DowntimeParetoRow({
    required this.key,
    required this.label,
    required this.minutes,
    required this.count,
    required this.pctOfTotalMinutes,
    required this.cumulativePct,
  });
}

/// Ponavljajući razlozi u periodu.
class DowntimeRepeatReason {
  final String reason;
  final int occurrences;
  final int totalMinutesClipped;

  const DowntimeRepeatReason({
    required this.reason,
    required this.occurrences,
    required this.totalMinutesClipped,
  });
}

/// Grupna statistika (radni centar, proces, …).
class DowntimeGroupStats {
  final String key;
  final String label;
  final int events;
  final int minutesClipped;
  final int minutesOee;
  final int minutesOoe;
  final int minutesTeep;

  const DowntimeGroupStats({
    required this.key,
    required this.label,
    required this.events,
    required this.minutesClipped,
    required this.minutesOee,
    required this.minutesOoe,
    required this.minutesTeep,
  });
}

/// Potpuni analitički izvještaj za [rangeStart, rangeEndExclusive) u lokalnom vremenu.
class DowntimeAnalyticsReport {
  final DateTime rangeStart;
  final DateTime rangeEndExclusive;
  final bool includeRejected;

  final int eventsTouchingPeriod;
  final int totalMinutesClipped;
  final int minutesOeeLoss;
  final int minutesOoeLoss;
  final int minutesTeepLoss;
  final int plannedMinutes;
  final int unplannedMinutes;

  final Map<String, int> countByStatus;
  final Map<String, int> minutesBySeverity;

  final List<DowntimeDailyBucket> byDay;
  final List<DowntimeParetoRow> paretoCategories;
  final List<DowntimeGroupStats> byWorkCenter;
  final List<DowntimeGroupStats> byProcess;
  final List<DowntimeGroupStats> byShift;
  final List<DowntimeRepeatReason> repeatReasons;

  final double? mttrMinutesResolved;
  final int closedForMttrCount;
  final int verifiedCount;
  final int correctiveActionFlagged;

  const DowntimeAnalyticsReport({
    required this.rangeStart,
    required this.rangeEndExclusive,
    required this.includeRejected,
    required this.eventsTouchingPeriod,
    required this.totalMinutesClipped,
    required this.minutesOeeLoss,
    required this.minutesOoeLoss,
    required this.minutesTeepLoss,
    required this.plannedMinutes,
    required this.unplannedMinutes,
    required this.countByStatus,
    required this.minutesBySeverity,
    required this.byDay,
    required this.paretoCategories,
    required this.byWorkCenter,
    required this.byProcess,
    required this.byShift,
    required this.repeatReasons,
    required this.mttrMinutesResolved,
    required this.closedForMttrCount,
    required this.verifiedCount,
    required this.correctiveActionFlagged,
  });

  static DateTime _dayStart(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Efektivni kraj segmenta zastoja (otvoreni → [now]).
  static DateTime _eventEndForClip(DowntimeEventModel e, DateTime now) {
    if (e.endedAt != null) return e.endedAt!;
    if (DowntimeEventStatus.isOpenLike(e.status)) return now;
    return e.startedAt;
  }

  /// Minute zastoja koje padaju u [rangeStart, rangeEndExclusive).
  /// Presjek zastoja s analitičkim periodom (lokalno vrijeme).
  static ({DateTime segStart, DateTime segEnd})? clipInterval(
    DowntimeEventModel e,
    DateTime rangeStart,
    DateTime rangeEndExclusive,
    DateTime now,
  ) {
    final s = e.startedAt.toLocal();
    final end = _eventEndForClip(e, now).toLocal();
    final rs = rangeStart.toLocal();
    final re = rangeEndExclusive.toLocal();
    final segStart = s.isAfter(rs) ? s : rs;
    final segEnd = end.isBefore(re) ? end : re;
    if (!segEnd.isAfter(segStart)) return null;
    return (segStart: segStart, segEnd: segEnd);
  }

  static int clippedMinutes(
    DowntimeEventModel e,
    DateTime rangeStart,
    DateTime rangeEndExclusive,
    DateTime now,
  ) {
    final iv = clipInterval(e, rangeStart, rangeEndExclusive, now);
    if (iv == null) return 0;
    return iv.segEnd.difference(iv.segStart).inMinutes.clamp(0, 1 << 28);
  }

  static void _addMinutesToCalendarDays({
    required String eventId,
    required DateTime segStart,
    required DateTime segEnd,
    required DateTime rangeEndExclusive,
    required Map<String, _DayAgg> dayMap,
    required void Function(_DayAgg agg, int partMinutes) fillFlags,
  }) {
    var d = _dayStart(segStart);
    final end = segEnd;
    while (d.isBefore(rangeEndExclusive) && d.isBefore(end)) {
      final next = d.add(const Duration(days: 1));
      final partStart = segStart.isAfter(d) ? segStart : d;
      final partEnd = end.isBefore(next) ? end : next;
      if (partEnd.isAfter(partStart)) {
        final pm = partEnd.difference(partStart).inMinutes;
        if (pm > 0) {
          final dk =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final da = dayMap.putIfAbsent(dk, () => _DayAgg(day: d));
          da.eventIds.add(eventId);
          da.minutes += pm;
          fillFlags(da, pm);
        }
      }
      d = next;
    }
  }

  static bool _includeEvent(
    DowntimeEventModel e,
    bool includeRejected,
  ) {
    if (e.status == DowntimeEventStatus.archived) return false;
    if (!includeRejected && e.status == DowntimeEventStatus.rejected) {
      return false;
    }
    return true;
  }

  static bool _touchesPeriod(
    DowntimeEventModel e,
    DateTime rangeStart,
    DateTime rangeEndExclusive,
    DateTime now,
  ) {
    final s = e.startedAt.toLocal();
    final end = _eventEndForClip(e, now).toLocal();
    final rs = rangeStart.toLocal();
    final re = rangeEndExclusive.toLocal();
    return s.isBefore(re) && end.isAfter(rs);
  }

  static DowntimeAnalyticsReport compute({
    required List<DowntimeEventModel> events,
    required DateTime rangeStart,
    required DateTime rangeEndExclusive,
    required DateTime now,
    bool includeRejected = false,
  }) {
    final rs = _dayStart(rangeStart);
    var re = rangeEndExclusive.toLocal();
    final n = now.toLocal();
    if (re.isAfter(n)) re = n;

    final inPeriod = <DowntimeEventModel>[];
    for (final e in events) {
      if (!_includeEvent(e, includeRejected)) continue;
      if (_touchesPeriod(e, rs, re, n)) {
        inPeriod.add(e);
      }
    }

    var totalMin = 0;
    var oee = 0;
    var ooe = 0;
    var teep = 0;
    var planned = 0;
    var unplanned = 0;

    final countByStatus = <String, int>{};
    final minutesBySeverity = <String, int>{};

    final byCatMin = <String, int>{};
    final byCatCnt = <String, int>{};
    final wcMap = <String, _Agg>{};
    final procMap = <String, _Agg>{};
    final shiftMap = <String, _Agg>{};
    final dayMap = <String, _DayAgg>{};
    final reasonMin = <String, int>{};
    final reasonCnt = <String, int>{};

    final mttrDurations = <double>[];
    var verified = 0;
    var capa = 0;
    var eventsWithMinutes = 0;

    for (final e in inPeriod) {
      final iv = clipInterval(e, rs, re, n);
      if (iv == null) continue;
      final cm = iv.segEnd.difference(iv.segStart).inMinutes.clamp(0, 1 << 28);
      if (cm <= 0) continue;
      eventsWithMinutes++;

      countByStatus[e.status] = (countByStatus[e.status] ?? 0) + 1;
      minutesBySeverity[e.severity] =
          (minutesBySeverity[e.severity] ?? 0) + cm;

      totalMin += cm;
      if (e.affectsOee) oee += cm;
      if (e.affectsOoe) ooe += cm;
      if (e.affectsTeep) teep += cm;
      if (e.isPlanned) {
        planned += cm;
      } else {
        unplanned += cm;
      }

      final cat = e.downtimeCategory.isEmpty ? '—' : e.downtimeCategory;
      byCatMin[cat] = (byCatMin[cat] ?? 0) + cm;
      byCatCnt[cat] = (byCatCnt[cat] ?? 0) + 1;

      final wcKey = e.workCenterId.isEmpty ? e.workCenterCode : e.workCenterId;
      final wcLabel = e.workCenterCode.isNotEmpty
          ? '${e.workCenterCode} · ${e.workCenterName}'
          : (e.workCenterName.isNotEmpty ? e.workCenterName : wcKey);
      _putAgg(wcMap, wcKey, wcLabel, cm, e);

      final pKey = e.processId.isEmpty ? e.processCode : e.processId;
      final pLabel = e.processCode.isNotEmpty
          ? '${e.processCode} · ${e.processName}'
          : (e.processName.isNotEmpty ? e.processName : pKey);
      _putAgg(procMap, pKey, pLabel, cm, e);

      final shKey = e.shiftId.isNotEmpty ? e.shiftId : e.shiftName;
      final shLabel = e.shiftName.isNotEmpty ? e.shiftName : e.shiftId;
      if (shKey.isNotEmpty || shLabel.isNotEmpty) {
        _putAgg(
          shiftMap,
          shKey.isEmpty ? shLabel : shKey,
          shLabel.isEmpty ? shKey : shLabel,
          cm,
          e,
        );
      }

      _addMinutesToCalendarDays(
        eventId: e.id,
        segStart: iv.segStart,
        segEnd: iv.segEnd,
        rangeEndExclusive: re,
        dayMap: dayMap,
        fillFlags: (agg, partMinutes) {
          if (e.affectsOee) agg.oee += partMinutes;
          if (e.affectsOoe) agg.ooe += partMinutes;
          if (e.affectsTeep) agg.teep += partMinutes;
        },
      );

      final rsn = e.downtimeReason.trim().isEmpty
          ? DowntimeCategoryKeys.labelHr(e.downtimeCategory)
          : e.downtimeReason.trim();
      reasonMin[rsn] = (reasonMin[rsn] ?? 0) + cm;
      reasonCnt[rsn] = (reasonCnt[rsn] ?? 0) + 1;

      if (e.status == DowntimeEventStatus.verified) verified++;

      if (e.correctiveActionRequired) capa++;

      if (e.endedAt != null &&
          (e.status == DowntimeEventStatus.resolved ||
              e.status == DowntimeEventStatus.verified)) {
        final started = e.startedAt.toLocal();
        final ended = e.endedAt!.toLocal();
        if (!ended.isBefore(rs) && !started.isAfter(re)) {
          final dur = ended.difference(started).inMinutes.toDouble();
          if (dur >= 0) mttrDurations.add(dur);
        }
      }
    }

    double? mttr;
    if (mttrDurations.isNotEmpty) {
      mttr = mttrDurations.reduce((a, b) => a + b) / mttrDurations.length;
    }

    final byDay = dayMap.values.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    final daily = byDay
        .map(
          (d) => DowntimeDailyBucket(
            dayLocal: d.day,
            eventCount: d.eventIds.length,
            minutesClipped: d.minutes,
            minutesOee: d.oee,
            minutesOoe: d.ooe,
            minutesTeep: d.teep,
          ),
        )
        .toList();

    final pareto = _buildPareto(byCatMin, byCatCnt, totalMin);

    List<DowntimeGroupStats> groupList(Map<String, _Agg> m) {
      final list = m.values
          .map(
            (a) => DowntimeGroupStats(
              key: a.key,
              label: a.label,
              events: a.events,
              minutesClipped: a.minutes,
              minutesOee: a.oee,
              minutesOoe: a.ooe,
              minutesTeep: a.teep,
            ),
          )
          .toList()
        ..sort((a, b) => b.minutesClipped.compareTo(a.minutesClipped));
      return list;
    }

    final repeats = <DowntimeRepeatReason>[];
    reasonCnt.forEach((reason, c) {
      if (c >= 2) {
        repeats.add(
          DowntimeRepeatReason(
            reason: reason,
            occurrences: c,
            totalMinutesClipped: reasonMin[reason] ?? 0,
          ),
        );
      }
    });
    repeats.sort((a, b) => b.occurrences.compareTo(a.occurrences));

    return DowntimeAnalyticsReport(
      rangeStart: rs,
      rangeEndExclusive: re,
      includeRejected: includeRejected,
      eventsTouchingPeriod: eventsWithMinutes,
      totalMinutesClipped: totalMin,
      minutesOeeLoss: oee,
      minutesOoeLoss: ooe,
      minutesTeepLoss: teep,
      plannedMinutes: planned,
      unplannedMinutes: unplanned,
      countByStatus: countByStatus,
      minutesBySeverity: minutesBySeverity,
      byDay: daily,
      paretoCategories: pareto,
      byWorkCenter: groupList(wcMap),
      byProcess: groupList(procMap),
      byShift: groupList(shiftMap),
      repeatReasons: repeats,
      mttrMinutesResolved: mttr,
      closedForMttrCount: mttrDurations.length,
      verifiedCount: verified,
      correctiveActionFlagged: capa,
    );
  }

  static void _putAgg(
    Map<String, _Agg> map,
    String key,
    String label,
    int cm,
    DowntimeEventModel e,
  ) {
    final k = key.isEmpty ? '—' : key;
    final a = map.putIfAbsent(
      k,
      () => _Agg(key: k, label: label.isEmpty ? k : label),
    );
    a.events += 1;
    a.minutes += cm;
    if (e.affectsOee) a.oee += cm;
    if (e.affectsOoe) a.ooe += cm;
    if (e.affectsTeep) a.teep += cm;
  }

  static List<DowntimeParetoRow> _buildPareto(
    Map<String, int> byCatMin,
    Map<String, int> byCatCnt,
    int totalMin,
  ) {
    if (totalMin <= 0 || byCatMin.isEmpty) return const [];

    final rows = <DowntimeParetoRow>[];
    final sorted = byCatMin.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var cum = 0.0;
    for (final e in sorted) {
      final m = e.value;
      final pct = 100.0 * m / totalMin;
      cum += pct;
      rows.add(
        DowntimeParetoRow(
          key: e.key,
          label: DowntimeCategoryKeys.labelHr(e.key),
          minutes: m,
          count: byCatCnt[e.key] ?? 0,
          pctOfTotalMinutes: pct,
          cumulativePct: cum.clamp(0, 100.0),
        ),
      );
    }
    return rows;
  }
}

class _Agg {
  final String key;
  final String label;
  int events = 0;
  int minutes = 0;
  int oee = 0;
  int ooe = 0;
  int teep = 0;

  _Agg({required this.key, required this.label});
}

class _DayAgg {
  final DateTime day;
  final Set<String> eventIds = {};
  int minutes = 0;
  int oee = 0;
  int ooe = 0;
  int teep = 0;

  _DayAgg({required this.day});
}
