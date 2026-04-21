import 'package:cloud_firestore/cloud_firestore.dart';

/// Kontekst smjene za OOE (planirani interval, neto operativno vrijeme, pauze).
///
/// Jedan dokument = jedna smjena (`shiftCode`) na jedan kalendarski dan u pogonu.
/// Kasnije: ulaz u [OoeCalculationService] umjesto samo globalne konstante smjene.
class ShiftContext {
  final String id;
  final String companyId;
  final String plantKey;

  /// Kratka oznaka: npr. `DAY`, `NIGHT`, `A`.
  final String shiftCode;

  /// `yyyy-MM-dd` u lokalnom kalendarskom smislu (isti kao u ostalim OOE ID-jevima).
  final String shiftDateKey;

  final String? shiftId;

  final DateTime? plannedStartAt;
  final DateTime? plannedEndAt;

  /// Neto operativno vrijeme koje ulazi u availability (sekunde), nakon odbitka planiranih pauza ako ih računaš van trake.
  final int operatingTimeSeconds;

  /// Rezervisano za eksplicitno knjiženje pauza (npr. ručak); ostatak u v1 može biti 0.
  final int plannedBreakSeconds;

  final bool isWorkingShift;
  final bool active;

  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const ShiftContext({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.shiftCode,
    required this.shiftDateKey,
    this.shiftId,
    this.plannedStartAt,
    this.plannedEndAt,
    required this.operatingTimeSeconds,
    required this.plannedBreakSeconds,
    required this.isWorkingShift,
    required this.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Lokalni datum (bez vremena) iz [shiftDateKey].
  DateTime get shiftDateLocal {
    final p = shiftDateKey.split('-');
    if (p.length != 3) {
      return DateTime.now();
    }
    final y = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 1;
    final d = int.tryParse(p[2]) ?? 1;
    return DateTime(y, m, d);
  }

  static String shiftDateKeyFromLocal(DateTime localDate) {
    final d = localDate;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  factory ShiftContext.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final id = doc.id;
    final map = doc.data();
    if (map == null) {
      return _empty(id);
    }
    return ShiftContext.fromMap(id, map);
  }

  static ShiftContext _empty(String id) {
    final now = DateTime.now();
    return ShiftContext(
      id: id,
      companyId: '',
      plantKey: '',
      shiftCode: '',
      shiftDateKey: shiftDateKeyFromLocal(now),
      operatingTimeSeconds: 0,
      plannedBreakSeconds: 0,
      isWorkingShift: true,
      active: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ShiftContext.fromMap(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return ShiftContext(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      shiftCode: (map['shiftCode'] ?? '').toString(),
      shiftDateKey: (map['shiftDateKey'] ?? '').toString(),
      shiftId: map['shiftId']?.toString(),
      plannedStartAt: ts(map['plannedStartAt']),
      plannedEndAt: ts(map['plannedEndAt']),
      operatingTimeSeconds: (map['operatingTimeSeconds'] is num)
          ? (map['operatingTimeSeconds'] as num).toInt()
          : int.tryParse('${map['operatingTimeSeconds'] ?? 0}') ?? 0,
      plannedBreakSeconds: (map['plannedBreakSeconds'] is num)
          ? (map['plannedBreakSeconds'] as num).toInt()
          : int.tryParse('${map['plannedBreakSeconds'] ?? 0}') ?? 0,
      isWorkingShift: map['isWorkingShift'] != false,
      active: map['active'] != false,
      notes: (map['notes'] ?? '').toString().trim().isEmpty
          ? null
          : (map['notes'] ?? '').toString().trim(),
      createdAt: ts(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: ts(map['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: map['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'shiftCode': shiftCode.trim(),
      'shiftDateKey': shiftDateKey,
      if (shiftId != null && shiftId!.trim().isNotEmpty) 'shiftId': shiftId!.trim(),
      if (plannedStartAt != null) 'plannedStartAt': plannedStartAt,
      if (plannedEndAt != null) 'plannedEndAt': plannedEndAt,
      'operatingTimeSeconds': operatingTimeSeconds,
      'plannedBreakSeconds': plannedBreakSeconds,
      'isWorkingShift': isWorkingShift,
      'active': active,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (createdBy != null && createdBy!.trim().isNotEmpty)
        'createdBy': createdBy!.trim(),
    };
  }
}
