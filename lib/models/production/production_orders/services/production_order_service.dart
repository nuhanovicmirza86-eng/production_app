// lib/modules/production/production_orders/services/production_order_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/production_order_model.dart';

class ProductionOrderService {
  final FirebaseFirestore _firestore;

  ProductionOrderService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _orders => _firestore.collection('production_orders');

  CollectionReference get _snapshots =>
      _firestore.collection('production_order_snapshots');

  // ================= CREATE (DRAFT) =================

  Future<String> createProductionOrder({
    required String companyId,
    required String plantKey,
    required String productionOrderCode,
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
    String? customerId,
    String? customerName,
    String? productionPlanId,
    String? productionPlanLineId,
  }) async {
    final docRef = _orders.doc();

    final now = DateTime.now();

    final order = ProductionOrderModel(
      id: docRef.id,
      companyId: companyId,
      plantKey: plantKey,
      productionOrderCode: productionOrderCode,
      status: 'draft',
      productionPlanId: productionPlanId,
      productionPlanLineId: productionPlanLineId,
      productId: productId,
      productCode: productCode,
      productName: productName,
      customerId: customerId,
      customerName: customerName,
      plannedQty: plannedQty,
      producedGoodQty: 0,
      producedScrapQty: 0,
      producedReworkQty: 0,
      unit: unit,
      bomId: bomId,
      bomVersion: bomVersion,
      routingId: routingId,
      routingVersion: routingVersion,
      machineId: null,
      lineId: null,
      scheduledStartAt: null,
      scheduledEndAt: null,
      releasedAt: null,
      releasedBy: null,
      createdAt: now,
      createdBy: createdBy,
      updatedAt: now,
      updatedBy: createdBy,
    );

    await docRef.set(order.toMap());

    return docRef.id;
  }

  // ================= RELEASE =================

  Future<void> releaseProductionOrder({
    required String productionOrderId,
    required String companyId,
    required String releasedBy,
  }) async {
    final docRef = _orders.doc(productionOrderId);

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(docRef);

      if (!doc.exists) {
        throw Exception('Production order not found');
      }

      final data = doc.data() as Map<String, dynamic>;

      if (data['companyId'] != companyId) {
        throw Exception('Invalid company context');
      }

      if (data['status'] != 'draft') {
        throw Exception('Only draft orders can be released');
      }

      final bomId = data['bomId'];
      final routingId = data['routingId'];

      if (bomId == null || routingId == null) {
        throw Exception('BOM and Routing must exist before release');
      }

      final now = DateTime.now();

      final snapshotRef = _snapshots.doc();

      tx.set(snapshotRef, {
        'companyId': data['companyId'],
        'plantKey': data['plantKey'],
        'productionOrderId': productionOrderId,
        'bomId': data['bomId'],
        'bomVersion': data['bomVersion'],
        'routingId': data['routingId'],
        'routingVersion': data['routingVersion'],
        'createdAt': now,
        'createdBy': releasedBy,
      });

      tx.update(docRef, {
        'status': 'released',
        'releasedAt': now,
        'releasedBy': releasedBy,
        'updatedAt': now,
        'updatedBy': releasedBy,
      });
    });
  }

  // ================= READ LIST =================

  Future<List<ProductionOrderModel>> getOrders({
    required String companyId,
    String? status,
  }) async {
    Query query = _orders
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map(
          (doc) => ProductionOrderModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // ================= READ SINGLE =================

  Future<ProductionOrderModel?> getById(String id) async {
    final doc = await _orders.doc(id).get();

    if (!doc.exists) return null;

    return ProductionOrderModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>,
    );
  }
}
