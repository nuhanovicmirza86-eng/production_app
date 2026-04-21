import 'package:cloud_firestore/cloud_firestore.dart';

/// Brzi snimak za live OOE ekran (docId = [machineId] u okviru plant kolekcije).
class OoeLiveStatus {
  final String machineId;
  final String companyId;
  final String plantKey;

  final String? lineId;
  final String currentState;
  final String? currentReasonCode;
  final String? currentReasonName;
  final DateTime? currentStateStartedAt;

  final String? activeOrderId;
  final String? activeProductId;
  final String? currentShiftId;

  final double currentShiftOoe;
  final double availability;
  final double performance;
  final double quality;

  final double goodCount;
  final double scrapCount;

  final DateTime updatedAt;

  const OoeLiveStatus({
    required this.machineId,
    required this.companyId,
    required this.plantKey,
    this.lineId,
    required this.currentState,
    this.currentReasonCode,
    this.currentReasonName,
    this.currentStateStartedAt,
    this.activeOrderId,
    this.activeProductId,
    this.currentShiftId,
    required this.currentShiftOoe,
    required this.availability,
    required this.performance,
    required this.quality,
    required this.goodCount,
    required this.scrapCount,
    required this.updatedAt,
  });

  factory OoeLiveStatus.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data();
    final mid = doc.id;
    if (map == null) {
      final now = DateTime.now();
      return OoeLiveStatus(
        machineId: mid,
        companyId: '',
        plantKey: '',
        currentState: '',
        currentShiftOoe: 0,
        availability: 0,
        performance: 0,
        quality: 0,
        goodCount: 0,
        scrapCount: 0,
        updatedAt: now,
      );
    }
    return OoeLiveStatus.fromMap(mid, map);
  }

  factory OoeLiveStatus.fromMap(String docId, Map<String, dynamic> map) {
    final mid = (map['machineId'] ?? docId).toString();
    return OoeLiveStatus(
      machineId: mid,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      lineId: map['lineId']?.toString(),
      currentState: (map['currentState'] ?? '').toString(),
      currentReasonCode: map['currentReasonCode']?.toString(),
      currentReasonName: map['currentReasonName']?.toString(),
      currentStateStartedAt:
          (map['currentStateStartedAt'] as Timestamp?)?.toDate(),
      activeOrderId: map['activeOrderId']?.toString(),
      activeProductId: map['activeProductId']?.toString(),
      currentShiftId: map['currentShiftId']?.toString(),
      currentShiftOoe: (map['currentShiftOoe'] as num?)?.toDouble() ?? 0,
      availability: (map['availability'] as num?)?.toDouble() ?? 0,
      performance: (map['performance'] as num?)?.toDouble() ?? 0,
      quality: (map['quality'] as num?)?.toDouble() ?? 0,
      goodCount: (map['goodCount'] as num?)?.toDouble() ?? 0,
      scrapCount: (map['scrapCount'] as num?)?.toDouble() ?? 0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'machineId': machineId,
      'companyId': companyId,
      'plantKey': plantKey,
      if (lineId != null && lineId!.trim().isNotEmpty) 'lineId': lineId,
      'currentState': currentState,
      if (currentReasonCode != null && currentReasonCode!.trim().isNotEmpty)
        'currentReasonCode': currentReasonCode,
      if (currentReasonName != null && currentReasonName!.trim().isNotEmpty)
        'currentReasonName': currentReasonName,
      if (currentStateStartedAt != null)
        'currentStateStartedAt': currentStateStartedAt,
      if (activeOrderId != null && activeOrderId!.trim().isNotEmpty)
        'activeOrderId': activeOrderId,
      if (activeProductId != null && activeProductId!.trim().isNotEmpty)
        'activeProductId': activeProductId,
      if (currentShiftId != null && currentShiftId!.trim().isNotEmpty)
        'currentShiftId': currentShiftId,
      'currentShiftOoe': currentShiftOoe,
      'availability': availability,
      'performance': performance,
      'quality': quality,
      'goodCount': goodCount,
      'scrapCount': scrapCount,
      'updatedAt': updatedAt,
    };
  }
}
