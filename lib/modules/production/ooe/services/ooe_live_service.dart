import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/ooe_live_status.dart';
import 'ooe_live_callable_service.dart';

/// Čitanje / osvježavanje `ooe_live_status` po mašini.
///
/// **Čitanje** Callable-om (`listOoeLiveForPlant` / `getOoeLiveForMachine`):
/// Firestore rules za ovu kolekciju ne dozvoljavaju list/get klijentu.
///
/// **Osvježavanje KPI** Callable-om `refreshOoeLiveStatusForMachine` (bez klijentskog računa i Firestore upisa).
class OoeLiveService {
  factory OoeLiveService({
    FirebaseFunctions? functions,
    OoeLiveCallableService? liveCallable,
  }) {
    final fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');
    return OoeLiveService._(
      fn,
      liveCallable ?? OoeLiveCallableService(functions: fn),
    );
  }

  OoeLiveService._(this._fn, this._liveCallable);

  final FirebaseFunctions _fn;
  final OoeLiveCallableService _liveCallable;

  static const _poll = Duration(seconds: 2);

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

  /// Osvježi KPI za mašinu — backend materijalizira `ooe_live_status` (isti payload kao ranije).
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

    await _liveCallable.refreshOoeLiveStatusForMachine(
      companyId: cid,
      plantKey: pk,
      machineId: mid,
      lineId: lineId,
      activeOrderId: activeOrderId,
      activeProductId: activeProductId,
      shiftId: shiftId,
      idealCycleTimeSeconds: idealCycleTimeSeconds,
    );
  }
}
