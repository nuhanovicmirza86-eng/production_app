import 'package:flutter/foundation.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_annual_leave_display.dart';

/// Lokalni nacrt `work_time_rules` (tenant / pogon). Isti oblik lako se šalje Callables kad bude spreman backend.
@immutable
class WorkTimeRulesDraft {
  const WorkTimeRulesDraft({
    required this.weeklyStandardHours,
    required this.dailyStandardHours,
    required this.useDailyNormForDayFund,
    required this.nightStartHour,
    required this.nightStartMinute,
    required this.nightEndHour,
    required this.nightEndMinute,
    required this.saturdayAsWeekend,
    required this.sundayAsWeekend,
    required this.holidayCalendarTag,
    required this.maxOvertimeHoursPerDay,
    required this.overtimeRequiresApproval,
    required this.latePenaltyEnabled,
    required this.lateGraceMinutes,
    required this.extendedMealEnabled,
    required this.extendedMealThresholdMinutes,
    required this.settlementRequiresApproval,
    required this.lockEditsAfterExport,
    required this.minBreakBetweenShiftsHours,
    required this.earlyArrivalPriznajStvarniDolazak,
    required this.annualLeaveBaseDaysPerYear,
    required this.annualLeaveMaxCarryoverDays,
    required this.annualLeavePolicyNote,
  });

  static const String nightWorkWire = '22:00–06:00';

  static const initial = WorkTimeRulesDraft(
    weeklyStandardHours: 40,
    dailyStandardHours: 8,
    useDailyNormForDayFund: true,
    nightStartHour: 22,
    nightStartMinute: 0,
    nightEndHour: 6,
    nightEndMinute: 0,
    saturdayAsWeekend: true,
    sundayAsWeekend: true,
    holidayCalendarTag: 'BA',
    maxOvertimeHoursPerDay: 4,
    overtimeRequiresApproval: true,
    latePenaltyEnabled: false,
    lateGraceMinutes: 5,
    extendedMealEnabled: true,
    extendedMealThresholdMinutes: 120,
    settlementRequiresApproval: true,
    lockEditsAfterExport: true,
    minBreakBetweenShiftsHours: 11,
    earlyArrivalPriznajStvarniDolazak: false,
    annualLeaveBaseDaysPerYear: 20,
    annualLeaveMaxCarryoverDays: 7,
    annualLeavePolicyNote: kCroatiaAnnualLeaveLawSummaryHr,
  );

  // --- Fond (wire: weeklyStandardHours, dailyStandardHours) ---
  final double weeklyStandardHours;
  final double dailyStandardHours;
  final bool useDailyNormForDayFund;

  // --- Noć (wire: nightWork ili nightStart/End) ---
  final int nightStartHour;
  final int nightStartMinute;
  final int nightEndHour;
  final int nightEndMinute;

  // --- Kategorije ---
  final bool saturdayAsWeekend;
  final bool sundayAsWeekend;
  final String holidayCalendarTag;

  // --- Prekovremeno (wire: maxDailyOvertime, overtime.approval) ---
  final double maxOvertimeHoursPerDay;
  final bool overtimeRequiresApproval;

  // --- Kašnjenja (wire: latePenalty.enabled) ---
  final bool latePenaltyEnabled;
  final int lateGraceMinutes;

  // --- Topli (wire: extendedMeal.*) ---
  final bool extendedMealEnabled;
  final int extendedMealThresholdMinutes;

  // --- Workflow (wire: settlement / export policy) ---
  final bool settlementRequiresApproval;
  final bool lockEditsAfterExport;

  // --- ORV valjanost ---
  final double minBreakBetweenShiftsHours;

  // --- Rano dolazak: ako [true], sati rada broje od stvarne prijave; ako [false], od početka smjene. ---
  final bool earlyArrivalPriznajStvarniDolazak;
  // --- Godišnji: baza, prijenos, zakon. ---
  final double annualLeaveBaseDaysPerYear;
  final double annualLeaveMaxCarryoverDays;
  final String annualLeavePolicyNote;

