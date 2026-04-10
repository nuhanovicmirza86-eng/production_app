import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../production/production_orders/services/production_order_service.dart';
import '../models/order_model.dart';
import 'order_audit_service.dart';
import 'order_status_engine.dart';

class OrdersService {
  OrdersService({
    FirebaseFirestore? firestore,
    OrderAuditService? orderAuditService,
    OrderStatusEngine? orderStatusEngine,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _orderAuditService =
           orderAuditService ??
           OrderAuditService(
             firestore: firestore ?? FirebaseFirestore.instance,
           ),
       _orderStatusEngine = orderStatusEngine ?? const OrderStatusEngine();

  final FirebaseFirestore _firestore;
  final OrderAuditService _orderAuditService;
  final OrderStatusEngine _orderStatusEngine;

  // ================= COLLECTIONS =================

  CollectionReference get _orders => _firestore.collection('orders');
  CollectionReference get _orderItems => _firestore.collection('order_items');
  CollectionReference get _orderCounters =>
      _firestore.collection('order_counters');

  // ============================================================
  // ======================= PUBLIC API ==========================
  // ============================================================

  Future<String> createOrder({
    required Map<String, dynamic> companyData,
    required String orderType,
    required String partnerId,
    required String partnerCode,
    required String partnerName,
    required DateTime orderDate,
    DateTime? requestedDeliveryDate,
    DateTime? confirmedDeliveryDate,
    String? customerReference,
    String? supplierReference,
    String? plantKey,
    String? receiptPlantKey,
    String? deliveryAddress,
    String? shippingTerms,
    String? currency,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final companyId = _requireCompanyId(companyData);
    final userId = _requireUserId(companyData);

    _validateOrderType(orderType);
    _validateOrderItems(items);

    final orderNumber = await _generateOrderNumber(
      companyId: companyId,
      orderType: orderType,
      generatedBy: userId,
    );

    final orderRef = _orders.doc();

    final headerPayload = _buildOrderHeaderPayload(
      orderId: orderRef.id,
      companyId: companyId,
      orderNumber: orderNumber,
      orderType: orderType,
      partnerId: partnerId,
      partnerCode: partnerCode,
      partnerName: partnerName,
      orderDate: orderDate,
      requestedDeliveryDate: requestedDeliveryDate,
      confirmedDeliveryDate: confirmedDeliveryDate,
      customerReference: customerReference,
      supplierReference: supplierReference,
      plantKey: plantKey,
      receiptPlantKey: receiptPlantKey,
      deliveryAddress: deliveryAddress,
      shippingTerms: shippingTerms,
      currency: currency,
      notes: notes,
      createdBy: userId,
    );

    final batch = _firestore.batch();

    batch.set(orderRef, headerPayload);

    for (final item in items) {
      final itemRef = _orderItems.doc();

      final itemPayload = _buildOrderItemPayload(
        orderItemId: itemRef.id,
        companyId: companyId,
        orderId: orderRef.id,
        orderType: orderType,
        partnerId: partnerId,
        plantKey: plantKey,
        item: item,
        createdBy: userId,
      );

      batch.set(itemRef, itemPayload);
    }

    await batch.commit();

    await recalculateOrderStatus(
      companyId: companyId,
      orderId: orderRef.id,
      updatedBy: userId,
    );

    return orderRef.id;
  }

  Future<Map<String, dynamic>?> getOrderById({
    required String companyId,
    required String orderId,
  }) async {
    final doc = await _orders.doc(orderId).get();

    if (!doc.exists) return null;

    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  Future<List<Map<String, dynamic>>> getOrderItems({
    required String companyId,
    required String orderId,
  }) async {
    final query = await _orderItems
        .where('companyId', isEqualTo: companyId)
        .where('orderId', isEqualTo: orderId)
        .get();

    return query.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<OrderModel>> searchOrders({
    required String companyId,
    String? orderType,
  }) async {
    Query query = _orders.where('companyId', isEqualTo: companyId);

    if (orderType != null && orderType.trim().isNotEmpty) {
      query = query.where('orderType', isEqualTo: orderType.trim());
    }

    final snapshot = await query
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .get();

    return snapshot.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return OrderModel.fromMap(d.id, data);
    }).toList();
  }

  /// Učitava zaglavlje narudžbe i stavke iz kolekcije `order_items` (izvor istine za linije).
  Future<OrderModel?> loadOrderModelWithItems({
    required String companyId,
    required String orderId,
  }) async {
    final header = await getOrderById(companyId: companyId, orderId: orderId);
    if (header == null) return null;

    final rawItems = await getOrderItems(companyId: companyId, orderId: orderId);
    rawItems.sort((a, b) {
      final la = (a['lineId'] ?? '').toString();
      final lb = (b['lineId'] ?? '').toString();
      return la.compareTo(lb);
    });

    final items = rawItems
        .map((m) => OrderItemModel.fromOrderItemRow(m))
        .toList();

    return OrderModel.fromOrderDocument(orderId, header, items: items);
  }

  Future<void> updateOrderStatus({
    required String companyId,
    required String orderId,
    required String newStatus,
    required String updatedBy,
    String? reason,
  }) async {
    final order = await getOrderById(companyId: companyId, orderId: orderId);

    if (order == null) {
      throw Exception('Order not found');
    }

    final orderType = (order['orderType'] ?? '').toString().trim();
    final oldStatus = (order['status'] ?? '').toString().trim();
    final orderNumber = (order['orderNumber'] ?? '').toString().trim();

    _validateOrderType(orderType);
    _orderStatusEngine.validateManualStatusTransition(
      orderType: orderType,
      currentStatus: oldStatus,
      newStatus: newStatus,
    );

    await _orders.doc(orderId).update({
      'status': newStatus,
      'lastStatusChangeAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });

    await _orderAuditService.appendOrderStatusHistory(
      companyId: companyId,
      orderId: orderId,
      orderNumber: orderNumber,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedBy: updatedBy,
      reason: reason,
    );
  }

  Future<void> updateOrderItemExecution({
    required String companyId,
    required String orderId,
    required String orderItemId,
    double? confirmedQty,
    double? deliveredQty,
    double? receivedQty,
    required String updatedBy,
  }) async {
    final order = await getOrderById(companyId: companyId, orderId: orderId);
    if (order == null) {
      throw Exception('Order not found');
    }

    final orderType = (order['orderType'] ?? '').toString().trim();
    _validateOrderType(orderType);

    final itemDoc = await _orderItems.doc(orderItemId).get();
    if (!itemDoc.exists) {
      throw Exception('Order item not found');
    }

    final item = itemDoc.data() as Map<String, dynamic>;

    final orderedQty = _orderStatusEngine.toDouble(item['orderedQty']);
    final nextConfirmedQty =
        confirmedQty ?? _orderStatusEngine.toDouble(item['confirmedQty']);
    final nextDeliveredQty =
        deliveredQty ?? _orderStatusEngine.toDouble(item['deliveredQty']);
    final nextReceivedQty =
        receivedQty ?? _orderStatusEngine.toDouble(item['receivedQty']);
    final dueDate = _orderStatusEngine.toDateTimeOrNull(item['dueDate']);
    final hasProductionLink = (item['hasProductionLink'] ?? false) == true;

    final sanitizedConfirmedQty = _orderStatusEngine.sanitizeQty(
      nextConfirmedQty,
    );
    final sanitizedDeliveredQty = _orderStatusEngine.sanitizeQty(
      nextDeliveredQty,
    );
    final sanitizedReceivedQty = _orderStatusEngine.sanitizeQty(
      nextReceivedQty,
    );

    final openQty = _orderStatusEngine.calculateOpenQty(
      orderType: orderType,
      orderedQty: orderedQty,
      deliveredQty: sanitizedDeliveredQty,
      receivedQty: sanitizedReceivedQty,
    );

    final isLate = _orderStatusEngine.calculateItemIsLate(
      orderType: orderType,
      dueDate: dueDate,
      now: DateTime.now(),
      orderedQty: orderedQty,
      deliveredQty: sanitizedDeliveredQty,
      receivedQty: sanitizedReceivedQty,
    );

    final itemStatus = orderType == 'customer_order'
        ? _orderStatusEngine.calculateCustomerOrderItemStatus(
            orderedQty: orderedQty,
            confirmedQty: sanitizedConfirmedQty,
            deliveredQty: sanitizedDeliveredQty,
            hasProductionLink: hasProductionLink,
            isLate: isLate,
          )
        : _orderStatusEngine.calculateSupplierOrderItemStatus(
            orderedQty: orderedQty,
            confirmedQty: sanitizedConfirmedQty,
            receivedQty: sanitizedReceivedQty,
            isLate: isLate,
          );

    final updateData = <String, dynamic>{
      'confirmedQty': sanitizedConfirmedQty,
      'deliveredQty': sanitizedDeliveredQty,
      'receivedQty': sanitizedReceivedQty,
      'openQty': openQty,
      'status': itemStatus,
      'isLate': isLate,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };

    await _orderItems.doc(orderItemId).update(updateData);

    await recalculateOrderStatus(
      companyId: companyId,
      orderId: orderId,
      updatedBy: updatedBy,
    );
  }

  Future<void> recalculateOrderStatus({
    required String companyId,
    required String orderId,
    required String updatedBy,
  }) async {
    final order = await getOrderById(companyId: companyId, orderId: orderId);
    if (order == null) {
      throw Exception('Order not found');
    }

    final orderType = (order['orderType'] ?? '').toString().trim();
    _validateOrderType(orderType);

    final items = await getOrderItems(companyId: companyId, orderId: orderId);

    final now = DateTime.now();
    final totals = _orderStatusEngine.calculateOrderTotals(items, now: now);
    final oldStatus = (order['status'] ?? '').toString().trim();
    final orderNumber = (order['orderNumber'] ?? '').toString().trim();

    final status = orderType == 'customer_order'
        ? _orderStatusEngine.calculateCustomerOrderStatus(
            currentStatus: oldStatus,
            totalItems: totals.totalItems,
            totalOrderedQty: totals.totalOrderedQty,
            totalConfirmedQty: totals.totalConfirmedQty,
            totalDeliveredQty: totals.totalDeliveredQty,
            hasProductionLink: totals.hasProductionLink,
            isLate: totals.isLate,
          )
        : _orderStatusEngine.calculateSupplierOrderStatus(
            currentStatus: oldStatus,
            totalItems: totals.totalItems,
            totalOrderedQty: totals.totalOrderedQty,
            totalConfirmedQty: totals.totalConfirmedQty,
            totalReceivedQty: totals.totalReceivedQty,
            isLate: totals.isLate,
          );

    await _orders.doc(orderId).update({
      'status': status,
      'totalItemsCount': totals.totalItems,
      'totalOrderedQty': totals.totalOrderedQty,
      'totalDeliveredQty': totals.totalDeliveredQty,
      'totalReceivedQty': totals.totalReceivedQty,
      'hasProductionLink': totals.hasProductionLink,
      'isLate': totals.isLate,
      'lastStatusChangeAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });

    if (oldStatus != status) {
      await _orderAuditService.appendOrderStatusHistory(
        companyId: companyId,
        orderId: orderId,
        orderNumber: orderNumber,
        oldStatus: oldStatus,
        newStatus: status,
        changedBy: updatedBy,
      );
    }
  }

  Future<void> linkOrderToProduction({
    required String companyId,
    required String orderId,
    required String orderItemId,
    required String productionOrderId,
    required String productionOrderCode,
    required String linkedBy,
  }) async {
    final itemRef = _orderItems.doc(orderItemId);

    final itemDoc = await itemRef.get();
    if (!itemDoc.exists) {
      throw Exception('Order item not found');
    }

    final item = itemDoc.data() as Map<String, dynamic>;
    final order = await getOrderById(companyId: companyId, orderId: orderId);
    if (order == null) {
      throw Exception('Order not found');
    }

    await itemRef.update({
      'linkedProductionOrderIds': FieldValue.arrayUnion([productionOrderId]),
      'linkedProductionOrderCodes': FieldValue.arrayUnion([
        productionOrderCode,
      ]),
      'hasProductionLink': true,
      'status': _orderStatusEngine.calculateCustomerOrderItemStatus(
        orderedQty: _orderStatusEngine.toDouble(item['orderedQty']),
        confirmedQty: _orderStatusEngine.toDouble(item['confirmedQty']),
        deliveredQty: _orderStatusEngine.toDouble(item['deliveredQty']),
        hasProductionLink: true,
        isLate: (item['isLate'] ?? false) == true,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': linkedBy,
    });

    await _orderAuditService.appendOrderLinkHistory(
      companyId: companyId,
      orderId: orderId,
      orderItemId: orderItemId,
      productionOrderId: productionOrderId,
      productionOrderCode: productionOrderCode,
      linkedBy: linkedBy,
    );

    await recalculateOrderStatus(
      companyId: companyId,
      orderId: orderId,
      updatedBy: linkedBy,
    );
  }

  /// Kreira draft proizvodni nalog sa poljima sljedljivosti (narudžba → PN) i povezuje stavku narudžbe.
  Future<String> createAndLinkProductionOrderFromOrderItem({
    required Map<String, dynamic> companyData,
    required String orderId,
    required String orderNumber,
    required OrderType orderType,
    required String partnerId,
    required String partnerName,
    required String orderItemDocId,
    required String productId,
    required String productCode,
    required String productName,
    required String unit,
    required String plantKey,
    required DateTime scheduledEndAt,
    required double plannedQty,
    required String bomId,
    required String bomVersion,
    required String routingId,
    required String routingVersion,
  }) async {
    final companyId = _requireCompanyId(companyData);
    final userId = _requireUserId(companyData);

    if (orderItemDocId.trim().isEmpty) {
      throw Exception('Nedostaje ID stavke narudžbe (order_items)');
    }

    final sourceCustomerId =
        orderType == OrderType.customer ? partnerId.trim() : null;
    final sourceCustomerName =
        orderType == OrderType.customer ? partnerName.trim() : null;

    final prodService = ProductionOrderService(firestore: _firestore);

    final productionOrderId = await prodService.createProductionOrder(
      companyId: companyId,
      plantKey: plantKey.trim(),
      productId: productId,
      productCode: productCode,
      productName: productName,
      plannedQty: plannedQty,
      unit: unit,
      bomId: bomId,
      bomVersion: bomVersion,
      routingId: routingId,
      routingVersion: routingVersion,
      createdBy: userId,
      scheduledEndAt: scheduledEndAt,
      customerId: sourceCustomerId?.isEmpty ?? true ? null : sourceCustomerId,
      customerName:
          sourceCustomerName?.isEmpty ?? true ? null : sourceCustomerName,
      sourceOrderId: orderId,
      sourceOrderItemId: orderItemDocId,
      sourceOrderNumber: orderNumber,
      sourceCustomerId: sourceCustomerId?.isEmpty ?? true ? null : sourceCustomerId,
      sourceCustomerName:
          sourceCustomerName?.isEmpty ?? true ? null : sourceCustomerName,
    );

    final poSnap = await _firestore.collection('production_orders').doc(productionOrderId).get();
    final productionOrderCode =
        (poSnap.data()?['productionOrderCode'] ?? '').toString().trim();
    if (productionOrderCode.isEmpty) {
      throw Exception('Proizvodni nalog nema orderCode nakon kreiranja');
    }

    await linkOrderToProduction(
      companyId: companyId,
      orderId: orderId,
      orderItemId: orderItemDocId,
      productionOrderId: productionOrderId,
      productionOrderCode: productionOrderCode,
      linkedBy: userId,
    );

    return productionOrderId;
  }

  // ============================================================
  // ======================= PRIVATE =============================
  // ============================================================

  String _requireCompanyId(Map<String, dynamic> companyData) {
    final cid = (companyData['companyId'] ?? '').toString().trim();
    if (cid.isEmpty) {
      throw Exception('Missing companyId');
    }
    return cid;
  }

  String _requireUserId(Map<String, dynamic> companyData) {
    final uid = (companyData['userId'] ?? '').toString().trim();
    if (uid.isEmpty) {
      throw Exception('Missing userId');
    }
    return uid;
  }

  void _validateOrderType(String orderType) {
    const allowed = ['customer_order', 'supplier_order'];
    if (!allowed.contains(orderType)) {
      throw Exception('Invalid orderType');
    }
  }

  void _validateOrderItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      throw Exception('Order must have at least one item');
    }

    for (final item in items) {
      if ((item['lineId'] ?? '').toString().isEmpty) {
        throw Exception('Missing lineId');
      }
    }
  }

  Future<String> _generateOrderNumber({
    required String companyId,
    required String orderType,
    required String generatedBy,
  }) async {
    final prefix = orderType == 'customer_order' ? 'SO' : 'PO';
    final year = DateTime.now().year;
    final counterDocId = _buildOrderCounterDocId(
      companyId: companyId,
      prefix: prefix,
      year: year,
    );

    final counterRef = _orderCounters.doc(counterDocId);

    final nextSequence = await _firestore.runTransaction<int>((
      transaction,
    ) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {
          'id': counterDocId,
          'companyId': companyId,
          'prefix': prefix,
          'year': year,
          'lastNumber': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': generatedBy,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': generatedBy,
        });
        return 1;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final currentLastNumber = _toInt(data['lastNumber']);
      final nextNumber = currentLastNumber + 1;

      transaction.update(counterRef, {
        'lastNumber': nextNumber,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': generatedBy,
      });

      return nextNumber;
    });

    final formattedSequence = nextSequence.toString().padLeft(6, '0');
    return '$prefix-$year-$formattedSequence';
  }

  String _buildOrderCounterDocId({
    required String companyId,
    required String prefix,
    required int year,
  }) {
    return '${companyId}_${prefix}_$year';
  }

  Map<String, dynamic> _buildOrderHeaderPayload({
    required String orderId,
    required String companyId,
    required String orderNumber,
    required String orderType,
    required String partnerId,
    required String partnerCode,
    required String partnerName,
    required DateTime orderDate,
    DateTime? requestedDeliveryDate,
    DateTime? confirmedDeliveryDate,
    String? customerReference,
    String? supplierReference,
    String? plantKey,
    String? receiptPlantKey,
    String? deliveryAddress,
    String? shippingTerms,
    String? currency,
    String? notes,
    required String createdBy,
  }) {
    return {
      'orderId': orderId,
      'companyId': companyId,
      'orderNumber': orderNumber,
      'orderType': orderType,
      'status': 'confirmed',
      'partnerId': partnerId,
      'partnerCode': partnerCode,
      'partnerName': partnerName,
      'orderDate': Timestamp.fromDate(orderDate),
      'requestedDeliveryDate': requestedDeliveryDate != null
          ? Timestamp.fromDate(requestedDeliveryDate)
          : null,
      'confirmedDeliveryDate': confirmedDeliveryDate != null
          ? Timestamp.fromDate(confirmedDeliveryDate)
          : null,
      'customerReference': customerReference,
      'supplierReference': supplierReference,
      'plantKey': plantKey,
      'receiptPlantKey': receiptPlantKey,
      'deliveryAddress': deliveryAddress,
      'shippingTerms': shippingTerms,
      'currency': currency,
      'notes': notes,
      'totalItemsCount': 0,
      'totalOrderedQty': 0.0,
      'totalDeliveredQty': 0.0,
      'totalReceivedQty': 0.0,
      'hasProductionLink': false,
      'isLate': false,
      'lastStatusChangeAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': createdBy,
    };
  }

  Map<String, dynamic> _buildOrderItemPayload({
    required String orderItemId,
    required String companyId,
    required String orderId,
    required String orderType,
    required String partnerId,
    String? plantKey,
    required Map<String, dynamic> item,
    required String createdBy,
  }) {
    return {
      'orderItemId': orderItemId,
      'companyId': companyId,
      'orderId': orderId,
      'orderType': orderType,
      'partnerId': partnerId,
      'plantKey': plantKey,
      'lineId': item['lineId'],
      'itemType': item['itemType'],
      if ((item['productId'] ?? '').toString().trim().isNotEmpty)
        'productId': item['productId'].toString().trim(),
      'code': item['code'],
      'name': item['name'],
      'orderedQty': _orderStatusEngine.toDouble(item['orderedQty']),
      'confirmedQty': 0.0,
      'deliveredQty': 0.0,
      'receivedQty': 0.0,
      'openQty': _orderStatusEngine.toDouble(item['orderedQty']),
      'unit': item['unit'],
      'unitPrice': _orderStatusEngine.toDouble(item['unitPrice']),
      'dueDate': _toTimestampOrNull(item['dueDate']),
      'status': 'confirmed',
      'hasProductionLink': false,
      'isLate': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': createdBy,
    };
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  Timestamp? _toTimestampOrNull(dynamic value) {
    final date = _orderStatusEngine.toDateTimeOrNull(value);
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}
