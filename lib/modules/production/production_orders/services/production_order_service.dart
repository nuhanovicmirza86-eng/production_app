import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_order_model.dart';
import 'production_order_callable_service.dart';

class ProductionOrderService {
  ProductionOrderService({
    FirebaseFirestore? firestore,
    ProductionOrderCallableService? callables,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _callables = callables ?? ProductionOrderCallableService();

  final FirebaseFirestore _firestore;
  final ProductionOrderCallableService _callables;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('production_orders');

  // ================= PRIVATE =================

  bool _canChangeCriticalFields(String actorRole) {
    return actorRole == 'admin' || actorRole == 'production_manager';
  }

  // ================= CREATE (Callable) =================

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
    return _callables.createProductionOrder(
      companyId: companyId,
      plantKey: plantKey,
      plantCode: plantCode,
      productId: productId,
      productCode: productCode,
      productName: productName,
      plannedQty: plannedQty,
      unit: unit,
      bomId: bomId,
      bomVersion: bomVersion,
      routingId: routingId,
      routingVersion: routingVersion,
      createdBy: createdBy,
      scheduledEndAt: scheduledEndAt,
      customerId: customerId,
      customerName: customerName,
      productionPlanId: productionPlanId,
      productionPlanLineId: productionPlanLineId,
      sourceOrderId: sourceOrderId,
      sourceOrderItemId: sourceOrderItemId,
      sourceOrderNumber: sourceOrderNumber,
      sourceCustomerId: sourceCustomerId,
      sourceCustomerName: sourceCustomerName,
      sourceOrderDate: sourceOrderDate,
      requestedDeliveryDate: requestedDeliveryDate,
      inputMaterialLot: inputMaterialLot,
      workCenterId: workCenterId,
      workCenterCode: workCenterCode,
      workCenterName: workCenterName,
      machineId: machineId,
      lineId: lineId,
    );
  }

  // ================= UPDATE (Callable) =================

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
    if (!_canChangeCriticalFields(actorRole)) {
      throw Exception(
        'Nemaš pravo izmjene količine ili roka izrade proizvodnog naloga',
      );
    }
    final reason = (changeReason ?? '').trim();
    if (reason.isEmpty) {
      throw Exception('Razlog izmjene je obavezan');
    }
    await _callables.updateCritical(
      productionOrderId: productionOrderId,
      companyId: companyId,
      plantKey: plantKey,
      actorUserId: actorUserId,
      actorRole: actorRole,
      plannedQty: plannedQty,
      scheduledEndAt: scheduledEndAt,
      changeReason: reason,
    );
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

    final uid = actorUserId.trim();
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit.');
    }

    await _callables.updateMesAssignment(
      productionOrderId: productionOrderId.trim(),
      companyId: companyId,
      plantKey: plantKey,
      actorUserId: uid,
      workCenterId: workCenterId,
      workCenterCode: workCenterCode,
      workCenterName: workCenterName,
      machineId: machineId,
      lineId: lineId,
    );
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

  // ================= RELEASE (Callable) =================

  Future<void> releaseProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String releasedBy,
  }) async {
    await _callables.release(
      productionOrderId: productionOrderId,
      companyId: companyId,
      plantKey: plantKey,
      releasedBy: releasedBy,
    );
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

  // ================= COMPLETE / CLOSE / CANCEL (Callable) =================

  Future<void> completeProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    await _callables.complete(
      productionOrderId: productionOrderId,
      companyId: companyId,
      plantKey: plantKey,
      actorUserId: actorUserId,
    );
  }

  Future<void> closeProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    await _callables.closeOrder(
      productionOrderId: productionOrderId,
      companyId: companyId,
      plantKey: plantKey,
      actorUserId: actorUserId,
    );
  }

  Future<void> cancelProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    await _callables.cancel(
      productionOrderId: productionOrderId,
      companyId: companyId,
      plantKey: plantKey,
      actorUserId: actorUserId,
    );
  }
}
