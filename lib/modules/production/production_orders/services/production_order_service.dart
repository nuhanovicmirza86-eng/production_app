import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_order_model.dart';

class ProductionOrderService {
  final FirebaseFirestore _firestore;

  ProductionOrderService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('production_orders');

  CollectionReference<Map<String, dynamic>> get _snapshots =>
      _firestore.collection('production_order_snapshots');

  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _firestore.collection('production_order_audit_logs');

  // ================= PRIVATE =================

  static String? _trimOrNull(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// Prefiks u broju naloga: [plantCode] ako je zadan, inače [plantKey] (kompatibilnost).
  String _generateOrderCode({
    required String plantKey,
    String? plantCode,
    required DateTime now,
  }) {
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final millis = now.millisecondsSinceEpoch.toString().substring(8);
    final prefix = (plantCode != null && plantCode.trim().isNotEmpty)
        ? plantCode.trim()
        : plantKey.trim();

    return '$prefix-$year$month$day-$millis';
  }

  bool _canChangeCriticalFields(String actorRole) {
    return actorRole == 'admin' || actorRole == 'production_manager';
  }

  bool _isSameDateTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute &&
        a.second == b.second &&
        a.millisecond == b.millisecond;
  }

  // ================= CREATE =================

  Future<String> createProductionOrder({
    required String companyId,
    required String plantKey,

    /// Šifra pogona za prefiks u `productionOrderCode` (npr. iz companyData). Ako je prazno, koristi se [plantKey].
    String? plantCode,
    required String productId,
    required String productCode,
    required String productName,
    required double plannedQty,
    required String unit,
    required String bomId,
    required String bomVersion,
    required String routingId,
    required String routingVersion,
    required String createdBy,
    required DateTime scheduledEndAt,
    String? customerId,
    String? customerName,
    String? productionPlanId,
    String? productionPlanLineId,
    String? sourceOrderId,
    String? sourceOrderItemId,
    String? sourceOrderNumber,
    String? sourceCustomerId,
    String? sourceCustomerName,
    DateTime? sourceOrderDate,
    DateTime? requestedDeliveryDate,
    String? inputMaterialLot,
    String? workCenterId,
    String? workCenterCode,
    String? workCenterName,
    String? machineId,
    String? lineId,
  }) async {
    final docRef = _orders.doc();
    final now = DateTime.now();

    final orderCode = _generateOrderCode(
      plantKey: plantKey,
      plantCode: plantCode,
      now: now,
    );

    final order = ProductionOrderModel(
      id: docRef.id,
      companyId: companyId,
      plantKey: plantKey,
      productionOrderCode: orderCode,
      status: 'draft',
      productionPlanId: productionPlanId,
      productionPlanLineId: productionPlanLineId,
      productId: productId.trim(),
      productCode: productCode.trim(),
      productName: productName.trim(),
      customerId: customerId,
      customerName: customerName?.trim(),
      sourceOrderId: _trimOrNull(sourceOrderId),
      sourceOrderItemId: _trimOrNull(sourceOrderItemId),
      sourceOrderNumber: _trimOrNull(sourceOrderNumber),
      sourceCustomerId: _trimOrNull(sourceCustomerId),
      sourceCustomerName: _trimOrNull(sourceCustomerName),
      sourceOrderDate: sourceOrderDate,
      requestedDeliveryDate: requestedDeliveryDate,
      plannedQty: plannedQty,
      producedGoodQty: 0,
      producedScrapQty: 0,
      producedReworkQty: 0,
      unit: unit.trim(),
      bomId: bomId.trim(),
      bomVersion: bomVersion.trim(),
      routingId: routingId.trim(),
      routingVersion: routingVersion.trim(),
      machineId: _trimOrNull(machineId),
      lineId: _trimOrNull(lineId),
      workCenterId: _trimOrNull(workCenterId),
      workCenterCode: _trimOrNull(workCenterCode),
      workCenterName: _trimOrNull(workCenterName),
      scheduledStartAt: null,
      scheduledEndAt: scheduledEndAt,
      releasedAt: null,
      releasedBy: null,
      createdAt: now,
      createdBy: createdBy.trim(),
      updatedAt: now,
      updatedBy: createdBy.trim(),
      hasCriticalChanges: false,
      lastChangedAt: null,
      lastChangedBy: null,
      workOrderDate: null,
      workOrderNumber: null,
      plannedLeadDays: null,
      pantheonCode: null,
      palletCount: null,
      piecesPerPallet: null,
      notes: null,
      operationName: null,
      inputMaterialLot: _trimOrNull(inputMaterialLot),
    );

    await docRef.set(order.toMap());

    return docRef.id;
  }

  // ================= UPDATE =================

