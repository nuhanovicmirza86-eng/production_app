/// Šifre uzroka (Faza 3 — proširiti iz mastera po industriji / kompaniji).
const Map<String, String> planningRootCauseCodeLabels = {
  'unknown': 'Nije analizirano / —',
  'machine_down': 'Kvar / stroj u stopu',
  'material': 'Kasno / nedostaje materijal',
  'setup_long': 'Preduga priprema (setup)',
  'quality_hold': 'Quality hold / prilagodba',
  'operator': 'Nedostatak operatera / smjena',
  'replan_drift': 'Pomicanje nakon (re)plana (lokalno)',
  'other': 'Ostalo',
};

List<String> get planningRootCauseCodeKeys {
  return planningRootCauseCodeLabels.keys.toList()..sort();
}
