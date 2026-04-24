import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
///
/// **Čitanje** s klijenta ide Callable-om (`listOoeLiveForPlant` / `getOoeLiveForMachine`):
/// Firestore rules za ovu kolekciju ne dozvoljavaju list/get — upisi ostaju kroz Firestore.
class OoeLiveService {
  OoeLiveService({
    FirebaseFirestore? firestore,
    OoeLossReasonService? reasons,
    MachineStateService? machineStates,
    ProductionCountService? counts,
    ProductService? products,
    ShiftContextService? shiftContexts,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _reasons = reasons ?? OoeLossReasonService(),
       _machineStates = machineStates ?? MachineStateService(),
       _counts = counts ?? ProductionCountService(),
       _products = products ?? ProductService(),
       _shiftContexts = shiftContexts ?? ShiftContextService(),
       _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final OoeLossReasonService _reasons;
  final MachineStateService _machineStates;
  final ProductionCountService _counts;
  final ProductService _products;
  final ShiftContextService _shiftContexts;
  final FirebaseFunctions _fn;

  static const _poll = Duration(seconds: 2);

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ooe_live_status');

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<List<OoeLiveStatus>> _listViaCallable({
    required String companyId,
    required String plantKey,
  }) async {
    final callable = _fn.httpsCallable('listOoeLiveForPlant');
    final raw = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'plantKey': plantKey,
    });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('listOoeLiveForPlant nije uspio.');
    }
    final items = data['items'];
    if (items is! List) {
      return const <OoeLiveStatus>[];
    }
    final out = <OoeLiveStatus>[];
    for (final e in items) {
      if (e is! Map) continue;
      final id = (e['id'] ?? '').toString();
      final m = e['data'];
      if (m is! Map) continue;
      out.add(
        OoeLiveStatus.fromMap(
          id,
          Map<String, dynamic>.from(m),
        ),
      );
    }
    out.sort((a, b) => a.machineId.compareTo(b.machineId));
    return out;
  }

  Future<OoeLiveStatus?> _getOneViaCallable({
    required String companyId,
    required String plantKey,
    required String machineId,
  }) async {
    final callable = _fn.httpsCallable('getOoeLiveForMachine');
    final raw = await callable.call<Map<String, dynamic>>({
      'companyId': companyId,
      'plantKey': plantKey,
      'machineId': machineId,
    });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('getOoeLiveForMachine nije uspio.');
    }
    final item = data['item'];
    if (item == null) {
      return null;
    }
    if (item is! Map) {
      return null;
    }
    final id = (item['id'] ?? '').toString();
    final m = item['data'];
    if (m is! Map) {
      return null;
    }
    return OoeLiveStatus.fromMap(id, Map<String, dynamic>.from(m));
  }

  /// Periodično osvježavanje (Callable umjesto Firestore stream).
  Stream<T> _pollStream<T>(Future<T> Function() fetch) {
    var active = true;
    late final StreamController<T> controller;
    void start() {
      Future<void> loop() async {
        while (active) {
          try {
            final v = await fetch();
            if (!active) {
              return;
            }
            if (!controller.isClosed) {
              controller.add(v);
            }
          } catch (e, st) {
            if (active && !controller.isClosed) {
              controller.addError(e, st);
            }
            return;
          }
          if (!active) {
            return;
          }
          await Future<void>.delayed(_poll);
        }
      }

      unawaited(loop());
    }

    controller = StreamController<T>(
      onListen: start,
      onCancel: () {
        active = false;
      },
    );
    return controller.stream;
  }

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
    return _pollStream<OoeLiveStatus?>(
      () => _getOneViaCallable(companyId: cid, plantKey: pk, machineId: mid),
    );
  }

  /// Svi live zapisi za pogon (Callable + poll, umjesto Firestore [snapshots]).
  Stream<List<OoeLiveStatus>> watchLiveForPlant({
    required String companyId,
    required String plantKey,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (cid.isEmpty || pk.isEmpty) {
      return Stream<List<OoeLiveStatus>>.value(const <OoeLiveStatus>[]);
    }
    return _pollStream<List<OoeLiveStatus>>(
      () => _listViaCallable(companyId: cid, plantKey: pk),
    );
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
