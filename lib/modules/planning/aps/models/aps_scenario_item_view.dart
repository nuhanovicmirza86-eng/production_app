/// Veza potražnje i scenarija (aps_scenario_items).
class ApsScenarioItemView {
  const ApsScenarioItemView({
    required this.id,
    required this.scenarioId,
    required this.demandId,
    this.sequence = 0,
  });

  final String id;
  final String scenarioId;
  final String demandId;
  final int sequence;

  factory ApsScenarioItemView.fromMap(Map<String, dynamic> map) {
    return ApsScenarioItemView(
      id: (map['id'] ?? '').toString().trim(),
      scenarioId: (map['scenarioId'] ?? '').toString().trim(),
      demandId: (map['demandId'] ?? '').toString().trim(),
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
    );
  }
}
