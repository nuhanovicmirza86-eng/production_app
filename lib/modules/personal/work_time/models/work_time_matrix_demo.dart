import 'package:flutter/foundation.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_settlement_status.dart';

/// Sažetak mjeseca i KPI — **jedan** demo izvor (kasnije: `work_time_monthly_summary` + pravila).
///
/// Povezuje Pregled, Mjesečni, Payroll, ORV (upozorenja).
@immutable
class WorkTimeMatrixSnapshot {
  const WorkTimeMatrixSnapshot({
    required this.year,
    required this.month,
    required this.fundHours,
    required this.workedHours,
    required this.regularWithinFundHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.weekendHours,
    required this.holidayHours,
    required this.extendedMealDays,
    required this.lateCount,
    required this.incompleteEventDays,
    required this.correctionsInMonth,
    required this.settlementStatus,
    this.payrollBlockersNote,
  });

  final int year;
  final int month;
  final double fundHours;
  final double workedHours;
  final double regularWithinFundHours;
  final double overtimeHours;
  final double nightHours;
  final double weekendHours;
  final double holidayHours;
  final int extendedMealDays;
  final int lateCount;
  final int incompleteEventDays;
  final int correctionsInMonth;
  /// Vrijednost iz [WorkTimeSettlementStatus].
  final String settlementStatus;
  final String? payrollBlockersNote;

  String get monthLabel => '$year-${month.toString().padLeft(2, '0')}';

  /// Spreman za export kad je nakon [WorkTimeSettlementStatus.approved] / [locked] (ovisno o politici).
  bool get hasReviewBlocker =>
      settlementStatus == WorkTimeSettlementStatus.needsReview;

  /// Odgovor [workTimeGetMonthSummary] (Cloud Function) + lokalni demo.
  factory WorkTimeMatrixSnapshot.fromJson(Map<String, dynamic> j) {
    double dv(String k) {
      final v = j[k];
      if (v is num) return v.toDouble();
      return 0;
    }

    int iv(String k) {
      final v = j[k];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final note = j['payrollBlockersNote'];
    return WorkTimeMatrixSnapshot(
      year: iv('year'),
      month: iv('month'),
      fundHours: dv('fundHours'),
      workedHours: dv('workedHours'),
      regularWithinFundHours: dv('regularWithinFundHours'),
      overtimeHours: dv('overtimeHours'),
      nightHours: dv('nightHours'),
      weekendHours: dv('weekendHours'),
      holidayHours: dv('holidayHours'),
      extendedMealDays: iv('extendedMealDays'),
      lateCount: iv('lateCount'),
      incompleteEventDays: iv('incompleteEventDays'),
      correctionsInMonth: iv('correctionsInMonth'),
      settlementStatus: (j['settlementStatus'] ?? '').toString().trim().isNotEmpty
          ? (j['settlementStatus'] ?? '').toString().trim()
          : WorkTimeSettlementStatus.draft,
      payrollBlockersNote: note == null
          ? null
          : (note.toString().trim().isEmpty ? null : note.toString().trim()),
    );
  }
}

/// Demo: konzistentan prikaz po periodu. Produkcija zamjenjuje Callables / očitavanje kolekcija.
abstract final class WorkTimeMatrixDemo {
  /// Snapshot za (godina, mjesec). Isti brojevi osim [settlementStatus] (demo varijanta za 2026-04).
  static WorkTimeMatrixSnapshot snapshotFor(int year, int month) {
    final isDemoApril = year == 2026 && month == 4;
    return WorkTimeMatrixSnapshot(
      year: year,
      month: month,
      fundHours: 176,
      workedHours: 182,
      regularWithinFundHours: 170,
      overtimeHours: 6,
      nightHours: 24,
      weekendHours: 4,
      holidayHours: 2,
      extendedMealDays: 3,
      lateCount: 5,
      incompleteEventDays: 2,
      correctionsInMonth: 4,
      settlementStatus: isDemoApril
          ? WorkTimeSettlementStatus.needsReview
          : WorkTimeSettlementStatus.draft,
      payrollBlockersNote: isDemoApril
          ? '4. 4.: neispravan redoslijed ulaza/izlaza. Jedan zaposlenik: nedostaje par u zapisu.'
          : null,
    );
  }
}
