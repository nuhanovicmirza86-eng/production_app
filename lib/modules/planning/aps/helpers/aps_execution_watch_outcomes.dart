/// Kanonski poslovni ishodi i prikaz za P6.1 trag vrijednosti.
abstract final class ApsExecutionWatchOutcomes {
  static const riskOutcomes = [
    'prevented_delay',
    'prevented_downtime',
    'saved_delivery_deadline',
    'risk_reduced',
    'no_impact',
    'unresolved',
    'false_positive',
  ];

  static const opportunityOutcomes = [
    'used_free_capacity',
    'accelerated_urgent_order',
    'improved_resource_utilization',
    'reduced_waiting_time',
    'completed_ahead_of_plan',
    'no_impact',
    'unresolved',
  ];

  static List<String> outcomesForAlertKind(String alertKind) {
    return alertKind == 'opportunity' ? opportunityOutcomes : riskOutcomes;
  }

  static String labelForBusinessOutcome(String code) {
    switch (code) {
      case 'prevented_delay':
        return 'Kašnjenje spriječeno';
      case 'prevented_downtime':
        return 'Zastoj spriječen';
      case 'saved_delivery_deadline':
        return 'Rok isporuke spašen';
      case 'risk_reduced':
        return 'Rizik smanjen';
      case 'used_free_capacity':
        return 'Iskorišten slobodan kapacitet';
      case 'accelerated_urgent_order':
        return 'Ubrzan hitan nalog';
      case 'improved_resource_utilization':
        return 'Bolja iskorištenost resursa';
      case 'reduced_waiting_time':
        return 'Smanjeno čekanje';
      case 'completed_ahead_of_plan':
        return 'Završeno ranije od plana';
      case 'no_impact':
        return 'Bez utjecaja na plan';
      case 'unresolved':
        return 'Neriješeno';
      case 'false_positive':
        return 'Lažno upozorenje';
      default:
        return code;
    }
  }

  static String labelForUserAction(String code) {
    switch (code) {
      case 'in_progress':
        return 'U toku rješavanja';
      case 'resolved':
        return 'Riješeno';
      case 'dismissed':
        return 'Odbačeno';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  /// Zadani ishod za brzi resolve (P6-1H smoke).
  static String? suggestedOutcome({
    required String alertKind,
    required String alertType,
  }) {
    if (alertKind == 'opportunity') {
      switch (alertType) {
        case 'early_completion_opportunity':
          return 'completed_ahead_of_plan';
        case 'free_capacity_opportunity':
          return 'used_free_capacity';
        default:
          return 'used_free_capacity';
      }
    }
    switch (alertType) {
      case 'material_shortage_risk':
        return 'prevented_delay';
      case 'operation_delay_risk':
        return 'prevented_delay';
      case 'machine_stoppage_risk':
      case 'extraordinary_event_risk':
        return 'prevented_downtime';
      case 'urgent_order_risk':
        return 'saved_delivery_deadline';
      default:
        return 'risk_reduced';
    }
  }
}
