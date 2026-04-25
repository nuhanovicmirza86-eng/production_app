/// Status obračuna u [work_time_daily_summary] / [work_time_monthly_summary].
///
/// U Firestoreu koristite **istu** string-vrijednost (snake_case). Ne izmišljati
/// varijante u klijentu.
///
/// Vidi: `maintenance_app/docs/architecture/archive/2026-04-24_TIME_AND_ATTENDANCE_PAYROLL_MODULE.md` §15
abstract final class WorkTimeSettlementStatus {
  static const String draft = 'draft';
  static const String needsReview = 'needs_review';
  static const String readyForApproval = 'ready_for_approval';
  static const String approved = 'approved';
  static const String locked = 'locked';
  static const String exported = 'exported';

  static const List<String> all = <String>[
    draft,
    needsReview,
    readyForApproval,
    approved,
    locked,
    exported,
  ];

  static bool isKnown(String? value) {
    final v = (value ?? '').trim();
    return v.isNotEmpty && all.contains(v);
  }
}
