import 'package:flutter/foundation.dart';

@immutable
class PlanningUiFormatters {
  const PlanningUiFormatters._();

  /// Oznaka motora nakon generiranja (nije interni API ključ u UI prema korisniku).
  static String engineStrategy(String code) {
    switch (code.trim()) {
      case 'edd_finite_routing_multi_v1':
        return 'Rok (EDD) · ograničen kapacitet · višekorakni routings';
      case 'edd_finite_synthetic_v1':
        return 'Rok (EDD) · ograničen kapacitet · jedna sintetička operacija';
      case 'mvp_fifo_due_edd':
      case 'mvp_fifo_due':
      case 'mvp_fifo_due_edd_edd': // u slučaju starih nacrta
        return 'MVP: redoslijed po roku';
      default:
        if (code.isEmpty) return '—';
        return code;
    }
  }

  /// Sljedeći korak u radnom toku plana (`null` = nema sljedećeg).
  static String? nextPlanWorkflowStatus(String current) {
    switch (current.trim().toLowerCase()) {
      case 'draft':
        return 'simulated';
      case 'simulated':
        return 'confirmed';
      case 'confirmed':
        return 'released';
      default:
        return null;
    }
  }

  static String planWorkflowAdvanceLabel(String targetStatus) {
    switch (targetStatus) {
      case 'simulated':
        return 'Pomakni u simulaciju';
      case 'confirmed':
        return 'Potvrdi plan';
      case 'released':
        return 'Objavi plan';
      default:
        return 'Dalje';
    }
  }

  static String planStatus(String code) {
    switch (code) {
      case 'draft':
        return 'Nacrt';
      case 'simulated':
        return 'Simulacija';
      case 'confirmed':
        return 'Potvrđen';
      case 'released':
        return 'Objavljen';
      case 'approved':
        return 'Odobren';
      case 'closed':
        return 'Zatvoren';
      case 'cancelled':
        return 'Otkazan';
      default:
        return code;
    }
  }

  static String formatDateTime(DateTime? d) {
    if (d == null) return '—';
    final t = d.toLocal();
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.'
        '${t.year}  '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  /// Ljudski opis (bez prikaza sirovog ID-eva u porukama).
  static String conflictTypeLabel(String raw) {
    switch (raw) {
      case 'noMachineCapacity':
        return 'Nema slobodnog kapaciteta na stroju';
      case 'noMachineAssigned':
        return 'Nije dodijeljen stroj';
      case 'noToolCapacity':
        return 'Nema alatnog kapaciteta';
      case 'noOperatorCapacity':
        return 'Nema kapaciteta operatera';
      case 'materialNotAvailable':
        return 'Materijal nije raspoloživ';
      case 'dueDateRisk':
        return 'Rizik u odnosu na traženi rok';
      case 'beyondHorizon':
        return 'Ivan horizonta planiranja';
      case 'sequenceNotFeasible':
        return 'Nedostižan slijed operacija';
      case 'other':
        return 'Ostalo';
      default:
        return raw;
    }
  }
}
