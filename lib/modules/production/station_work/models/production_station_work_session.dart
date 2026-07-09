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
    this.operatorDisplayName,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.createdByUid,
    this.createdByEmail,
    this.createdByDisplayName,
    required this.status,
    required this.goodQty,
    required this.scrapQty,
    required this.reworkQty,
    required this.downtimeMinutes,
    this.comment,
    this.orderSnapshot,
    this.profileSnapshot,
    this.fieldValues,
    this.controlledInputWarning,
    this.updatedAt,
    this.updatedByUid,
    this.updatedByEmail,
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
  final String? operatorDisplayName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final String? createdByUid;
  final String? createdByEmail;
  final String? createdByDisplayName;
  final String status;
  final double goodQty;
  final double scrapQty;
  final double reworkQty;
  final double downtimeMinutes;
  final String? comment;
  final ProductionStationWorkOrderSnapshot? orderSnapshot;
  final Map<String, dynamic>? profileSnapshot;
  final Map<String, dynamic>? fieldValues;
  final Map<String, dynamic>? controlledInputWarning;
  final DateTime? updatedAt;
  final String? updatedByUid;
  final String? updatedByEmail;

  bool get isActive =>
      status == statusOpen || status == statusPaused;

  bool get isProfileDriven =>
      processProfileType == 'chemical_dosing' ||
      (profileSnapshot != null && profileSnapshot!.isNotEmpty);

  factory ProductionStationWorkSession.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ProductionStationWorkSession.fromMap(doc.id, doc.data() ?? {});
  }

  factory ProductionStationWorkSession.fromMap(String id, Map<String, dynamic> m) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is Map) {
        final seconds = v['seconds'];
        if (seconds is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            (seconds * 1000).round(),
            isUtc: true,
          ).toLocal();
        }
      }
      if (v is String && v.trim().isNotEmpty) {
        return DateTime.tryParse(v.trim())?.toLocal();
      }
      return null;
    }

    Map<String, dynamic>? warningMap(dynamic raw) {
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
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

    Map<String, dynamic>? profileSnapshot;
    final profileRaw = m['profileSnapshot'];
    if (profileRaw is Map) {
      profileSnapshot = Map<String, dynamic>.from(profileRaw);
    }

    Map<String, dynamic>? fieldValues;
    final fieldValuesRaw = m['fieldValues'];
    if (fieldValuesRaw is Map) {
      fieldValues = Map<String, dynamic>.from(fieldValuesRaw);
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
      operatorDisplayName:
          (m['operatorDisplayName'] ?? '').toString().trim().isEmpty
          ? null
          : (m['operatorDisplayName'] ?? '').toString().trim(),
      startedAt: ts(m['startedAt']),
      endedAt: ts(m['endedAt']),
      createdAt: ts(m['createdAt']),
      createdByUid: (m['createdByUid'] ?? '').toString().trim().isEmpty
          ? null
          : (m['createdByUid'] ?? '').toString().trim(),
      createdByEmail: (m['createdByEmail'] ?? '').toString().trim().isEmpty
          ? null
          : (m['createdByEmail'] ?? '').toString().trim(),
      createdByDisplayName:
          (m['createdByDisplayName'] ?? '').toString().trim().isEmpty
          ? null
          : (m['createdByDisplayName'] ?? '').toString().trim(),
      status: (m['status'] ?? '').toString().trim(),
      goodQty: n(m['goodQty']),
      scrapQty: n(m['scrapQty']),
      reworkQty: n(m['reworkQty']),
      downtimeMinutes: n(m['downtimeMinutes']),
      comment: (m['comment'] ?? '').toString().trim().isEmpty
          ? null
          : (m['comment'] ?? '').toString().trim(),
      orderSnapshot: snap,
      profileSnapshot: profileSnapshot,
      fieldValues: fieldValues,
      controlledInputWarning: warningMap(m['controlledInputWarning']),
      updatedAt: ts(m['updatedAt']),
      updatedByUid: (m['updatedByUid'] ?? '').toString().trim().isEmpty
          ? null
          : (m['updatedByUid'] ?? '').toString().trim(),
      updatedByEmail: (m['updatedByEmail'] ?? '').toString().trim().isEmpty
          ? null
          : (m['updatedByEmail'] ?? '').toString().trim(),
    );
  }
}
