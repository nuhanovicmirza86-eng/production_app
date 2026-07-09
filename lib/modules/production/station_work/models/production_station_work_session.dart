import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionStationWorkOrderSnapshot {
  const ProductionStationWorkOrderSnapshot({
    required this.productionOrderCode,
    this.productId,
    required this.productCode,
    required this.productName,
    required this.plannedQty,
    required this.producedGoodQty,
    required this.unit,
    this.bomId,
    this.bomVersion,
    this.routingId,
    this.routingVersion,
    this.operationName,
    this.workInstructions,
    this.workCenterId,
    this.workCenterCode,
    this.workCenterName,
  });

  final String productionOrderCode;
  final String? productId;
  final String productCode;
  final String productName;
  final double plannedQty;
  final double producedGoodQty;
  final String unit;
  final String? bomId;
  final String? bomVersion;
  final String? routingId;
  final String? routingVersion;
  final String? operationName;
  final String? workInstructions;
  final String? workCenterId;
  final String? workCenterCode;
  final String? workCenterName;

  factory ProductionStationWorkOrderSnapshot.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    double n(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0;
    }

    return ProductionStationWorkOrderSnapshot(
      productionOrderCode: (m['productionOrderCode'] ?? '').toString().trim(),
      productId: (m['productId'] ?? '').toString().trim().isEmpty
          ? null
          : (m['productId'] ?? '').toString().trim(),
      productCode: (m['productCode'] ?? '').toString().trim(),
      productName: (m['productName'] ?? '').toString().trim(),
      plannedQty: n(m['plannedQty']),
      producedGoodQty: n(m['producedGoodQty']),
      unit: (m['unit'] ?? 'kom').toString().trim().isEmpty
          ? 'kom'
          : (m['unit'] ?? 'kom').toString().trim(),
      bomId: (m['bomId'] ?? '').toString().trim().isEmpty
          ? null
          : (m['bomId'] ?? '').toString().trim(),
      bomVersion: (m['bomVersion'] ?? '').toString().trim().isEmpty
          ? null
          : (m['bomVersion'] ?? '').toString().trim(),
      routingId: (m['routingId'] ?? '').toString().trim().isEmpty
          ? null
          : (m['routingId'] ?? '').toString().trim(),
      routingVersion: (m['routingVersion'] ?? '').toString().trim().isEmpty
          ? null
          : (m['routingVersion'] ?? '').toString().trim(),
      operationName: (m['operationName'] ?? '').toString().trim().isEmpty
          ? null
          : (m['operationName'] ?? '').toString().trim(),
      workInstructions: (m['workInstructions'] ?? '').toString().trim().isEmpty
          ? null
          : (m['workInstructions'] ?? '').toString().trim(),
      workCenterId: (m['workCenterId'] ?? '').toString().trim().isEmpty
          ? null
          : (m['workCenterId'] ?? '').toString().trim(),
      workCenterCode: (m['workCenterCode'] ?? '').toString().trim().isEmpty
          ? null
          : (m['workCenterCode'] ?? '').toString().trim(),
      workCenterName: (m['workCenterName'] ?? '').toString().trim().isEmpty
          ? null
          : (m['workCenterName'] ?? '').toString().trim(),
    );
  }
}

class ProductionStationWorkSession {
  static const statusOpen = 'open';
  static const statusPaused = 'paused';
  static const statusClosed = 'closed';

  const ProductionStationWorkSession({
    required this.id,
    required this.companyId,
    required this.stationConfigId,
    required this.stationSlot,
    required this.plantKey,
    required this.phase,
    required this.processProfileType,
    required this.productionOrderId,
    required this.operatorId,
    this.operatorEmail,
    this.startedAt,
    this.endedAt,
    required this.status,
    required this.goodQty,
    required this.scrapQty,
    required this.reworkQty,
    required this.downtimeMinutes,
    this.comment,
    this.orderSnapshot,
    this.updatedAt,
    this.updatedByUid,
  });

  final String id;
  final String companyId;
  final String stationConfigId;
  final int stationSlot;
  final String plantKey;
  final String phase;
  final String processProfileType;
  final String productionOrderId;
  final String operatorId;
  final String? operatorEmail;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String status;
  final double goodQty;
  final double scrapQty;
  final double reworkQty;
  final double downtimeMinutes;
  final String? comment;
  final ProductionStationWorkOrderSnapshot? orderSnapshot;
  final DateTime? updatedAt;
  final String? updatedByUid;

  bool get isActive =>
      status == statusOpen || status == statusPaused;

  factory ProductionStationWorkSession.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ProductionStationWorkSession.fromMap(doc.id, doc.data() ?? {});
  }

  factory ProductionStationWorkSession.fromMap(String id, Map<String, dynamic> m) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    double n(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0;
    }

    final snapRaw = m['orderSnapshot'];
    ProductionStationWorkOrderSnapshot? snap;
    if (snapRaw is Map) {
      snap = ProductionStationWorkOrderSnapshot.fromMap(
        Map<String, dynamic>.from(snapRaw),
      );
    }

    return ProductionStationWorkSession(
      id: id,
      companyId: (m['companyId'] ?? '').toString().trim(),
      stationConfigId: (m['stationConfigId'] ?? '').toString().trim(),
      stationSlot: (m['stationSlot'] as num?)?.toInt() ?? 0,
      plantKey: (m['plantKey'] ?? '').toString().trim(),
      phase: (m['phase'] ?? '').toString().trim(),
      processProfileType: (m['processProfileType'] ?? '').toString().trim(),
      productionOrderId: (m['productionOrderId'] ?? '').toString().trim(),
      operatorId: (m['operatorId'] ?? '').toString().trim(),
      operatorEmail: (m['operatorEmail'] ?? '').toString().trim().isEmpty
          ? null
          : (m['operatorEmail'] ?? '').toString().trim(),
      startedAt: ts(m['startedAt']),
      endedAt: ts(m['endedAt']),
      status: (m['status'] ?? '').toString().trim(),
      goodQty: n(m['goodQty']),
      scrapQty: n(m['scrapQty']),
      reworkQty: n(m['reworkQty']),
      downtimeMinutes: n(m['downtimeMinutes']),
      comment: (m['comment'] ?? '').toString().trim().isEmpty
          ? null
          : (m['comment'] ?? '').toString().trim(),
      orderSnapshot: snap,
      updatedAt: ts(m['updatedAt']),
      updatedByUid: (m['updatedByUid'] ?? '').toString().trim().isEmpty
          ? null
          : (m['updatedByUid'] ?? '').toString().trim(),
    );
  }
}
