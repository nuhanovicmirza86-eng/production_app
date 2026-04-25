import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../packing/services/packing_box_callable_service.dart';
import '../models/production_operator_tracking_entry.dart';
import '../models/tracking_scrap_line.dart';
import 'production_operator_tracking_callable_service.dart';

class ProductionOperatorTrackingService {
  ProductionOperatorTrackingService({
    FirebaseFirestore? firestore,
    PackingBoxCallableService? packingCallable,
    ProductionOperatorTrackingCallableService? trackingCallable,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _packingCallable = packingCallable ?? PackingBoxCallableService(),
        _trackingCallable =
            trackingCallable ?? ProductionOperatorTrackingCallableService();

  final FirebaseFirestore _db;
  final PackingBoxCallableService _packingCallable;
  final ProductionOperatorTrackingCallableService _trackingCallable;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('production_operator_tracking');

  /// Unosi za jedan dan i fazu (npr. samo `preparation`).
  Stream<List<ProductionOperatorTrackingEntry>> watchDayPhase({
    required String companyId,
    required String plantKey,
    required String phase,
    required String workDate,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const Stream.empty();
    }
    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('phase', isEqualTo: phase)
        .where('workDate', isEqualTo: workDate)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(ProductionOperatorTrackingEntry.fromDoc).toList(),
        );
  }

  /// Uživo: sva tri toka (stanice 1–3 / faze) za isti [workDate], spojeno i sortirano po [createdAt] ↓.
  /// Pretplata na Firestore počinje tek kad netko sluša stream.
  Stream<List<ProductionOperatorTrackingEntry>> watchDayAllPhasesMerged({
    required String companyId,
    required String plantKey,
    required String workDate,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const Stream.empty();
    }

    return Stream<List<ProductionOperatorTrackingEntry>>.multi((listener) {
      var prep = <ProductionOperatorTrackingEntry>[];
      var first = <ProductionOperatorTrackingEntry>[];
      var fin = <ProductionOperatorTrackingEntry>[];

      void emit() {
        final merged = [...prep, ...first, ...fin];
        merged.sort((a, b) {
          final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
        if (!listener.isClosed) {
          listener.add(merged);
        }
      }

      final sub1 = watchDayPhase(
        companyId: cid,
        plantKey: pk,
        phase: ProductionOperatorTrackingEntry.phasePreparation,
        workDate: workDate,
      ).listen(
        (v) {
          prep = v;
          emit();
        },
        onError: listener.addError,
      );
      final sub2 = watchDayPhase(
        companyId: cid,
        plantKey: pk,
        phase: ProductionOperatorTrackingEntry.phaseFirstControl,
        workDate: workDate,
      ).listen(
        (v) {
          first = v;
          emit();
        },
        onError: listener.addError,
      );
      final sub3 = watchDayPhase(
        companyId: cid,
        plantKey: pk,
        phase: ProductionOperatorTrackingEntry.phaseFinalControl,
        workDate: workDate,
      ).listen(
        (v) {
          fin = v;
          emit();
        },
        onError: listener.addError,
      );

      listener.onCancel = () {
        sub1.cancel();
        sub2.cancel();
        sub3.cancel();
      };
    });
  }

  /// Jednokratno učitavanje (npr. za PDF) — isti filtri kao [watchDayPhase].
  Future<List<ProductionOperatorTrackingEntry>> fetchDayPhase({
    required String companyId,
    required String plantKey,
    required String phase,
    required String workDate,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const [];
    }
    final snap = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('phase', isEqualTo: phase)
        .where('workDate', isEqualTo: workDate)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(ProductionOperatorTrackingEntry.fromDoc).toList();
  }

  /// Jednokratno: sva tri toka (faze) za isti [workDate].
  Future<List<ProductionOperatorTrackingEntry>> fetchDayAllPhasesMerged({
    required String companyId,
    required String plantKey,
    required String workDate,
  }) async {
    final phases = <String>[
      ProductionOperatorTrackingEntry.phasePreparation,
      ProductionOperatorTrackingEntry.phaseFirstControl,
      ProductionOperatorTrackingEntry.phaseFinalControl,
    ];
    final lists = await Future.wait(
      phases.map(
        (phase) => fetchDayPhase(
          companyId: companyId,
          plantKey: plantKey,
          phase: phase,
          workDate: workDate,
        ),
      ),
    );
    final merged = lists.expand((e) => e).toList();
    merged.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return merged;
  }

  /// Svi unosi jedne faze u rasponu [startWorkDate]–[endWorkDate] (uključivo), `workDate` = `yyyy-MM-dd`.
  Future<List<ProductionOperatorTrackingEntry>> fetchPhaseDateRange({
    required String companyId,
    required String plantKey,
    required String phase,
    required String startWorkDate,
    required String endWorkDate,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];
    final snap = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('phase', isEqualTo: phase)
        .where('workDate', isGreaterThanOrEqualTo: startWorkDate)
        .where('workDate', isLessThanOrEqualTo: endWorkDate)
        .get();
    return snap.docs.map(ProductionOperatorTrackingEntry.fromDoc).toList();
  }

  /// Svi unosi svih triju faza u rasponu [startWorkDate]–[endWorkDate], spojeno i sortirano (datum → createdAt ↓).
  Future<List<ProductionOperatorTrackingEntry>> fetchAllPhasesDateRangeMerged({
    required String companyId,
    required String plantKey,
    required String startWorkDate,
    required String endWorkDate,
  }) async {
    final phases = <String>[
      ProductionOperatorTrackingEntry.phasePreparation,
      ProductionOperatorTrackingEntry.phaseFirstControl,
      ProductionOperatorTrackingEntry.phaseFinalControl,
    ];
    final lists = await Future.wait(
      phases.map(
        (phase) => fetchPhaseDateRange(
          companyId: companyId,
          plantKey: plantKey,
          phase: phase,
          startWorkDate: startWorkDate,
          endWorkDate: endWorkDate,
        ),
      ),
    );
    final merged = <ProductionOperatorTrackingEntry>[];
    for (final l in lists) {
      merged.addAll(l);
    }
    merged.sort((a, b) {
      final wd = a.workDate.compareTo(b.workDate);
      if (wd != 0) return wd;
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return merged;
  }

  /// Snimanje unosa — Callable `createProductionOperatorTrackingEntry` (createdAt samo na serveru).
  Future<void> createEntry({
    required String companyId,
    required String plantKey,
    required String phase,
    required String workDate,
    required String itemCode,
    required String itemName,

    /// Pripremljeno / dobro (bez škarta).
    required double goodQty,
    required String unit,
    String? productId,
    String? workCenterId,
    String? productionOrderId,
    String? commercialOrderId,
    String? rawMaterialOrderCode,
    String? lineOrBatchRef,
    String? releaseToolOrRodRef,
    String? customerName,
    String? rawWorkOperatorName,
    String? preparedByDisplayName,
    String? sourceQrPayload,
    String? notes,
    List<TrackingScrapLine> scrapBreakdown = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Korisnik nije prijavljen.');
    }
    await _trackingCallable.createProductionOperatorTrackingEntry(
      companyId: companyId,
      plantKey: plantKey,
      phase: phase,
      workDate: workDate,
      itemCode: itemCode,
      itemName: itemName,
      goodQty: goodQty,
      unit: unit,
      productId: productId,
      workCenterId: workCenterId,
      productionOrderId: productionOrderId,
      commercialOrderId: commercialOrderId,
      rawMaterialOrderCode: rawMaterialOrderCode,
      lineOrBatchRef: lineOrBatchRef,
      releaseToolOrRodRef: releaseToolOrRodRef,
      customerName: customerName,
      rawWorkOperatorName: rawWorkOperatorName,
      preparedByDisplayName: preparedByDisplayName,
      sourceQrPayload: sourceQrPayload,
      notes: notes,
      scrapBreakdown: scrapBreakdown,
    );
  }

  /// Jedna ispravka vlastitog zapisa (audit u `production_operator_tracking_audit`).
  Future<void> correctEntry({
    required String companyId,
    required ProductionOperatorTrackingEntry entry,
    required String itemCode,
    required String itemName,
    required double goodQty,
    required String unit,
    String? productId,
    String? workCenterId,
    String? productionOrderId,
    String? commercialOrderId,
    String? rawMaterialOrderCode,
    String? lineOrBatchRef,
    String? releaseToolOrRodRef,
    String? customerName,
    String? rawWorkOperatorName,
    String? preparedByDisplayName,
    String? sourceQrPayload,
    String? notes,
    List<TrackingScrapLine> scrapBreakdown = const [],
    String? reason,
  }) async {
    await _trackingCallable.correctProductionOperatorTrackingEntry(
      companyId: companyId,
      entryId: entry.id,
      itemCode: itemCode,
      itemName: itemName,
      goodQty: goodQty,
      unit: unit,
      productId: productId,
      workCenterId: workCenterId,
      productionOrderId: productionOrderId,
      commercialOrderId: commercialOrderId,
      rawMaterialOrderCode: rawMaterialOrderCode,
      lineOrBatchRef: lineOrBatchRef,
      releaseToolOrRodRef: releaseToolOrRodRef,
      customerName: customerName,
      rawWorkOperatorName: rawWorkOperatorName,
      preparedByDisplayName: preparedByDisplayName,
      sourceQrPayload: sourceQrPayload,
      notes: notes,
      scrapBreakdown: scrapBreakdown,
      reason: reason,
    );
  }

  /// Ponovno slanje unosa iz lokalnog reda ([OfflineTrackingQueue]).
  Future<void> createEntryFromQueuePayload(Map<String, dynamic> q) async {
    final scrap = <TrackingScrapLine>[];
    final raw = q['scrapBreakdown'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final s = TrackingScrapLine.tryParse(m);
          if (s != null) scrap.add(s);
        }
      }
    }
    final g = q['goodQty'];
    final goodQty = g is num ? g.toDouble() : double.tryParse('$g') ?? 0.0;

    await createEntry(
      companyId: (q['companyId'] ?? '').toString(),
      plantKey: (q['plantKey'] ?? '').toString(),
      phase: (q['phase'] ?? '').toString(),
      workDate: (q['workDate'] ?? '').toString(),
      itemCode: (q['itemCode'] ?? '').toString(),
      itemName: (q['itemName'] ?? '').toString(),
      goodQty: goodQty,
      unit: (q['unit'] ?? 'kom').toString(),
      productId: _optStr(q['productId']),
      workCenterId: _optStr(q['workCenterId']),
      productionOrderId: _optStr(q['productionOrderId']),
      commercialOrderId: _optStr(q['commercialOrderId']),
      rawMaterialOrderCode: _optStr(q['rawMaterialOrderCode']),
      lineOrBatchRef: _optStr(q['lineOrBatchRef']),
      releaseToolOrRodRef: _optStr(q['releaseToolOrRodRef']),
      customerName: _optStr(q['customerName']),
      rawWorkOperatorName: _optStr(q['rawWorkOperatorName']),
      preparedByDisplayName: _optStr(q['preparedByDisplayName']),
      sourceQrPayload: _optStr(q['sourceQrPayload']),
      notes: _optStr(q['notes']),
      scrapBreakdown: scrap,
    );
  }

  static String? _optStr(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Nakon ispisa etikete kutije — povezuje tracking unose s [packing_boxes] dokumentom (Callable).
  Future<void> setPackedBoxIdForEntries({
    required String companyId,
    required String plantKey,
    required List<String> entryIds,
    required String packedBoxId,
  }) async {
    final pid = packedBoxId.trim();
    if (pid.isEmpty) return;
    final ids = entryIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return;
    await _packingCallable.setTrackingPackedBoxIds(
      companyId: companyId,
      plantKey: plantKey,
      entryIds: ids,
      packedBoxId: pid,
    );
  }
}
