import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedna promjena stanja mašine / linije (izvor istine za downtime / availability).
class MachineStateEvent {
  final String id;
  final String companyId;
  final String plantKey;
  final String machineId;

  final String? lineId;
  final String? workCenterId;
  final String? orderId;
  final String? productId;
  final String? shiftId;
  final DateTime? shiftDate;

  final String state;
  final String? reasonCode;
  final String? reasonCategory;

  /// Denormalizirano s [OoeLossReason.tpmLossKey] kad je [reasonCode] riješen, ili ručno/PLC.
  final String? tpmLossKey;

  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  final String source;
  final String? createdBy;
  final DateTime createdAt;
  final String? notes;

  const MachineStateEvent({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.machineId,
    this.lineId,
    this.workCenterId,
    this.orderId,
    this.productId,
    this.shiftId,
    this.shiftDate,
    required this.state,
    this.reasonCode,
    this.reasonCategory,
    this.tpmLossKey,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    required this.source,
    this.createdBy,
    required this.createdAt,
    this.notes,
  });

  static const String stateRunning = 'running';
  static const String stateStopped = 'stopped';
  static const String stateSetup = 'setup';
  static const String stateWaitingMaterial = 'waiting_material';
  static const String stateWaitingOperator = 'waiting_operator';
  static const String stateMaintenance = 'maintenance';
  static const String stateQualityHold = 'quality_hold';
  static const String statePlannedBreak = 'planned_break';
  static const String stateIdle = 'idle';

  static String? _trimOrNull(dynamic v) {
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  static DateTime? _readDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  factory MachineStateEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final id = doc.id;
    final map = doc.data();
    if (map == null) {
      final now = DateTime.now();
      return MachineStateEvent(
        id: id,
        companyId: '',
        plantKey: '',
        machineId: '',
        state: stateIdle,
        tpmLossKey: null,
        startedAt: now,
        createdAt: now,
        source: 'manual',
      );
    }
    return MachineStateEvent.fromMap(id, map);
  }

  factory MachineStateEvent.fromMap(String id, Map<String, dynamic> map) {
    return MachineStateEvent(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      machineId: (map['machineId'] ?? '').toString(),
      lineId: _trimOrNull(map['lineId']),
      workCenterId: _trimOrNull(map['workCenterId']),
      orderId: _trimOrNull(map['orderId']),
      productId: _trimOrNull(map['productId']),
      shiftId: _trimOrNull(map['shiftId']),
      shiftDate: _readDate(map['shiftDate']),
      state: (map['state'] ?? stateIdle).toString(),
      reasonCode: _trimOrNull(map['reasonCode']),
      reasonCategory: _trimOrNull(map['reasonCategory']),
      tpmLossKey: _trimOrNull(map['tpmLossKey']),
      startedAt:
          (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      durationSeconds: (map['durationSeconds'] is num)
          ? (map['durationSeconds'] as num).toInt()
          : int.tryParse((map['durationSeconds'] ?? '').toString()),
      source: (map['source'] ?? 'manual').toString(),
      createdBy: _trimOrNull(map['createdBy']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: _trimOrNull(map['notes']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'machineId': machineId,
      if (lineId != null && lineId!.trim().isNotEmpty) 'lineId': lineId,
      if (workCenterId != null && workCenterId!.trim().isNotEmpty)
        'workCenterId': workCenterId,
      if (orderId != null && orderId!.trim().isNotEmpty) 'orderId': orderId,
      if (productId != null && productId!.trim().isNotEmpty)
        'productId': productId,
      if (shiftId != null && shiftId!.trim().isNotEmpty) 'shiftId': shiftId,
      if (shiftDate != null) 'shiftDate': shiftDate,
      'state': state,
      if (reasonCode != null && reasonCode!.trim().isNotEmpty)
        'reasonCode': reasonCode,
      if (reasonCategory != null && reasonCategory!.trim().isNotEmpty)
        'reasonCategory': reasonCategory,
      if (tpmLossKey != null && tpmLossKey!.trim().isNotEmpty)
        'tpmLossKey': tpmLossKey,
      'startedAt': startedAt,
      if (endedAt != null) 'endedAt': endedAt,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'source': source,
      if (createdBy != null && createdBy!.trim().isNotEmpty)
        'createdBy': createdBy,
      'createdAt': createdAt,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}
