import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String companyId;

  final String orderNumber;

  final OrderType orderType;

  final String partnerId;
  final String partnerName;
  final String? partnerCode;

  final List<OrderItemModel> items;

  final OrderStatus status;

  /// Ukupna naručena količina (Firestore: totalOrderedQty ili legacy totalQty).
  final double totalQty;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? createdBy;
  final String? updatedBy;

  final bool isLate;

  final DateTime? orderDate;
  final DateTime? requestedDeliveryDate;
  final DateTime? confirmedDeliveryDate;

  final String? notes;
  final String? currency;
  final String? plantKey;

  /// Broj narudžbe kupca / dobavljača (referenca partnera).
  final String? customerReference;
  final String? supplierReference;

  const OrderModel({
    required this.id,
    required this.companyId,
    required this.orderNumber,
    required this.orderType,
    required this.partnerId,
    required this.partnerName,
    this.partnerCode,
    required this.items,
    required this.status,
    required this.totalQty,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.isLate = false,
    this.orderDate,
    this.requestedDeliveryDate,
    this.confirmedDeliveryDate,
    this.notes,
    this.currency,
    this.plantKey,
    this.customerReference,
    this.supplierReference,
  });

  OrderModel copyWith({
    List<OrderItemModel>? items,
    OrderStatus? status,
    double? totalQty,
    bool? isLate,
    DateTime? orderDate,
    DateTime? requestedDeliveryDate,
    DateTime? confirmedDeliveryDate,
    String? notes,
    String? currency,
    String? plantKey,
    DateTime? updatedAt,
    String? customerReference,
    String? supplierReference,
  }) {
    return OrderModel(
      id: id,
      companyId: companyId,
      orderNumber: orderNumber,
      orderType: orderType,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerCode: partnerCode,
      items: items ?? this.items,
      status: status ?? this.status,
      totalQty: totalQty ?? this.totalQty,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      isLate: isLate ?? this.isLate,
      orderDate: orderDate ?? this.orderDate,
      requestedDeliveryDate:
          requestedDeliveryDate ?? this.requestedDeliveryDate,
      confirmedDeliveryDate:
          confirmedDeliveryDate ?? this.confirmedDeliveryDate,
      notes: notes ?? this.notes,
      currency: currency ?? this.currency,
      plantKey: plantKey ?? this.plantKey,
      customerReference: customerReference ?? this.customerReference,
      supplierReference: supplierReference ?? this.supplierReference,
    );
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final embedded = map['items'] as List<dynamic>? ?? [];
    final items = embedded
        .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
        .toList();
    return OrderModel.fromOrderDocument(id, map, items: items);
  }

  factory OrderModel.fromOrderDocument(
    String id,
    Map<String, dynamic> map, {
    List<OrderItemModel> items = const [],
  }) {
    return OrderModel(
      id: id,
      companyId: _s(map['companyId']),
      orderNumber: _s(map['orderNumber']),
      orderType: OrderTypeX.fromString(map['orderType']),
      partnerId: _s(map['partnerId']),
      partnerName: _s(map['partnerName']),
      partnerCode: map['partnerCode']?.toString(),
      items: items,
      status: OrderStatusX.fromString(map['status']),
      totalQty: _d(map['totalOrderedQty'] ?? map['totalQty']),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
      createdBy: map['createdBy']?.toString().trim(),
      updatedBy: map['updatedBy']?.toString().trim(),
      isLate: map['isLate'] == true,
      orderDate: _toDate(map['orderDate']) ?? _toDate(map['createdAt']),
      requestedDeliveryDate: _toDate(map['requestedDeliveryDate']),
      confirmedDeliveryDate: _toDate(map['confirmedDeliveryDate']),
      notes: _nullableString(map['notes']),
      currency: _nullableString(map['currency']),
      plantKey: _nullableString(map['plantKey']),
      customerReference: _nullableString(map['customerReference']),
      supplierReference: _nullableString(map['supplierReference']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'orderNumber': orderNumber,
      'orderType': orderType.value,
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerCode': partnerCode,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status.value,
      'totalQty': totalQty,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String? _nullableString(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v)) ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(_s(v));
  }
}

class OrderItemModel {
  /// ID Firestore dokumenta u `order_items` (potrebno za povezivanje s PN).
  final String? orderItemDocId;

  final String productId;
  final String productCode;
  final String productName;

  final double qty;
  final String unit;

  final DateTime? dueDate;

  final String? lineId;
  final String? lineStatus;

