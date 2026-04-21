import 'package:timezone/timezone.dart' as tz;

import '../models/shift_context.dart';

/// Isto kao Cloud Function [SHIFT_EVENT_TZ] u `ooe_shift_recompute.js` (Luxon).
///
/// OOE prozor događaja za sažetak — jedna zona za klijent i backend.
const String kOoeShiftEventTimeZoneId = 'Europe/Sarajevo';

/// Vremenski interval za filtriranje događaja prilikom agregacije (Callable, klijentski pregled).
class ShiftEventWindow {
  const ShiftEventWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

/// Iz [ShiftContext.plannedStartAt] / [ShiftContext.plannedEndAt] gradi prozor na odabrani kalendarski dan
/// u zoni [kOoeShiftEventTimeZoneId] (usklađeno s Firebase Callable).
///
/// Zahtijeva `timezone` inicijalizaciju (`initializeTimeZones()` u `main.dart`).
/// Ako nedostaje kontekst ili planirana vremena, vraća se **06:00–22:00** u toj zoni na taj dan.
class ShiftContextWindowHelper {
  ShiftContextWindowHelper._();

  static tz.Location? _loc;

  static tz.Location _location() {
    final cached = _loc;
    if (cached != null) return cached;
    _loc = tz.getLocation(kOoeShiftEventTimeZoneId);
    return _loc!;
  }

  static ShiftEventWindow eventWindowForSummary({
    required DateTime shiftCalendarDayLocal,
    ShiftContext? context,
  }) {
    final loc = _location();
    final y = shiftCalendarDayLocal.year;
    final m = shiftCalendarDayLocal.month;
    final d = shiftCalendarDayLocal.day;

    final ctx = context;
    if (ctx != null &&
        ctx.plannedStartAt != null &&
        ctx.plannedEndAt != null) {
      final ps = ctx.plannedStartAt!;
      final pe = ctx.plannedEndAt!;
      final startWall = tz.TZDateTime.from(ps.toUtc(), loc);
      final endWall = tz.TZDateTime.from(pe.toUtc(), loc);

      var start = tz.TZDateTime(
        loc,
        y,
        m,
        d,
        startWall.hour,
        startWall.minute,
        startWall.second,
      );
      var end = tz.TZDateTime(
        loc,
        y,
        m,
        d,
        endWall.hour,
        endWall.minute,
        endWall.second,
      );
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }
      if (end.difference(start).inSeconds >= 60) {
        return ShiftEventWindow(start: start, end: end);
      }
    }

    final defStart = tz.TZDateTime(loc, y, m, d, 6, 0);
    final defEnd = tz.TZDateTime(loc, y, m, d, 22, 0);
    return ShiftEventWindow(start: defStart, end: defEnd);
  }

  /// Kratki opis za UI (bosanski/hrvatski, bez sirovih ID-jeva).
  static String describeLabel(ShiftEventWindow w) {
    final loc = _location();
    final a = tz.TZDateTime.from(w.start, loc);
    final b = tz.TZDateTime.from(w.end, loc);
    String hm(tz.TZDateTime x) {
      final h = x.hour.toString().padLeft(2, '0');
      final m = x.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    var suffix = '';
    if (b.day != a.day || b.month != a.month || b.year != a.year) {
      suffix = ' (kraj sljedećeg kalendarskog dana)';
    }
    return 'Prozor događaja: ${hm(a)}–${hm(b)}$suffix';
  }
}
