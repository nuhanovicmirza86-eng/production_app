import 'package:cloud_firestore/cloud_firestore.dart';

/// Kalendar kapaciteta za jedan dan / opseg (osnova za TEEP — koliko vremena postoji).
///
/// Piše se iznad raw događaja (Callable / admin); klijent čita.
class CapacityCalendar {
  final String id;
  final String companyId;
  final String plantKey;

  /// `plant` | `line` | `machine`
  final String scopeType;
  final String scopeId;

  /// Kalendarski dan (datum u lokalu / anker na serveru).
  final DateTime date;

  final int calendarTimeSeconds;
  final int scheduledOperatingTimeSeconds;
  final int plannedProductionTimeSeconds;
  final int plannedNonProductionTimeSeconds;
  final int nonWorkingTimeSeconds;

  final int shiftCount;
  final bool isHoliday;
  final bool isWeekend;

  final String? notes;

  const CapacityCalendar({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.scopeType,
    required this.scopeId,
    required this.date,
    required this.calendarTimeSeconds,
    required this.scheduledOperatingTimeSeconds,
    required this.plannedProductionTimeSeconds,
    required this.plannedNonProductionTimeSeconds,
    required this.nonWorkingTimeSeconds,
    required this.shiftCount,
    required this.isHoliday,
    required this.isWeekend,
    this.notes,
  });

  factory CapacityCalendar.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data();
    if (map == null) {
      return CapacityCalendar(
        id: doc.id,
        companyId: '',
        plantKey: '',
        scopeType: 'plant',
        scopeId: '',
        date: DateTime.now(),
        calendarTimeSeconds: 0,
        scheduledOperatingTimeSeconds: 0,
        plannedProductionTimeSeconds: 0,
        plannedNonProductionTimeSeconds: 0,
        nonWorkingTimeSeconds: 0,
        shiftCount: 0,
        isHoliday: false,
        isWeekend: false,
      );
    }
    return CapacityCalendar.fromMap(doc.id, map);
  }

  factory CapacityCalendar.fromMap(String id, Map<String, dynamic> map) {
    DateTime d = DateTime.now();
    final td = map['date'];
    if (td is Timestamp) d = td.toDate();

    return CapacityCalendar(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      scopeType: (map['scopeType'] ?? 'plant').toString(),
      scopeId: (map['scopeId'] ?? '').toString(),
      date: d,
      calendarTimeSeconds:
          (map['calendarTimeSeconds'] as num?)?.toInt() ?? 0,
      scheduledOperatingTimeSeconds:
          (map['scheduledOperatingTimeSeconds'] as num?)?.toInt() ?? 0,
      plannedProductionTimeSeconds:
          (map['plannedProductionTimeSeconds'] as num?)?.toInt() ?? 0,
      plannedNonProductionTimeSeconds:
          (map['plannedNonProductionTimeSeconds'] as num?)?.toInt() ?? 0,
      nonWorkingTimeSeconds:
          (map['nonWorkingTimeSeconds'] as num?)?.toInt() ?? 0,
      shiftCount: (map['shiftCount'] as num?)?.toInt() ?? 0,
      isHoliday: map['isHoliday'] == true,
      isWeekend: map['isWeekend'] == true,
      notes: map['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'scopeType': scopeType,
      'scopeId': scopeId,
      'date': Timestamp.fromDate(date),
      'calendarTimeSeconds': calendarTimeSeconds,
      'scheduledOperatingTimeSeconds': scheduledOperatingTimeSeconds,
      'plannedProductionTimeSeconds': plannedProductionTimeSeconds,
      'plannedNonProductionTimeSeconds': plannedNonProductionTimeSeconds,
      'nonWorkingTimeSeconds': nonWorkingTimeSeconds,
      'shiftCount': shiftCount,
      'isHoliday': isHoliday,
      'isWeekend': isWeekend,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
    };
  }
}
