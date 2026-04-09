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

  final double totalQty;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? createdBy;
  final String? updatedBy;

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
  });

  // ================= FROM MAP =================

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    return OrderModel(
      id: id,
      companyId: _s(map['companyId']),
      orderNumber: _s(map['orderNumber']),
      orderType: OrderTypeX.fromString(map['orderType']),
      partnerId: _s(map['partnerId']),
      partnerName: _s(map['partnerName']),
      partnerCode: map['partnerCode']?.toString(),
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      status: OrderStatusX.fromString(map['status']),
      totalQty: _d(map['totalQty']),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
      createdBy: map['createdBy']?.toString(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  // ================= TO MAP =================

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

  // ================= HELPERS =================

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v)) ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    try {
      if (v.runtimeType.toString() == 'Timestamp') {
        return (v as dynamic).toDate();
      }
    } catch (_) {}

    if (v is DateTime) return v;

    return DateTime.tryParse(_s(v));
  }
}

// ================= ITEMS =================

class OrderItemModel {
  final String productId;
  final String productCode;
  final String productName;

  final double qty;
  final String unit;

  final DateTime? dueDate;

  const OrderItemModel({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.qty,
    required this.unit,
    this.dueDate,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: _s(map['productId']),
      productCode: _s(map['productCode']),
      productName: _s(map['productName']),
      qty: _d(map['qty']),
      unit: _s(map['unit']),
      dueDate: _toDate(map['dueDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productCode': productCode,
      'productName': productName,
      'qty': qty,
      'unit': unit,
      'dueDate': dueDate,
    };
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v)) ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    try {
      if (v.runtimeType.toString() == 'Timestamp') {
        return (v as dynamic).toDate();
      }
    } catch (_) {}

    if (v is DateTime) return v;

    return DateTime.tryParse(_s(v));
  }
}

// ================= ENUMS =================

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
  fulfilled,
  cancelled,
  closed,
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
      case OrderStatus.fulfilled:
        return 'fulfilled';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.closed:
        return 'closed';
    }
  }

  static OrderStatus fromString(dynamic v) {
    final value = (v ?? '').toString();

    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'in_production':
        return OrderStatus.inProduction;
      case 'fulfilled':
        return OrderStatus.fulfilled;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'closed':
        return OrderStatus.closed;
      default:
        return OrderStatus.draft;
    }
  }
}
