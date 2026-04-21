import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../products/services/product_service.dart';
import '../models/ooe_live_status.dart';
import '../models/shift_context.dart';
import 'ooe_calculation_service.dart';
import 'ooe_loss_reason_service.dart';
import 'ooe_path_ids.dart';
import 'machine_state_service.dart';
import 'production_count_service.dart';
import 'shift_context_service.dart';
import 'shift_context_window.dart';
/// Čitanje / osvježavanje `ooe_live_status` po mašini.
class OoeLiveService {
  final FirebaseFirestore _firestore;
  final OoeLossReasonService _reasons;
  final MachineStateService _machineStates;
  final ProductionCountService _counts;
  final ProductService _products;
  final ShiftContextService _shiftContexts;

  OoeLiveService({
    FirebaseFirestore? firestore,
    OoeLossReasonService? reasons,
    MachineStateService? machineStates,
    ProductionCountService? counts,
    ProductService? products,
    ShiftContextService? shiftContexts,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _reasons = reasons ?? OoeLossReasonService(),
       _machineStates = machineStates ?? MachineStateService(),
       _counts = counts ?? ProductionCountService(),
       _products = products ?? ProductService(),
       _shiftContexts = shiftContexts ?? ShiftContextService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ooe_live_status');

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Jedan dokument [ooe_live_status] za mašinu (isti KPI kao na dashboardu).
  Stream<OoeLiveStatus?> watchLiveStatusForMachine({
    required String companyId,
    required String plantKey,
    required String machineId,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    final mid = _s(machineId);
    if (cid.isEmpty || pk.isEmpty || mid.isEmpty) {
      return Stream<OoeLiveStatus?>.value(null);
    }
    final docId = OoePathIds.liveStatusDocId(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
    );
    return _col.doc(docId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return OoeLiveStatus.fromMap(mid, data);
    });
  }

  /// Svi live zapisi za pogon (MVP: jedan stream za dashboard).
  Stream<List<OoeLiveStatus>> watchLiveForPlant({
    required String companyId,
    required String plantKey,
  }) {
    return _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => OoeLiveStatus.fromMap(d.id, d.data()))
              .toList();
          return list..sort((a, b) => a.machineId.compareTo(b.machineId));
        });
  }

  /// Osvježi KPI za mašinu: događaji u **prozoru trenutne smjene** ([ShiftContextWindowHelper],
  /// zona [kOoeShiftEventTimeZoneId]), odsječeno do „sada“. Neto operativno vrijeme iz konteksta smjene.
  Future<void> refreshLiveKpiForMachine({
    required String companyId,
    required String plantKey,
    required String machineId,
    String? lineId,
    String? activeOrderId,
    String? activeProductId,
    String? shiftId,
    double? idealCycleTimeSeconds,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    final mid = _s(machineId);
    if (cid.isEmpty || pk.isEmpty || mid.isEmpty) return;

    final now = DateTime.now();
    final loc = tz.getLocation(kOoeShiftEventTimeZoneId);
    final nowZ = tz.TZDateTime.now(loc);
    final shiftCalDay = DateTime(nowZ.year, nowZ.month, nowZ.day);

    final reasonMap = await _reasons.loadActiveReasonByCodeMap(
      companyId: cid,
      plantKey: pk,
    );

    final shiftCode = _s(shiftId).isNotEmpty ? _s(shiftId) : 'DAY';
    ShiftContext? shiftCtx;
    try {
      shiftCtx = await _shiftContexts.getContext(
        companyId: cid,
        plantKey: pk,
        shiftDateLocal: shiftCalDay,
        shiftCode: shiftCode,
      );
    } catch (_) {
      shiftCtx = null;
    }

    final win = ShiftContextWindowHelper.eventWindowForSummary(
      shiftCalendarDayLocal: shiftCalDay,
      context: shiftCtx,
    );

    var fromInv = win.start;
    var toInv = win.end;
    if (now.isBefore(fromInv)) {
      toInv = fromInv;
    } else if (now.isBefore(toInv)) {
      toInv = now;
    }

    final stateEvents = await _machineStates.listEventsForMachineWindow(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
      fromInclusive: fromInv,
      toInclusive: toInv,
    );

    final countEvents = await _counts.listEventsForMachineWindow(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
      fromInclusive: fromInv,
      toInclusive: toInv,
    );

    double total = 0;
    double good = 0;
    double scrap = 0;
    for (final c in countEvents) {
      total += c.totalCountIncrement;
      good += c.goodCountIncrement;
      scrap += c.scrapCountIncrement;
    }

    double? resolvedIdeal = idealCycleTimeSeconds;
    final pid = _nullable(activeProductId);
    if (resolvedIdeal == null && pid != null) {
      try {
        final p = await _products.getProductById(
          productId: pid,
          companyId: cid,
        );
        final v = p?['idealCycleTimeSeconds'];
        if (v is num && v.toDouble() > 0) {
          resolvedIdeal = v.toDouble();
        }
      } catch (_) {}
    }

    final open = await _machineStates.getLatestOpenEventForMachine(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
    );

    var operatingSeconds = OoeCalculationService.defaultOperatingTimeSeconds;
    if (shiftCtx != null &&
        shiftCtx.isWorkingShift &&
        shiftCtx.operatingTimeSeconds > 0) {
      operatingSeconds = shiftCtx.operatingTimeSeconds;
    }

    final calc = OoeCalculationService.compute(
      operatingTimeSeconds: operatingSeconds,
      stateEvents: stateEvents,
      reasonByCode: reasonMap,
      totalCount: total,
      goodCount: good,
      scrapCount: scrap,
      reworkCount: 0,
      idealCycleTimeSeconds: resolvedIdeal,
    );

    final docId = OoePathIds.liveStatusDocId(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
    );

    final live = OoeLiveStatus(
      machineId: mid,
      companyId: cid,
      plantKey: pk,
      lineId: _nullable(lineId),
      currentState: open?.state ?? '',
      currentReasonCode: open?.reasonCode,
      currentReasonName: null,
      currentStateStartedAt: open?.startedAt,
      activeOrderId: _nullable(activeOrderId),
      activeProductId: _nullable(activeProductId),
      currentShiftId: _nullable(shiftId),
      currentShiftOoe: calc.ooe,
      availability: calc.availability,
      performance: calc.performance,
      quality: calc.quality,
      goodCount: good,
      scrapCount: scrap,
      updatedAt: now,
    );

    await _col.doc(docId).set(live.toMap());
  }

  Future<void> writeMinimalLiveStatus({
    required String companyId,
    required String plantKey,
    required String machineId,
    required String currentState,
    String? currentReasonCode,
    String? currentReasonName,
    DateTime? currentStateStartedAt,
    String? activeOrderId,
    String? activeProductId,
    String? shiftId,
    String? lineId,
    double currentShiftOoe = 0,
    double availability = 0,
    double performance = 0,
    double quality = 0,
    double goodCount = 0,
    double scrapCount = 0,
  }) async {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    final mid = _s(machineId);

    final docId = OoePathIds.liveStatusDocId(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
    );

    final live = OoeLiveStatus(
      machineId: mid,
      companyId: cid,
      plantKey: pk,
      lineId: _nullable(lineId),
      currentState: currentState,
      currentReasonCode: currentReasonCode,
      currentReasonName: currentReasonName,
      currentStateStartedAt: currentStateStartedAt,
      activeOrderId: _nullable(activeOrderId),
      activeProductId: _nullable(activeProductId),
      currentShiftId: _nullable(shiftId),
      currentShiftOoe: currentShiftOoe,
      availability: availability,
      performance: performance,
      quality: quality,
      goodCount: goodCount,
      scrapCount: scrapCount,
      updatedAt: DateTime.now(),
    );

    await _col.doc(docId).set(live.toMap());
  }

  String? _nullable(String? v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }
}
