import 'package:cloud_firestore/cloud_firestore.dart';

/// Inkrement količina po vremenu (izvor istine za performance / quality brojače).
class ProductionCountEvent {
  final String id;
  final String companyId;
  final String plantKey;
  final String machineId;

  final String? lineId;
  final String? orderId;
  final String? productId;
  final String? shiftId;

  final DateTime timestamp;

  final double totalCountIncrement;
  final double goodCountIncrement;
  final double scrapCountIncrement;

  final String source;
  final String? createdBy;
  final DateTime createdAt;

  const ProductionCountEvent({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.machineId,
    this.lineId,
    this.orderId,
    this.productId,
    this.shiftId,
    required this.timestamp,
    required this.totalCountIncrement,
    required this.goodCountIncrement,
    required this.scrapCountIncrement,
    required this.source,
    this.createdBy,
    required this.createdAt,
  });

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

  factory ProductionCountEvent.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final id = doc.id;
    final map = doc.data();
    final now = DateTime.now();
    if (map == null) {
      return ProductionCountEvent(
        id: id,
        companyId: '',
        plantKey: '',
        machineId: '',
        timestamp: now,
        totalCountIncrement: 0,
        goodCountIncrement: 0,
        scrapCountIncrement: 0,
        source: 'manual',
        createdAt: now,
      );
    }
    return ProductionCountEvent.fromMap(id, map);
  }

  factory ProductionCountEvent.fromMap(String id, Map<String, dynamic> map) {
    return ProductionCountEvent(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      machineId: (map['machineId'] ?? '').toString(),
      lineId: _trimOrNull(map['lineId']),
      orderId: _trimOrNull(map['orderId']),
      productId: _trimOrNull(map['productId']),
      shiftId: _trimOrNull(map['shiftId']),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalCountIncrement: _readDouble(map['totalCountIncrement']),
      goodCountIncrement: _readDouble(map['goodCountIncrement']),
      scrapCountIncrement: _readDouble(map['scrapCountIncrement']),
      source: (map['source'] ?? 'manual').toString(),
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
      'totalCountIncrement': totalCountIncrement,
      'goodCountIncrement': goodCountIncrement,
      'scrapCountIncrement': scrapCountIncrement,
      'source': source,
      if (createdBy != null && createdBy!.trim().isNotEmpty)
        'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