  WorkTimeRulesDraft copyWith({
    double? weeklyStandardHours,
    double? dailyStandardHours,
    bool? useDailyNormForDayFund,
    int? nightStartHour,
    int? nightStartMinute,
    int? nightEndHour,
    int? nightEndMinute,
    bool? saturdayAsWeekend,
    bool? sundayAsWeekend,
    String? holidayCalendarTag,
    double? maxOvertimeHoursPerDay,
    bool? overtimeRequiresApproval,
    bool? latePenaltyEnabled,
    int? lateGraceMinutes,
    bool? extendedMealEnabled,
    int? extendedMealThresholdMinutes,
    bool? settlementRequiresApproval,
    bool? lockEditsAfterExport,
    double? minBreakBetweenShiftsHours,
    bool? earlyArrivalPriznajStvarniDolazak,
    double? annualLeaveBaseDaysPerYear,
    double? annualLeaveMaxCarryoverDays,
    String? annualLeavePolicyNote,
  }) {
    return WorkTimeRulesDraft(
      weeklyStandardHours: weeklyStandardHours ?? this.weeklyStandardHours,
      dailyStandardHours: dailyStandardHours ?? this.dailyStandardHours,
      useDailyNormForDayFund:
          useDailyNormForDayFund ?? this.useDailyNormForDayFund,
      nightStartHour: nightStartHour ?? this.nightStartHour,
      nightStartMinute: nightStartMinute ?? this.nightStartMinute,
      nightEndHour: nightEndHour ?? this.nightEndHour,
      nightEndMinute: nightEndMinute ?? this.nightEndMinute,
      saturdayAsWeekend: saturdayAsWeekend ?? this.saturdayAsWeekend,
      sundayAsWeekend: sundayAsWeekend ?? this.sundayAsWeekend,
      holidayCalendarTag: holidayCalendarTag ?? this.holidayCalendarTag,
      maxOvertimeHoursPerDay:
          maxOvertimeHoursPerDay ?? this.maxOvertimeHoursPerDay,
      overtimeRequiresApproval:
          overtimeRequiresApproval ?? this.overtimeRequiresApproval,
      latePenaltyEnabled: latePenaltyEnabled ?? this.latePenaltyEnabled,
      lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
      extendedMealEnabled: extendedMealEnabled ?? this.extendedMealEnabled,
      extendedMealThresholdMinutes:
          extendedMealThresholdMinutes ?? this.extendedMealThresholdMinutes,
      settlementRequiresApproval:
          settlementRequiresApproval ?? this.settlementRequiresApproval,
      lockEditsAfterExport: lockEditsAfterExport ?? this.lockEditsAfterExport,
      minBreakBetweenShiftsHours:
          minBreakBetweenShiftsHours ?? this.minBreakBetweenShiftsHours,
      earlyArrivalPriznajStvarniDolazak: earlyArrivalPriznajStvarniDolazak ??
          this.earlyArrivalPriznajStvarniDolazak,
      annualLeaveBaseDaysPerYear:
          annualLeaveBaseDaysPerYear ?? this.annualLeaveBaseDaysPerYear,
      annualLeaveMaxCarryoverDays:
          annualLeaveMaxCarryoverDays ?? this.annualLeaveMaxCarryoverDays,
      annualLeavePolicyNote:
          annualLeavePolicyNote ?? this.annualLeavePolicyNote,
    );
  }

