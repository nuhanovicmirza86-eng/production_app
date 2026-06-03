import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../production/production_orders/services/production_order_service.dart';
import '../models/order_model.dart';
import 'order_status_engine.dart';

class OrdersService {
  OrdersService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    OrderStatusEngine? orderStatusEngine,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _orderStatusEngine = orderStatusEngine ?? const OrderStatusEngine();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final OrderStatusEngine _orderStatusEngine;

  Future<Map<String, dynamic>> _callCreateCommercialOrder(
    Map<String, dynamic> payload,
  ) async {
    final res = await _functions
        .httpsCallable('createCommercialOrder')
        .call<Map<String, dynamic>>(payload);
    return res.data;
  }

  Future<Map<String, dynamic>> _callUpdateCommercialOrder(
    Map<String, dynamic> payload,
  ) async {
    final res = await _functions
        .httpsCallable('updateCommercialOrder')
        .call<Map<String, dynamic>>(payload);
    return res.data;
  }

  Future<Map<String, dynamic>> _callListCommercialOrders({
    required String companyId,
    String? orderType,
    int limit = 100,
  }) async {
    final res = await _functions
        .httpsCallable('listCommercialOrders')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          if (orderType != null && orderType.trim().isNotEmpty)
            'orderType': orderType.trim(),
          'limit': limit,
        });
    return res.data;
  }

  Future<Map<String, dynamic>> _callGetCommercialOrder({
    required String companyId,
    required String orderId,
  }) async {
    final res = await _functions
        .httpsCallable('getCommercialOrder')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'orderId': orderId,
        });
    return res.data;
  }

  Future<Map<String, dynamic>> _callListCommercialOrderItemsByCompany({
    required String companyId,
    int limit = 2000,
  }) async {
    final res = await _functions
        .httpsCallable('listCommercialOrderItemsByCompany')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'limit': limit,
        });
    return res.data;
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static Map<String, dynamic> _mapFromDynamic(dynamic raw) {
    if (raw is! Map) return {};
    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static dynamic _jsonSafeDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toIso8601String();
    if (v is Timestamp) return v.toDate().toIso8601String();
    return v;
  }

  Map<String, dynamic> _itemForCallable(Map<String, dynamic> item) {
    final m = Map<String, dynamic>.from(item);
    m['dueDate'] = _jsonSafeDate(m['dueDate']);
    return m;
  }

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
    bool isExport = false,
    String? incoterms,
    String? customerCountryCode,
    String? vatExemptionNote,
    String? customsDeclarationRef,
    String? cmrNumber,
    String? awbNumber,
    required List<Map<String, dynamic>> items,
  }) async {
    final companyId = _requireCompanyId(companyData);

    _validateOrderType(orderType);
    _validateOrderItems(items);

    final payload = <String, dynamic>{
      'companyId': companyId,
      'orderType': orderType,
      'partnerId': partnerId,
      'partnerCode': partnerCode,
      'partnerName': partnerName,
      'orderDate': orderDate.toIso8601String(),
      'requestedDeliveryDate': requestedDeliveryDate?.toIso8601String(),
      'confirmedDeliveryDate': confirmedDeliveryDate?.toIso8601String(),
      'customerReference': customerReference,
      'supplierReference': supplierReference,
      'plantKey': plantKey,
      'receiptPlantKey': receiptPlantKey,
      'deliveryAddress': deliveryAddress,
      'shippingTerms': shippingTerms,
      'currency': currency,
      'notes': notes,
      'isExport': isExport,
      if ((incoterms ?? '').trim().isNotEmpty) 'incoterms': incoterms!.trim(),
      if ((customerCountryCode ?? '').trim().isNotEmpty)
        'customerCountryCode': customerCountryCode!.trim().toUpperCase(),
      if ((vatExemptionNote ?? '').trim().isNotEmpty)
        'vatExemptionNote': vatExemptionNote!.trim(),
      if ((customsDeclarationRef ?? '').trim().isNotEmpty)
        'customsDeclarationRef': customsDeclarationRef!.trim(),
      if ((cmrNumber ?? '').trim().isNotEmpty) 'cmrNumber': cmrNumber!.trim(),
      if ((awbNumber ?? '').trim().isNotEmpty) 'awbNumber': awbNumber!.trim(),
      'items': items.map(_itemForCallable).toList(),
    };

    final data = await _callCreateCommercialOrder(payload);
    if (data['success'] != true) {
      throw Exception('Kreiranje narudžbe nije uspjelo.');
    }
    final id = _s(data['orderId']);
    if (id.isEmpty) {
      throw Exception('Nedostaje orderId iz odgovora.');
    }
    return id;
  }

  Future<Map<String, dynamic>?> getOrderById({
    required String companyId,
    required String orderId,
  }) async {
    final data = await _callGetCommercialOrder(
      companyId: companyId,
      orderId: orderId,
    );
    if (data['success'] != true) {
      throw Exception('Učitavanje narudžbe nije uspjelo.');
    }
    final order = data['order'];
    if (order == null) return null;
    return _mapFromDynamic(order);
  }

  Future<List<Map<String, dynamic>>> getOrderItems({
    required String companyId,
    required String orderId,
  }) async {
    final data = await _callGetCommercialOrder(
      companyId: companyId,
      orderId: orderId,
    );
    if (data['success'] != true) {
      throw Exception('Učitavanje stavki narudžbe nije uspjelo.');
    }
    return _listOfMaps(data['items']);
  }

  /// Sve stavke narudžbi za kompaniju (ograničeno) — za tabularni pregled liste.
  Future<Map<String, List<OrderItemModel>>> loadOrderItemsGroupedByOrderId({
    required String companyId,
    int limit = 2000,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const {};

    final data = await _callListCommercialOrderItemsByCompany(
      companyId: cid,
      limit: limit,
    );
    if (data['success'] != true) {
      throw Exception('Učitavanje stavki narudžbi nije uspjelo.');
    }

    final out = <String, List<OrderItemModel>>{};
    for (final row in _listOfMaps(data['items'])) {
      final m = Map<String, dynamic>.from(row);
      final oid = _s(m['orderId']);
      if (oid.isEmpty) continue;
      out.putIfAbsent(oid, () => []).add(OrderItemModel.fromOrderItemRow(m));
    }
    for (final list in out.values) {
      list.sort((a, b) => (a.lineId ?? '').compareTo(b.lineId ?? ''));
    }
    return out;
  }

  Future<List<OrderModel>> searchOrders({
    required String companyId,
    String? orderType,
  }) async {
    final data = await _callListCommercialOrders(
      companyId: companyId,
      orderType: orderType,
      limit: 100,
    );
    if (data['success'] != true) {
      throw Exception('Pretraga narudžbi nije uspjela.');
    }

    return _listOfMaps(data['orders'])
        .map((m) => OrderModel.fromMap(_s(m['id']), m))
        .toList();
  }

  /// Učitava zaglavlje narudžbe i stavke iz kolekcije `order_items` (izvor istine za linije).
  Future<OrderModel?> loadOrderModelWithItems({
    required String companyId,
    required String orderId,
  }) async {
    final data = await _callGetCommercialOrder(
      companyId: companyId,
      orderId: orderId,
    );
    if (data['success'] != true) {
      throw Exception('Učitavanje narudžbe nije uspjelo.');
    }
    final header = data['order'];
    if (header == null) return null;

    final headerMap = _mapFromDynamic(header);
    final rawItems = _listOfMaps(data['items']);
    final items = rawItems
        .map((m) => OrderItemModel.fromOrderItemRow(m))
        .toList();

    return OrderModel.fromOrderDocument(orderId, headerMap, items: items);
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

    _validateOrderType(orderType);
    _orderStatusEngine.validateManualStatusTransition(
      orderType: orderType,
      currentStatus: oldStatus,
      newStatus: newStatus,
    );

    final data = await _callUpdateCommercialOrder({
      'companyId': companyId,
      'op': 'status',
      'orderId': orderId,
      'newStatus': newStatus,
      if (reason != null) 'reason': reason,
    });
    if (data['success'] != true) {
      throw Exception('Ažuriranje statusa nije uspjelo.');
    }
  }

  Future<void> updateOrderHeader({
    required String companyId,
    required String orderId,
    required String updatedBy,
    required DateTime orderDate,
    DateTime? requestedDeliveryDate,
    DateTime? confirmedDeliveryDate,
    String? notes,
    String? customerReference,
    String? supplierReference,
    String? currency,
    bool? isExport,
    String? incoterms,
    String? customerCountryCode,
    String? vatExemptionNote,
    String? customsDeclarationRef,
    String? cmrNumber,
    String? awbNumber,
    bool customerLogisticsInBaseExplicit = false,
    double? logisticsToCustomerCostInBase,
  }) async {
    final data = <String, dynamic>{
      'companyId': companyId,
      'op': 'header',
      'orderId': orderId,
      'orderDate': orderDate.toIso8601String(),
      'requestedDeliveryDate': requestedDeliveryDate?.toIso8601String(),
      'confirmedDeliveryDate': confirmedDeliveryDate?.toIso8601String(),
      'notes': notes,
      'customerReference': customerReference,
      'supplierReference': supplierReference,
      'currency': currency,
      if (isExport != null) 'isExport': isExport,
      'incoterms': incoterms,
      'customerCountryCode': customerCountryCode,
      'vatExemptionNote': vatExemptionNote,
      'customsDeclarationRef': customsDeclarationRef,
      'cmrNumber': cmrNumber,
      'awbNumber': awbNumber,
    };
    if (customerLogisticsInBaseExplicit) {
      data['logisticsToCustomerCostInBase'] = logisticsToCustomerCostInBase;
    }
    final res = await _callUpdateCommercialOrder(data);
    if (res['success'] != true) {
      throw Exception('Ažuriranje zaglavlja nije uspjelo.');
    }
  }

  Future<void> updateOrderItemOrderedAndDue({
    required String companyId,
    required String orderId,
    required String orderItemId,
    required String updatedBy,
    required double orderedQty,
    DateTime? dueDate,
    double? unitPrice,
    double? discountPercent,
    double? vatPercent,
    bool clearVatPercent = false,
  }) async {
    if (orderedQty <= 0) {
      throw Exception('Naručena količina mora biti veća od 0');
    }

    final payload = <String, dynamic>{
      'companyId': companyId,
      'op': 'item_ordered',
      'orderId': orderId,
      'orderItemId': orderItemId,
      'orderedQty': orderedQty,
      'dueDate': dueDate?.toIso8601String(),
    };
    if (unitPrice != null) payload['unitPrice'] = unitPrice;
    if (discountPercent != null) payload['discountPercent'] = discountPercent;
    if (clearVatPercent) {
      payload['vatPercent'] = null;
    } else if (vatPercent != null) {
      payload['vatPercent'] = vatPercent;
    }

    final data = await _callUpdateCommercialOrder(payload);
    if (data['success'] != true) {
      throw Exception('Ažuriranje stavke nije uspjelo.');
    }
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
    final data = await _callUpdateCommercialOrder({
      'companyId': companyId,
      'op': 'item_execution',
      'orderId': orderId,
      'orderItemId': orderItemId,
      if (confirmedQty != null) 'confirmedQty': confirmedQty,
      if (deliveredQty != null) 'deliveredQty': deliveredQty,
      if (receivedQty != null) 'receivedQty': receivedQty,
    });
    if (data['success'] != true) {
      throw Exception('Ažuriranje izvršenja stavke nije uspjelo.');
    }
  }

  Future<void> recalculateOrderStatus({
    required String companyId,
    required String orderId,
    required String updatedBy,
  }) async {
    final data = await _callUpdateCommercialOrder({
      'companyId': companyId,
      'op': 'recalculate',
      'orderId': orderId,
    });
    if (data['success'] != true) {
      throw Exception('Preračun statusa nije uspio.');
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
    final data = await _callUpdateCommercialOrder({
      'companyId': companyId,
      'op': 'link_production',
      'orderId': orderId,
      'orderItemId': orderItemId,
      'productionOrderId': productionOrderId,
      'productionOrderCode': productionOrderCode,
    });
    if (data['success'] != true) {
      throw Exception('Povezivanje s proizvodnim nalogom nije uspjelo.');
    }
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
    DateTime? sourceOrderDate,
    DateTime? requestedDeliveryDate,
    String? inputMaterialLot,
  }) async {
    final companyId = _requireCompanyId(companyData);
    final userId = _requireUserId(companyData);

    if (orderItemDocId.trim().isEmpty) {
      throw Exception('Nedostaje ID stavke narudžbe (order_items)');
    }

    final sourceCustomerId = orderType == OrderType.customer
        ? partnerId.trim()
        : null;
    final sourceCustomerName = orderType == OrderType.customer
        ? partnerName.trim()
        : null;

    final prodService = ProductionOrderService(firestore: _firestore);
    final plantCode = (companyData['plantCode'] ?? '').toString().trim();

    final productionOrderId = await prodService.createProductionOrder(
      companyId: companyId,
      plantKey: plantKey.trim(),
      plantCode: plantCode.isNotEmpty ? plantCode : null,
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
      customerName: sourceCustomerName?.isEmpty ?? true
          ? null
          : sourceCustomerName,
      sourceOrderId: orderId,
      sourceOrderItemId: orderItemDocId,
      sourceOrderNumber: orderNumber,
      sourceCustomerId: sourceCustomerId?.isEmpty ?? true
          ? null
          : sourceCustomerId,
      sourceCustomerName: sourceCustomerName?.isEmpty ?? true
          ? null
          : sourceCustomerName,
      sourceOrderDate: sourceOrderDate,
      requestedDeliveryDate: requestedDeliveryDate,
      inputMaterialLot: inputMaterialLot,
    );

    final poSnap = await _firestore
        .collection('production_orders')
        .doc(productionOrderId)
        .get();
    final productionOrderCode = (poSnap.data()?['productionOrderCode'] ?? '')
        .toString()
        .trim();
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
}
