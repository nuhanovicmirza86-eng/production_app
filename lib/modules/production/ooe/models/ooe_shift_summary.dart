import 'package:cloud_firestore/cloud_firestore.dart';

/// Agregat po smjeni — piše ga sistem (summary servis), ne ručni unos.
class OoeShiftSummary {
  final String id;
  final String companyId;
  final String plantKey;
  final String machineId;

  final String? lineId;
  final String? orderId;
  final String? productId;
  final String? shiftId;
  final DateTime shiftDate;

  final int operatingTimeSeconds;
  final int runTimeSeconds;
  final int stopTimeSeconds;

  final int plannedStopSeconds;
  final int unplannedStopSeconds;
  final int setupSeconds;
  final int materialWaitSeconds;
  final int operatorWaitSeconds;
  final int maintenanceSeconds;
  final int qualityHoldSeconds;
  final int microStopSeconds;

  final double totalCount;
  final double goodCount;
  final double scrapCount;
  final double reworkCount;

  final double? idealCycleTimeSeconds;
  final double? actualCycleTimeSeconds;

  final double availability;
  final double performance;
  final double quality;
  final double ooe;

  final List<Map<String, dynamic>> topLosses;
  /// Ključ = `tpm_*` (MesTpmLossKeys), isti format redaka kao [topLosses] (`reasonKey`, `seconds`).
  final List<Map<String, dynamic>> topTpmLosses;
  final DateTime lastCalculatedAt;
  final String calculationVersion;

  const OoeShiftSummary({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.machineId,
    this.lineId,
    this.orderId,
    this.productId,
    this.shiftId,
    required this.shiftDate,
    required this.operatingTimeSeconds,
    required this.runTimeSeconds,
    required this.stopTimeSeconds,
    required this.plannedStopSeconds,
    required this.unplannedStopSeconds,
    required this.setupSeconds,
    required this.materialWaitSeconds,
    required this.operatorWaitSeconds,
    required this.maintenanceSeconds,
    required this.qualityHoldSeconds,
    required this.microStopSeconds,
    required this.totalCount,
    required this.goodCount,
    required this.scrapCount,
    required this.reworkCount,
    this.idealCycleTimeSeconds,
    this.actualCycleTimeSeconds,
    required this.availability,
    required this.performance,
    required this.quality,
    required this.ooe,
    required this.topLosses,
    this.topTpmLosses = const [],
    required this.lastCalculatedAt,
    required this.calculationVersion,
  });

  static const String currentVersion = '2026-04-25-ooe-v2';

