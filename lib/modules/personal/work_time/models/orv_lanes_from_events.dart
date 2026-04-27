import 'package:production_app/modules/personal/work_time/models/orv_demo_data.dart';

/// Stvara trake za mrežu iz otkučaja (in/out) za jednog radnika; plan (ZRV) iz demo baze.
///
/// Izvor istine za sate u Callable sloju je [work_time_daily_summary]; ovdje je mreža ilustrativna
/// — crvena traka iz stvarnih događaja, siva iz [baseLanes] gdje postoji.
List<OrvDayLane> orvDayLanesWithEvents({
  required int year,
  required int month,
  required String? employeeDocId,
  required List<OrvDayLane> baseLanes,
  required List<Map<String, dynamic>> monthEvents,
}) {
  if (employeeDocId == null || employeeDocId.isEmpty) {
    return baseLanes;
  }
  final byDay = <int, List<_MsKind>>{};
  for (final e in monthEvents) {
    if ((e['employeeDocId'] ?? '').toString().trim() != employeeDocId) {
      continue;
    }
    final ms = e['occurredAtMs'];
    if (ms is! num) {
      continue;
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    if (dt.year != year || dt.month != month) {
      continue;
    }
    final k = (e['eventKind'] ?? '').toString().toLowerCase().trim();
    final day = dt.day;
    byDay.putIfAbsent(day, () => <_MsKind>[]).add(
          _MsKind(
            ms: ms.toInt(),
            isIn: k == 'in',
          ),
        );
  }
  for (final list in byDay.values) {
    list.sort((a, b) => a.ms.compareTo(b.ms));
  }
  return baseLanes
      .map((lane) {
        final list = byDay[lane.day];
        if (list == null || list.isEmpty) {
          return lane;
        }
        double? wFrom;
        double? wTo;
        final stack = <double>[];
        for (final x in list) {
          if (x.isIn) {
            stack.add(_hourFloatFromMs(x.ms));
          } else {
            if (stack.isEmpty) {
              continue;
            }
            final a = stack.removeLast();
            final b = _hourFloatFromMs(x.ms);
              wFrom = wFrom == null ? a : (a < wFrom ? a : wFrom);
              wTo = wTo == null ? b : (b > wTo ? b : wTo);
          }
        }
        final unclosedIn = stack.isNotEmpty;
        var workFrom = wFrom ?? 0.0;
        var workTo = wTo ?? 0.0;
        if (wFrom != null && wTo != null && workTo < workFrom) {
          workTo = workFrom;
        }
        final hasPair = wFrom != null && wTo != null;
        return OrvDayLane(
          day: lane.day,
          dayLabel: lane.dayLabel,
          isWeekend: lane.isWeekend,
          zrv: lane.zrv,
          zrvStartLabel: lane.zrvStartLabel,
          zrvEndLabel: lane.zrvEndLabel,
          absence: lane.absence,
          hasRowError: lane.hasRowError ||
              unclosedIn ||
              (list.isNotEmpty && !hasPair),
          scheduleFromHour: lane.scheduleFromHour,
          scheduleToHour: lane.scheduleToHour,
          workFromHour: workFrom,
          workToHour: workTo,
        );
      })
      .toList();
}

class _MsKind {
  const _MsKind({required this.ms, required this.isIn});
  final int ms;
  final bool isIn;
}

double _hourFloatFromMs(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return d.hour + d.minute / 60.0 + d.second / 3600.0;
}
