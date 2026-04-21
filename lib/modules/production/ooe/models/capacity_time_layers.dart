/// Tri vremenska sloja potrebna za ispravan OEE / OOE / TEEP (bez miješanja baza).
///
/// - [calendarTimeSeconds] — puni kalendarski period (npr. 24 h za dan).
/// - [operatingTimeSeconds] — kada je pogon/mašina operativno dostupna (smjene).
/// - [plannedProductionTimeSeconds] — unutar operativnog vremena, planirano za proizvodnju.
///
/// Uobičajeni odnos: `calendar ≥ operating ≥ planned ≥ run`.
class CapacityTimeLayers {
  const CapacityTimeLayers({
    required this.calendarTimeSeconds,
    required this.operatingTimeSeconds,
    required this.plannedProductionTimeSeconds,
  });

  final int calendarTimeSeconds;
  final int operatingTimeSeconds;
  final int plannedProductionTimeSeconds;
}
