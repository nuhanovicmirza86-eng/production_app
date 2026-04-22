import 'package:cloud_firestore/cloud_firestore.dart';

/// Suma polja [goodQty] s [executions] za dani [machineId], pripisana **lokalnom kalendaru [day]**
/// (MES `production_execution`). 
///
/// - Završeno: uzima se dan završetka [endedAt].
/// - U tijeku: ako [endedAt] nema, dan početka [startedAt] i status radni.
double sumLocalDayGoodOnMachine(
  List<Map<String, dynamic>> executions,
  String machineId, {
  required DateTime day,
}) {
  final d = day.toLocal();
  final dayStart = DateTime(d.year, d.month, d.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final want = machineId.trim();
  if (want.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (final e in executions) {
    final m = (e['machineId'] ?? '').toString().trim();
    if (m != want) {
      continue;
    }
    final st = (e['status'] ?? '').toString().toLowerCase();
    final end = e['endedAt'];
    final start = e['startedAt'];
    DateTime? tEnd;
    DateTime? tStart;
    if (end is Timestamp) {
      tEnd = end.toDate().toLocal();
    }
    if (start is Timestamp) {
      tStart = start.toDate().toLocal();
    }
    var include = false;
    if (tEnd != null) {
      if (!tEnd.isBefore(dayStart) && tEnd.isBefore(dayEnd)) {
        include = true;
      }
    } else if (tStart != null) {
      if (st == 'started' || st == 'paused') {
        if (!tStart.isBefore(dayStart) && tStart.isBefore(dayEnd)) {
          include = true;
        }
      }
    }
    if (!include) {
      continue;
    }
    final g = e['goodQty'];
    final gq = g is num ? g.toDouble() : double.tryParse('$g') ?? 0;
    sum += gq;
  }
  return sum;
}