  final List<String> linkedProductionOrderCodes;

  final double deliveredQty;
  final double receivedQty;
  final double openQty;

  const OrderItemModel({
    this.orderItemDocId,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.qty,
    required this.unit,
    this.dueDate,
    this.lineId,
    this.lineStatus,
    this.linkedProductionOrderCodes = const [],
    this.deliveredQty = 0,
    this.receivedQty = 0,
    this.openQty = 0,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      orderItemDocId: _nullableString(map['orderItemDocId']),
      productId: _s(map['productId'] ?? map['materialId'] ?? map['code']),
      productCode: _s(map['productCode'] ?? map['code']),
      productName: _s(map['productName'] ?? map['name']),
      qty: _d(map['qty'] ?? map['orderedQty']),
      unit: _s(map['unit']),
      dueDate: _toDate(map['dueDate']),
      lineId: _nullableString(map['lineId']),
      lineStatus: _nullableString(map['status']),
      linkedProductionOrderCodes: _stringList(
        map['linkedProductionOrderCodes'],
      ),
      deliveredQty: _d(map['deliveredQty']),
      receivedQty: _d(map['receivedQty']),
      openQty: _d(map['openQty']),
    );
  }

  factory OrderItemModel.fromOrderItemRow(Map<String, dynamic> map) {
    return OrderItemModel(
      orderItemDocId: _nullableString(map['id']),
      productId: _s(map['productId'] ?? map['materialId'] ?? map['code']),
      productCode: _s(map['code'] ?? map['productCode']),
      productName: _s(map['name'] ?? map['productName']),
      qty: _d(map['orderedQty'] ?? map['qty']),
      unit: _s(map['unit']),
      dueDate: _toDate(map['dueDate']),
      lineId: _nullableString(map['lineId']),
      lineStatus: _nullableString(map['status']),
      linkedProductionOrderCodes: _stringList(
        map['linkedProductionOrderCodes'],
      ),
      deliveredQty: _d(map['deliveredQty']),
      receivedQty: _d(map['receivedQty']),
      openQty: _d(map['openQty']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (orderItemDocId != null) 'orderItemDocId': orderItemDocId,
      'productId': productId,
      'productCode': productCode,
      'productName': productName,
      'qty': qty,
      'unit': unit,
      'dueDate': dueDate,
      if (lineId != null) 'lineId': lineId,
      if (lineStatus != null) 'status': lineStatus,
      'linkedProductionOrderCodes': linkedProductionOrderCodes,
    };
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String? _nullableString(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v)) ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(_s(v));
  }
}

enum OrderType { customer, supplier }

extension OrderTypeX on OrderType {
  String get value {
    switch (this) {
      case OrderType.customer:
        return 'customer_order';
      case OrderType.supplier:
        return 'supplier_order';
    }
  }

  static OrderType fromString(dynamic v) {
    final value = (v ?? '').toString();

    if (value == 'supplier_order') return OrderType.supplier;
    return OrderType.customer;
  }
}

enum OrderStatus {
  draft,
  confirmed,
  inProduction,
  partiallyFulfilled,
  fulfilled,
  cancelled,
  closed,
  late,
  open,
  partiallyReceived,
  received,
  qualityHold,
}

extension OrderStatusX on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.draft:
        return 'draft';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.inProduction:
        return 'in_production';
      case OrderStatus.partiallyFulfilled:
        return 'partially_fulfilled';
      case OrderStatus.fulfilled:
        return 'fulfilled';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.closed:
        return 'closed';
      case OrderStatus.late:
        return 'late';
      case OrderStatus.open:
        return 'open';
      case OrderStatus.partiallyReceived:
        return 'partially_received';
      case OrderStatus.received:
        return 'received';
      case OrderStatus.qualityHold:
        return 'quality_hold';
    }
  }

  static OrderStatus fromString(dynamic v) {
    final value = (v ?? '').toString().trim().toLowerCase();

    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'in_production':
        return OrderStatus.inProduction;
      case 'partially_fulfilled':
        return OrderStatus.partiallyFulfilled;
      case 'fulfilled':
        return OrderStatus.fulfilled;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'closed':
        return OrderStatus.closed;
      case 'late':
        return OrderStatus.late;
      case 'open':
        return OrderStatus.open;
      case 'partially_received':
        return OrderStatus.partiallyReceived;
      case 'received':
        return OrderStatus.received;
      case 'quality_hold':
        return OrderStatus.qualityHold;
      default:
        return OrderStatus.draft;
    }
  }
}
