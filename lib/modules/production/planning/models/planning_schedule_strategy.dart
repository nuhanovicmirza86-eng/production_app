/// Redoslijed naloga u poolu prije FCS (F4.3).
enum PlanningScheduleStrategy {
  /// EDD — raniji traženi rok; isti pristup kao ranije (due date → createdAt).
  eddDueDate,

  /// SPT — kraći procijenjeni ukupni posao (setup + trajanje) prvi; procjena s routingsom ako postoji.
  sptTotalWork,
}

extension PlanningScheduleStrategyLabels on PlanningScheduleStrategy {
  String get labelHr {
    switch (this) {
      case PlanningScheduleStrategy.eddDueDate:
        return 'EDD (rok)';
      case PlanningScheduleStrategy.sptTotalWork:
        return 'SPT (kraći posao prvi)';
    }
  }
}

PlanningScheduleStrategy planningScheduleStrategyFromId(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  if (s == 'spt_total_work' || s == 'spt') {
    return PlanningScheduleStrategy.sptTotalWork;
  }
  return PlanningScheduleStrategy.eddDueDate;
}

String planningScheduleStrategyToId(PlanningScheduleStrategy s) {
  switch (s) {
    case PlanningScheduleStrategy.eddDueDate:
      return 'edd_due_date';
    case PlanningScheduleStrategy.sptTotalWork:
      return 'spt_total_work';
  }
}