  factory OoeShiftSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data();
    if (map == null) {
      final now = DateTime.now();
      return OoeShiftSummary(
        id: doc.id,
        companyId: '',
        plantKey: '',
        machineId: '',
        shiftDate: now,
        operatingTimeSeconds: 0,
        runTimeSeconds: 0,
        stopTimeSeconds: 0,
        plannedStopSeconds: 0,
        unplannedStopSeconds: 0,
        setupSeconds: 0,
        materialWaitSeconds: 0,
        operatorWaitSeconds: 0,
        maintenanceSeconds: 0,
        qualityHoldSeconds: 0,
        microStopSeconds: 0,
        totalCount: 0,
        goodCount: 0,
        scrapCount: 0,
        reworkCount: 0,
        availability: 0,
        performance: 0,
        quality: 0,
        ooe: 0,
        topLosses: const [],
        topTpmLosses: const [],
        lastCalculatedAt: now,
        calculationVersion: currentVersion,
      );
    }
    return OoeShiftSummary.fromMap(doc.id, map);
  }

  factory OoeShiftSummary.fromMap(String id, Map<String, dynamic> map) {
    List<Map<String, dynamic>> topLosses = const [];
    final raw = map['topLosses'];
    if (raw is List) {
      topLosses = raw.map((e) {
        if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }

    List<Map<String, dynamic>> topTpmLosses = const [];
    final rawTpm = map['topTpmLosses'];
    if (rawTpm is List) {
      topTpmLosses = rawTpm.map((e) {
        if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }

    return OoeShiftSummary(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      machineId: (map['machineId'] ?? '').toString(),
      lineId: map['lineId']?.toString(),
      orderId: map['orderId']?.toString(),
      productId: map['productId']?.toString(),
      shiftId: map['shiftId']?.toString(),
      shiftDate: (map['shiftDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      operatingTimeSeconds: (map['operatingTimeSeconds'] as num?)?.toInt() ?? 0,
      runTimeSeconds: (map['runTimeSeconds'] as num?)?.toInt() ?? 0,
      stopTimeSeconds: (map['stopTimeSeconds'] as num?)?.toInt() ?? 0,
      plannedStopSeconds: (map['plannedStopSeconds'] as num?)?.toInt() ?? 0,
      unplannedStopSeconds: (map['unplannedStopSeconds'] as num?)?.toInt() ?? 0,
      setupSeconds: (map['setupSeconds'] as num?)?.toInt() ?? 0,
      materialWaitSeconds: (map['materialWaitSeconds'] as num?)?.toInt() ?? 0,
      operatorWaitSeconds: (map['operatorWaitSeconds'] as num?)?.toInt() ?? 0,
      maintenanceSeconds: (map['maintenanceSeconds'] as num?)?.toInt() ?? 0,
      qualityHoldSeconds: (map['qualityHoldSeconds'] as num?)?.toInt() ?? 0,
      microStopSeconds: (map['microStopSeconds'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toDouble() ?? 0,
      goodCount: (map['goodCount'] as num?)?.toDouble() ?? 0,
      scrapCount: (map['scrapCount'] as num?)?.toDouble() ?? 0,
      reworkCount: (map['reworkCount'] as num?)?.toDouble() ?? 0,
      idealCycleTimeSeconds: (map['idealCycleTimeSeconds'] as num?)
          ?.toDouble(),
      actualCycleTimeSeconds: (map['actualCycleTimeSeconds'] as num?)
          ?.toDouble(),
      availability: (map['availability'] as num?)?.toDouble() ?? 0,
      performance: (map['performance'] as num?)?.toDouble() ?? 0,
      quality: (map['quality'] as num?)?.toDouble() ?? 0,
      ooe: (map['ooe'] as num?)?.toDouble() ?? 0,
      topLosses: topLosses,
      topTpmLosses: topTpmLosses,
      lastCalculatedAt:
          (map['lastCalculatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      calculationVersion:
          (map['calculationVersion'] ?? currentVersion).toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'machineId': machineId,
      if (lineId != null && lineId!.trim().isNotEmpty) 'lineId': lineId,
      if (orderId != null && orderId!.trim().isNotEmpty) 'orderId': orderId,
      if (productId != null && productId!.trim().isNotEmpty)
        'productId': productId,
      if (shiftId != null && shiftId!.trim().isNotEmpty) 'shiftId': shiftId,
      'shiftDate': shiftDate,
      'operatingTimeSeconds': operatingTimeSeconds,
      'runTimeSeconds': runTimeSeconds,
      'stopTimeSeconds': stopTimeSeconds,
      'plannedStopSeconds': plannedStopSeconds,
      'unplannedStopSeconds': unplannedStopSeconds,
      'setupSeconds': setupSeconds,
      'materialWaitSeconds': materialWaitSeconds,
      'operatorWaitSeconds': operatorWaitSeconds,
      'maintenanceSeconds': maintenanceSeconds,
      'qualityHoldSeconds': qualityHoldSeconds,
      'microStopSeconds': microStopSeconds,
      'totalCount': totalCount,
      'goodCount': goodCount,
      'scrapCount': scrapCount,
      'reworkCount': reworkCount,
      if (idealCycleTimeSeconds != null)
        'idealCycleTimeSeconds': idealCycleTimeSeconds,
      if (actualCycleTimeSeconds != null)
        'actualCycleTimeSeconds': actualCycleTimeSeconds,
      'availability': availability,
      'performance': performance,
      'quality': quality,
      'ooe': ooe,
      'topLosses': topLosses,
      'topTpmLosses': topTpmLosses,
      'lastCalculatedAt': lastCalculatedAt,
      'calculationVersion': calculationVersion,
    };
  }
}
