import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionOrderModel {
  final String id;

  final String companyId;
  final String plantKey;

  final String productionOrderCode;
  final String status;

  final String? productionPlanId;
  final String? productionPlanLineId;

  final String productId;
  final String productCode;
  final String productName;

  final String? customerId;
  final String? customerName;

  /// Sljedljivost: komercijalna narudžba → proizvodni nalog (IATF).
  final String? sourceOrderId;
  final String? sourceOrderItemId;
  final String? sourceOrderNumber;
  final String? sourceCustomerId;
  final String? sourceCustomerName;

  final double plannedQty;
  final double producedGoodQty;
  final double producedScrapQty;
  final double producedReworkQty;

  final String unit;

  final String bomId;
  final String bomVersion;

  final String routingId;
  final String routingVersion;

  final String? machineId;
  final String? lineId;

  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;

  final DateTime? releasedAt;
  final String? releasedBy;

  final DateTime createdAt;
  final String createdBy;

  final DateTime updatedAt;
  final String updatedBy;

  // 🔥 NOVO
  final bool hasCriticalChanges;
  final DateTime? lastChangedAt;
  final String? lastChangedBy;

  ProductionOrderModel({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.productionOrderCode,
    required this.status,
    this.productionPlanId,
    this.productionPlanLineId,
    required this.productId,
    required this.productCode,
    required this.productName,
    this.customerId,
    this.customerName,
    this.sourceOrderId,
    this.sourceOrderItemId,
    this.sourceOrderNumber,
    this.sourceCustomerId,
    this.sourceCustomerName,
    required this.plannedQty,
    required this.producedGoodQty,
    required this.producedScrapQty,
    required this.producedReworkQty,
    required this.unit,
    required this.bomId,
    required this.bomVersion,
    required this.routingId,
    required this.routingVersion,
    this.machineId,
    this.lineId,
    this.scheduledStartAt,
    this.scheduledEndAt,
    this.releasedAt,
    this.releasedBy,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
    required this.hasCriticalChanges,
    this.lastChangedAt,
    this.lastChangedBy,
  });

  factory ProductionOrderModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductionOrderModel(
      id: id,
      companyId: map['companyId'] ?? '',
      plantKey: map['plantKey'] ?? '',
      productionOrderCode: map['productionOrderCode'] ?? '',
      status: map['status'] ?? '',
      productionPlanId: map['productionPlanId'],
      productionPlanLineId: map['productionPlanLineId'],
      productId: map['productId'] ?? '',
      productCode: map['productCode'] ?? '',
      productName: map['productName'] ?? '',
      customerId: map['customerId'],
      customerName: map['customerName'],
      sourceOrderId: map['sourceOrderId']?.toString(),
      sourceOrderItemId: map['sourceOrderItemId']?.toString(),
      sourceOrderNumber: map['sourceOrderNumber']?.toString(),
      sourceCustomerId: map['sourceCustomerId']?.toString(),
      sourceCustomerName: map['sourceCustomerName']?.toString(),
      plannedQty: (map['plannedQty'] ?? 0).toDouble(),
      producedGoodQty: (map['producedGoodQty'] ?? 0).toDouble(),
      producedScrapQty: (map['producedScrapQty'] ?? 0).toDouble(),
      producedReworkQty: (map['producedReworkQty'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      bomId: map['bomId'] ?? '',
      bomVersion: map['bomVersion'] ?? '',
      routingId: map['routingId'] ?? '',
      routingVersion: map['routingVersion'] ?? '',
      machineId: map['machineId'],
      lineId: map['lineId'],
      scheduledStartAt: (map['scheduledStartAt'] as Timestamp?)?.toDate(),
      scheduledEndAt: (map['scheduledEndAt'] as Timestamp?)?.toDate(),
      releasedAt: (map['releasedAt'] as Timestamp?)?.toDate(),
      releasedBy: map['releasedBy'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      updatedBy: map['updatedBy'] ?? '',

      // 🔥 NOVO
      hasCriticalChanges: map['hasCriticalChanges'] ?? false,
      lastChangedAt: (map['lastChangedAt'] as Timestamp?)?.toDate(),
      lastChangedBy: map['lastChangedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'productionOrderCode': productionOrderCode,
      'status': status,
      'productionPlanId': productionPlanId,
      'productionPlanLineId': productionPlanLineId,
      'productId': productId,
      'productCode': productCode,
      'productName': productName,
      'customerId': customerId,
      'customerName': customerName,
      if (sourceOrderId != null && sourceOrderId!.isNotEmpty)
        'sourceOrderId': sourceOrderId,
      if (sourceOrderItemId != null && sourceOrderItemId!.isNotEmpty)
        'sourceOrderItemId': sourceOrderItemId,
      if (sourceOrderNumber != null && sourceOrderNumber!.isNotEmpty)
        'sourceOrderNumber': sourceOrderNumber,
      if (sourceCustomerId != null && sourceCustomerId!.isNotEmpty)
        'sourceCustomerId': sourceCustomerId,
      if (sourceCustomerName != null && sourceCustomerName!.isNotEmpty)
        'sourceCustomerName': sourceCustomerName,
      'plannedQty': plannedQty,
      'producedGoodQty': producedGoodQty,
      'producedScrapQty': producedScrapQty,
      'producedReworkQty': producedReworkQty,
      'unit': unit,
      'bomId': bomId,
      'bomVersion': bomVersion,
      'routingId': routingId,
      'routingVersion': routingVersion,
      'machineId': machineId,
      'lineId': lineId,
      'scheduledStartAt': scheduledStartAt,
      'scheduledEndAt': scheduledEndAt,
      'releasedAt': releasedAt,
      'releasedBy': releasedBy,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,

      // 🔥 NOVO
      'hasCriticalChanges': hasCriticalChanges,
      'lastChangedAt': lastChangedAt,
      'lastChangedBy': lastChangedBy,
    };
  }
}
