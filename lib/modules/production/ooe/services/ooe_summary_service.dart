import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ooe_shift_summary.dart';
import 'ooe_shift_summary_callable_service.dart';

/// Čitanje `ooe_shift_summaries`; preračun samo preko Callable [recomputeOoeShiftSummary].
class OoeSummaryService {
  final FirebaseFirestore _firestore;
  final OoeShiftSummaryCallableService _callable;

  OoeSummaryService({
    FirebaseFirestore? firestore,
    OoeShiftSummaryCallableService? callable,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _callable = callable ?? OoeShiftSummaryCallableService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ooe_shift_summaries');

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Serverski preračun (Firebase Functions) — idealni ciklus iz `products.idealCycleTimeSeconds` ako je [productId]/[orderId] zadan.
  ///
  /// Ako [operatingTimeSeconds] nije poslan, Callable koristi [shift_contexts] za taj dan i smjenu, zatim default.
  Future<Map<String, dynamic>> recomputeShiftSummary({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime windowStart,
    required DateTime windowEnd,
    required String shiftId,
    int? operatingTimeSeconds,
    double? idealCycleTimeSeconds,
    String? lineId,
    String? orderId,
    String? productId,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    final mid = _s(machineId);
    if (cid.isEmpty || pk.isEmpty || mid.isEmpty) {
      throw Exception('companyId, plantKey i machineId su obavezni.');
    }

    final shiftDateLocal = DateTime(
      windowStart.year,
      windowStart.month,
      windowStart.day,
    );

    return _callable.recomputeShiftSummary(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
      windowStart: windowStart,
      windowEnd: windowEnd,
      shiftDateLocal: shiftDateLocal,
      shiftId: shiftId,
      operatingTimeSeconds: operatingTimeSeconds,
      productId: productId,
      orderId: orderId,
      lineId: lineId,
      idealCycleTimeSeconds: idealCycleTimeSeconds,
    );
  }

  Stream<List<OoeShiftSummary>> watchSummariesForMachineRecent({
    required String companyId,
    required String plantKey,
    required String machineId,
    int limit = 30,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    final mid = _s(machineId);

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('machineId', isEqualTo: mid)
        .orderBy('shiftDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(OoeShiftSummary.fromDoc).toList());
  }

  /// Isti kalendarski dan kao u Callable (`shiftDate` = UTC 12:00 za taj dan) —
  /// svi sažeci smjena (npr. DAY, NIGHT) za jednu mašinu.
  Stream<List<OoeShiftSummary>> watchSummariesForMachineOnCalendarDay({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime calendarDay,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    final mid = _s(machineId);
    final y = calendarDay.year;
    final m = calendarDay.month;
    final d = calendarDay.day;
    final anchorUtc = DateTime.utc(y, m, d, 12);
    final ts = Timestamp.fromDate(anchorUtc);

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('machineId', isEqualTo: mid)
        .where('shiftDate', isEqualTo: ts)
        .snapshots()
        .map((s) {
          final list = s.docs.map(OoeShiftSummary.fromDoc).toList();
          list.sort((a, b) {
            final sa = (a.shiftId ?? '').toLowerCase();
            final sb = (b.shiftId ?? '').toLowerCase();
            return sa.compareTo(sb);
          });
          return list;
        });
  }

  /// Isti kalendarski dan — svi sažeci u pogoni (sve mašine, sve smjene).
  Stream<List<OoeShiftSummary>> watchSummariesForPlantOnCalendarDay({
    required String companyId,
    required String plantKey,
    required DateTime calendarDay,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    final y = calendarDay.year;
    final m = calendarDay.month;
    final d = calendarDay.day;
    final anchorUtc = DateTime.utc(y, m, d, 12);
    final ts = Timestamp.fromDate(anchorUtc);

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('shiftDate', isEqualTo: ts)
        .snapshots()
        .map((s) {
          final list = s.docs.map(OoeShiftSummary.fromDoc).toList();
          list.sort((a, b) {
            final mm = a.machineId.compareTo(b.machineId);
            if (mm != 0) return mm;
            final sa = (a.shiftId ?? '').toLowerCase();
            final sb = (b.shiftId ?? '').toLowerCase();
            return sa.compareTo(sb);
          });
          return list;
        });
  }
}
