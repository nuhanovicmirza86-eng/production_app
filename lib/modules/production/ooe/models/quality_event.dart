import 'package:cloud_firestore/cloud_firestore.dart';

/// Kvalitet / škart / hold događaji (izvor istine za Q u OOE i izvještaje).
class QualityEvent {
  final String id;
  final String companyId;
  final String plantKey;
  final String machineId;

  final String? lineId;
  final String? orderId;
  final String? productId;
  final String? shiftId;

  final DateTime timestamp;

  final String eventType;
  final String? defectCode;
  final String? defectName;
  final double qty;
  final String? severity;
  final String? notes;

  final String? createdBy;
  final DateTime createdAt;

  const QualityEvent({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.machineId,
    this.lineId,
    this.orderId,
    this.productId,
    this.shiftId,
    required this.timestamp,
    required this.eventType,
    this.defectCode,
    this.defectName,
    required this.qty,
    this.severity,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  static const String typeScrap = 'scrap';
  static const String typeRework = 'rework';
  static const String typeHold = 'hold';
  static const String typeInspectionFail = 'inspection_fail';

  static double _readDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim().replaceAll(',', '.')) ?? 0;
  }

  static String? _trimOrNull(dynamic v) {
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  factory QualityEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final id = doc.id;
    final map = doc.data();
    final now = DateTime.now();
    if (map == null) {
      return QualityEvent(
        id: id,
        companyId: '',
        plantKey: '',
        machineId: '',
        timestamp: now,
        eventType: typeScrap,
        qty: 0,
        createdAt: now,
      );
    }
    return QualityEvent.fromMap(id, map);
  }

  factory QualityEvent.fromMap(String id, Map<String, dynamic> map) {
    return QualityEvent(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      machineId: (map['machineId'] ?? '').toString(),
      lineId: _trimOrNull(map['lineId']),
      orderId: _trimOrNull(map['orderId']),
      productId: _trimOrNull(map['productId']),
      shiftId: _trimOrNull(map['shiftId']),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventType: (map['eventType'] ?? typeScrap).toString(),
      defectCode: _trimOrNull(map['defectCode']),
      defectName: _trimOrNull(map['defectName']),
      qty: _readDouble(map['qty']),
      severity: _trimOrNull(map['severity']),
      notes: _trimOrNull(map['notes']),
      createdBy: _trimOrNull(map['createdBy']),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'timestamp': timestamp,
      'eventType': eventType,
      if (defectCode != null && defectCode!.trim().isNotEmpty)
        'defectCode': defectCode,
      if (defectName != null && defectName!.trim().isNotEmpty)
        'defectName': defectName,
      'qty': qty,
      if (severity != null && severity!.trim().isNotEmpty) 'severity': severity,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (createdBy != null && createdBy!.trim().isNotEmpty)
        'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