  String get nightIntervalLabel {
    String z(int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return '${z(nightStartHour, nightStartMinute)}–'
        '${z(nightEndHour, nightEndMinute)} (kraj narednog dana ako je rano jutro)';
  }

  static int _iv(Map<String, dynamic> j, String k, int fallback) {
    final v = j[k];
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    if (v is String) {
      return int.tryParse(v.trim().replaceAll(',', '.')) ?? fallback;
    }
    return fallback;
  }

  static double _dv(Map<String, dynamic> j, String k, double fallback) {
    final v = j[k];
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v.trim().replaceAll(',', '.')) ?? fallback;
    }
    return fallback;
  }

  static String _sv(Map<String, dynamic> j, String k, String fallback) {
    final v = j[k];
    if (v == null) {
      return fallback;
    }
    return v.toString().trim().isNotEmpty ? v.toString().trim() : fallback;
  }

  static bool _bv(Map<String, dynamic> j, String k, bool fallback) {
    final v = j[k];
    if (v is bool) {
      return v;
    }
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') {
        return true;
      }
      if (s == 'false' || s == '0' || s == 'no') {
        return false;
      }
    }
    if (v is int) {
      return v != 0;
    }
    return fallback;
  }

  /// Odgovor `workTimeGetRules` nakon uklanjanja meta ključeva (npr. `_docId`, `plantKey`).
  factory WorkTimeRulesDraft.fromJson(Map<String, dynamic> j) {
    return WorkTimeRulesDraft(
      weeklyStandardHours: _dv(j, 'weeklyStandardHours', initial.weeklyStandardHours),
      dailyStandardHours: _dv(j, 'dailyStandardHours', initial.dailyStandardHours),
      useDailyNormForDayFund: _bv(
        j,
        'useDailyNormForDayFund',
        initial.useDailyNormForDayFund,
      ),
      nightStartHour: _iv(
        j,
        'nightStartHour',
        initial.nightStartHour,
      ),
      nightStartMinute: _iv(
        j,
        'nightStartMinute',
        initial.nightStartMinute,
      ),
      nightEndHour: _iv(
        j,
        'nightEndHour',
        initial.nightEndHour,
      ),
      nightEndMinute: _iv(
        j,
        'nightEndMinute',
        initial.nightEndMinute,
      ),
      saturdayAsWeekend: _bv(
        j,
        'saturdayAsWeekend',
        initial.saturdayAsWeekend,
      ),
      sundayAsWeekend: _bv(
        j,
        'sundayAsWeekend',
        initial.sundayAsWeekend,
      ),
      holidayCalendarTag: (() {
        final s = (j['holidayCalendarTag']?.toString() ?? '').trim().toUpperCase();
        if (s.isEmpty) {
          return initial.holidayCalendarTag;
        }
        if (s.length > 8) {
          return s.substring(0, 8);
        }
        return s;
      })(),
      maxOvertimeHoursPerDay: _dv(
        j,
        'maxOvertimeHoursPerDay',
        initial.maxOvertimeHoursPerDay,
      ),
      overtimeRequiresApproval: _bv(
        j,
        'overtimeRequiresApproval',
        initial.overtimeRequiresApproval,
      ),
      latePenaltyEnabled: _bv(
        j,
        'latePenaltyEnabled',
        initial.latePenaltyEnabled,
      ),
      lateGraceMinutes: _iv(
        j,
        'lateGraceMinutes',
        initial.lateGraceMinutes,
      ),
      extendedMealEnabled: _bv(
        j,
        'extendedMealEnabled',
        initial.extendedMealEnabled,
      ),
      extendedMealThresholdMinutes: _iv(
        j,
        'extendedMealThresholdMinutes',
        initial.extendedMealThresholdMinutes,
      ),
      settlementRequiresApproval: _bv(
        j,
        'settlementRequiresApproval',
        initial.settlementRequiresApproval,
      ),
      lockEditsAfterExport: _bv(
        j,
        'lockEditsAfterExport',
        initial.lockEditsAfterExport,
      ),
      minBreakBetweenShiftsHours: _dv(
        j,
        'minBreakBetweenShiftsHours',
        initial.minBreakBetweenShiftsHours,
      ),
      earlyArrivalPriznajStvarniDolazak: _bv(
        j,
        'earlyArrivalPriznajStvarniDolazak',
        initial.earlyArrivalPriznajStvarniDolazak,
      ),
      annualLeaveBaseDaysPerYear: _dv(
        j,
        'annualLeaveBaseDaysPerYear',
        initial.annualLeaveBaseDaysPerYear,
      ),
      annualLeaveMaxCarryoverDays: _dv(
        j,
        'annualLeaveMaxCarryoverDays',
        initial.annualLeaveMaxCarryoverDays,
      ),
      annualLeavePolicyNote: _sv(
        j,
        'annualLeavePolicyNote',
        initial.annualLeavePolicyNote,
      ),
    );
  }

  /// Predmet `workTimeSetRules` (polja pravila, bez poslužiteljskih metapodataka).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weeklyStandardHours': weeklyStandardHours,
      'dailyStandardHours': dailyStandardHours,
      'useDailyNormForDayFund': useDailyNormForDayFund,
      'nightStartHour': nightStartHour,
      'nightStartMinute': nightStartMinute,
      'nightEndHour': nightEndHour,
      'nightEndMinute': nightEndMinute,
      'saturdayAsWeekend': saturdayAsWeekend,
      'sundayAsWeekend': sundayAsWeekend,
      'holidayCalendarTag': holidayCalendarTag,
      'maxOvertimeHoursPerDay': maxOvertimeHoursPerDay,
      'overtimeRequiresApproval': overtimeRequiresApproval,
      'latePenaltyEnabled': latePenaltyEnabled,
      'lateGraceMinutes': lateGraceMinutes,
      'extendedMealEnabled': extendedMealEnabled,
      'extendedMealThresholdMinutes': extendedMealThresholdMinutes,
      'settlementRequiresApproval': settlementRequiresApproval,
      'lockEditsAfterExport': lockEditsAfterExport,
      'minBreakBetweenShiftsHours': minBreakBetweenShiftsHours,
      'earlyArrivalPriznajStvarniDolazak': earlyArrivalPriznajStvarniDolazak,
      'annualLeaveBaseDaysPerYear': annualLeaveBaseDaysPerYear,
      'annualLeaveMaxCarryoverDays': annualLeaveMaxCarryoverDays,
      'annualLeavePolicyNote': annualLeavePolicyNote,
    };
  }
}
