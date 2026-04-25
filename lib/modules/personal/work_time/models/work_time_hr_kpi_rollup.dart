import 'package:flutter/foundation.dart';

/// Agregat za izvještaj (izvor u produkciji: događaji + odsustva + agregat).
@immutable
class WorkTimeHrKpiRollup {
  const WorkTimeHrKpiRollup({
    required this.lateArrivalHoursYtd,
    required this.earlyArrivalExcessYesCountYtd,
    required this.sickLeaveDaysYtd,
    required this.annualLeaveDaysYtd,
    required this.unpaidAbsenceDaysYtd,
    required this.businessTripDaysYtd,
    required this.paidOtherDaysYtd,
    required this.bereavementDaysYtd,
    required this.childBirthDaysYtd,
    required this.weddingDaysYtd,
    required this.overtimeHoursYtd,
    required this.employeesFrequentLate,
    required this.employeesFrequentSick,
    required this.employeesOvertimeHigh,
  });

  final double lateArrivalHoursYtd;
  final int earlyArrivalExcessYesCountYtd;
  final double sickLeaveDaysYtd;
  final double annualLeaveDaysYtd;
  final double unpaidAbsenceDaysYtd;
  final double businessTripDaysYtd;
  final double paidOtherDaysYtd;
  final double bereavementDaysYtd;
  final double childBirthDaysYtd;
  final double weddingDaysYtd;
  final double overtimeHoursYtd;
  final List<String> employeesFrequentLate;
  final List<String> employeesFrequentSick;
  final List<String> employeesOvertimeHigh;

  /// Primjer (do povezivanja s bazom); zamjenjuje stvarni agregat.
  static const WorkTimeHrKpiRollup demoYtd = WorkTimeHrKpiRollup(
    lateArrivalHoursYtd: 14.5,
    earlyArrivalExcessYesCountYtd: 42,
    sickLeaveDaysYtd: 31,
    annualLeaveDaysYtd: 118,
    unpaidAbsenceDaysYtd: 3,
    businessTripDaysYtd: 12,
    paidOtherDaysYtd: 2,
    bereavementDaysYtd: 1.5,
    childBirthDaysYtd: 0,
    weddingDaysYtd: 0,
    overtimeHoursYtd: 186,
    employeesFrequentLate: ['Ivan K. (3× mj.)', 'Marko P. (2× mj.)'],
    employeesFrequentSick: ['Ana S. (4 epizode)'],
    employeesOvertimeHigh: ['Petar M. (22 h/mj)'],
  );
}
