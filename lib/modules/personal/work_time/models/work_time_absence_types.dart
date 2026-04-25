import 'package:flutter/foundation.dart';

/// Dopuštene kategorije odsustva (HR / obračun).
enum WorkTimeAbsenceType {
  sickLeave,
  annualLeave,
  unpaidLeave,
  businessTrip,
  paidLeave,
  bereavement,
  childBirth,
  wedding,
}

extension WorkTimeAbsenceTypeLabels on WorkTimeAbsenceType {
  String get labelHr {
    switch (this) {
      case WorkTimeAbsenceType.sickLeave:
        return 'Bolovanje';
      case WorkTimeAbsenceType.annualLeave:
        return 'Godišnji odmor';
      case WorkTimeAbsenceType.unpaidLeave:
        return 'Neplaćeno odsustvo';
      case WorkTimeAbsenceType.businessTrip:
        return 'Službeni put';
      case WorkTimeAbsenceType.paidLeave:
        return 'Plaćeno odsustvo (ostalo)';
      case WorkTimeAbsenceType.bereavement:
        return 'Smrtni slučaj (porodica)';
      case WorkTimeAbsenceType.childBirth:
        return 'Rođenje djeteta';
      case WorkTimeAbsenceType.wedding:
        return 'Vjenčanje';
    }
  }

  String get key => name;
}

@immutable
class WorkTimeAbsenceEntry {
  const WorkTimeAbsenceEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.start,
    required this.end,
    this.note = '',
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final WorkTimeAbsenceType type;
  final DateTime start;
  final DateTime end;
  final String note;

  int get workingDaysApprox {
    if (end.isBefore(start)) {
      return 0;
    }
    return end.difference(start).inDays + 1;
  }
}