  Future<void> updateProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
    required String actorRole,
    double? plannedQty,
    DateTime? scheduledEndAt,
    String? changeReason,
  }) async {
    final docRef = _orders.doc(productionOrderId);

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(docRef);

      if (!doc.exists) throw Exception('Proizvodni nalog ne postoji');

      final data = doc.data();
      if (data == null) throw Exception('Podaci naloga nedostaju');

      if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
        throw Exception('Nemaš pristup ovom nalogu');
      }

      final currentPlannedQty = (data['plannedQty'] ?? 0).toDouble();
      final currentScheduledEndAt = (data['scheduledEndAt'] as Timestamp?)
          ?.toDate();

      final hasPlannedQtyChange =
          plannedQty != null && plannedQty != currentPlannedQty;

      final hasScheduledEndAtChange =
          scheduledEndAt != null &&
          !_isSameDateTime(scheduledEndAt, currentScheduledEndAt);

      if (!hasPlannedQtyChange && !hasScheduledEndAtChange) return;

      if (!_canChangeCriticalFields(actorRole)) {
        throw Exception(
          'Nemaš pravo izmjene količine ili roka izrade proizvodnog naloga',
        );
      }

      final reason = (changeReason ?? '').trim();
      if (reason.isEmpty) {
        throw Exception('Razlog izmjene je obavezan');
      }

      final now = DateTime.now();

      final updates = <String, dynamic>{
        'updatedAt': now,
        'updatedBy': actorUserId.trim(),
        'hasCriticalChanges': true,
        'lastChangedAt': now,
        'lastChangedBy': actorUserId.trim(),
      };

      if (hasPlannedQtyChange) {
        updates['plannedQty'] = plannedQty;
      }

      if (hasScheduledEndAtChange) {
        updates['scheduledEndAt'] = scheduledEndAt;
      }

      tx.update(docRef, updates);

      tx.set(_auditLogs.doc(), {
        'companyId': companyId,
        'plantKey': plantKey,
        'productionOrderId': productionOrderId,
        'eventType': 'critical_order_change',
        'reason': reason,
        'changedBy': actorUserId,
        'changedByRole': actorRole,
        'changedAt': now,
        'before': {
          'plannedQty': currentPlannedQty,
          'scheduledEndAt': currentScheduledEndAt,
        },
        'after': {
          'plannedQty': plannedQty ?? currentPlannedQty,
          'scheduledEndAt': scheduledEndAt ?? currentScheduledEndAt,
        },
      });
    });
  }

  /// Postavlja radni centar i opcionalno stroj/liniju na nalogu (samo admin / menadžer proizvodnje).
  Future<void> updateProductionOrderMesAssignment({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
    required String actorRole,
    String? workCenterId,
    String? workCenterCode,
    String? workCenterName,
    String? machineId,
    String? lineId,
  }) async {
    final role = actorRole.trim().toLowerCase();
    if (role != 'admin' && role != 'production_manager') {
      throw Exception(
        'Samo Admin ili Menadžer proizvodnje mogu mijenjati MES dodjelu naloga.',
      );
    }

    final docRef = _orders.doc(productionOrderId.trim());
    final uid = actorUserId.trim();
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit.');
    }

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Proizvodni nalog ne postoji');
      final data = snap.data();
      if (data == null) throw Exception('Podaci naloga nedostaju');
      if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
        throw Exception('Nemaš pristup ovom nalogu');
      }

      final st = (data['status'] ?? '').toString().toLowerCase();
      if (st == 'closed' || st == 'cancelled') {
        throw Exception('Nalog u ovom statusu se ne može mijenjati.');
      }

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'updatedAt': now,
        'updatedBy': uid,
      };

      void putOrDelete(String key, String? v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) {
          updates[key] = FieldValue.delete();
        } else {
          updates[key] = t;
        }
      }

      putOrDelete('workCenterId', workCenterId);
      putOrDelete('workCenterCode', workCenterCode);
      putOrDelete('workCenterName', workCenterName);
      putOrDelete('machineId', machineId);
      putOrDelete('lineId', lineId);

      tx.update(docRef, updates);
    });
  }

  /// Zadnji nalozi vezani uz radni centar (stream za detalje centra).
  Stream<List<ProductionOrderModel>> watchOrdersForWorkCenter({
    required String companyId,
    required String plantKey,
    required String workCenterId,
    int limit = 40,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final wcid = workCenterId.trim();
    if (cid.isEmpty || pk.isEmpty || wcid.isEmpty) {
      return Stream.value(const []);
    }

    return _orders
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('workCenterId', isEqualTo: wcid)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => ProductionOrderModel.fromMap(d.id, d.data()))
              .toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list;
        });
  }

  // ================= RELEASE =================

  Future<void> releaseProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String releasedBy,
  }) async {
    final docRef = _orders.doc(productionOrderId);

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(docRef);

      if (!doc.exists) {
        throw Exception('Proizvodni nalog ne postoji');
      }

      final data = doc.data();

      if (data == null) {
        throw Exception('Podaci naloga nedostaju');
      }

      if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
        throw Exception('Nemaš pristup ovom nalogu');
      }

      if (data['status'] != 'draft') {
        throw Exception('Samo draft nalozi mogu biti pušteni');
      }

      final now = DateTime.now();

      final snapshotRef = _snapshots.doc();

      tx.set(snapshotRef, {
        'companyId': data['companyId'],
        'plantKey': data['plantKey'],
        'productionOrderId': productionOrderId,
        'bomId': data['bomId'],
        'routingId': data['routingId'],
        'createdAt': now,
        'createdBy': releasedBy.trim(),
      });

      tx.update(docRef, {
        'status': 'released',
        'releasedAt': now,
        'releasedBy': releasedBy.trim(),
        'updatedAt': now,
        'updatedBy': releasedBy.trim(),
      });
    });
  }

  // ================= LIST =================

  Future<List<ProductionOrderModel>> getOrders({
    required String companyId,
    required String plantKey,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query = _orders
        .where('companyId', isEqualTo: companyId)
        .where('plantKey', isEqualTo: plantKey)
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => ProductionOrderModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Zadnjih [limit] naloga (npr. odabir pri prijavi zastoja) — manji upit od punog [getOrders].
  Future<List<ProductionOrderModel>> getRecentOrders({
    required String companyId,
    required String plantKey,
    int limit = 100,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final snapshot = await _orders
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => ProductionOrderModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ================= SINGLE =================

  Future<ProductionOrderModel?> getByProductionOrderCode({
    required String companyId,
    required String plantKey,
    required String productionOrderCode,
  }) async {
    final code = productionOrderCode.trim();
    if (code.isEmpty) return null;

    final snapshot = await _orders
        .where('companyId', isEqualTo: companyId)
        .where('plantKey', isEqualTo: plantKey)
        .where('productionOrderCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ProductionOrderModel.fromMap(doc.id, doc.data());
  }

  Future<ProductionOrderModel?> getById({
    required String id,
    required String companyId,
    required String plantKey,
  }) async {
    final doc = await _orders.doc(id).get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
      throw Exception('Nemaš pristup ovom nalogu');
    }

    return ProductionOrderModel.fromMap(doc.id, data);
  }

  /// Učitavanje više naloga paralelno (parovi tenant provjere kao kod [getById]; pogrešan tenant = preskače se).
  Future<Map<String, ProductionOrderModel>> getByIds({
    required String companyId,
    required String plantKey,
    required Iterable<String> ids,
  }) async {
    final list = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      final t = id.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      list.add(t);
    }
    if (list.isEmpty) return {};

    final snapshots = await Future.wait(list.map((id) => _orders.doc(id).get()));
    final out = <String, ProductionOrderModel>{};
    for (var i = 0; i < list.length; i++) {
      final doc = snapshots[i];
      if (!doc.exists) continue;
      final data = doc.data();
      if (data == null) continue;
      if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
        continue;
      }
      out[doc.id] = ProductionOrderModel.fromMap(doc.id, data);
    }
    return out;
  }

  // ================= COMPLETE / CLOSE / CANCEL (LIFECYCLE) =================

  Future<void> completeProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    final docRef = _orders.doc(productionOrderId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Proizvodni nalog ne postoji');
      final data = snap.data();
      if (data == null) throw Exception('Podaci naloga nedostaju');
      if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
        throw Exception('Nemaš pristup ovom nalogu');
      }
      final st = (data['status'] ?? '').toString();
      if (st != 'released' && st != 'in_progress') {
        throw Exception(
          'Nalog se može završiti samo iz statusa Pušten ili U toku.',
        );
      }
      final now = DateTime.now();
      tx.update(docRef, {
        'status': 'completed',
        'updatedAt': now,
        'updatedBy': actorUserId.trim(),
      });
    });
  }

  Future<void> closeProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    final docRef = _orders.doc(productionOrderId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Proizvodni nalog ne postoji');
      final data = snap.data();
      if (data == null) throw Exception('Podaci naloga nedostaju');
      if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
        throw Exception('Nemaš pristup ovom nalogu');
      }
      final st = (data['status'] ?? '').toString();
      if (st != 'completed') {
        throw Exception('Zatvaranje je moguće samo za završene naloge.');
      }
      final now = DateTime.now();
      tx.update(docRef, {
        'status': 'closed',
        'updatedAt': now,
        'updatedBy': actorUserId.trim(),
      });
    });
  }

  Future<void> cancelProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    final docRef = _orders.doc(productionOrderId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Proizvodni nalog ne postoji');
      final data = snap.data();
      if (data == null) throw Exception('Podaci naloga nedostaju');
      if (data['companyId'] != companyId || data['plantKey'] != plantKey) {
        throw Exception('Nemaš pristup ovom nalogu');
      }
      final st = (data['status'] ?? '').toString();
      if (st == 'completed' || st == 'closed' || st == 'cancelled') {
        throw Exception('Nalog se ne može otkazati u ovom statusu.');
      }
      final now = DateTime.now();
      tx.update(docRef, {
        'status': 'cancelled',
        'updatedAt': now,
        'updatedBy': actorUserId.trim(),
      });
    });
  }
}
