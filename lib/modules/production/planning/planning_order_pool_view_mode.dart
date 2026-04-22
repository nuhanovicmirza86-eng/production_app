/// Način prikaza order poola (tablica vs kartice).
enum PlanningOrderPoolViewMode {
  table,
  cards;

  String get preferenceValue => name;

  static PlanningOrderPoolViewMode? fromPreferenceValue(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return switch (raw) {
      'table' => PlanningOrderPoolViewMode.table,
      'cards' => PlanningOrderPoolViewMode.cards,
      _ => null,
    };
  }
}
