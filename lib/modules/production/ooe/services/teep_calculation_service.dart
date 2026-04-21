import '../models/capacity_time_layers.dart';

/// Nadgradnja nad OOE/OEE — **isti** događaji i A/P/Q; **različita baza vremena** po KPI-ju.
///
/// ### Tri vremenska sloja (obavezno za TEEP)
/// - **Kalendar [calendarTime]** — ukupno raspoloživo vrijeme u periodu (npr. 24 h / dan).
/// - **Operativno [operatingTime]** — dio kalendara kad je pogon ili mašina u smjenama / dostupna.
/// - **Planirana proizvodnja [plannedProductionTime]** — unutar operativnog vremena, planirano za proizvodnju.
///
/// Uobičajeni redoslijed: `calendar ≥ operating ≥ planned ≥ run`.
///
/// ### Definicije KPI (ne miješati baze)
/// - **OEE** — efikasnost u **planiranom vremenu proizvodnje**:
///   `OEE = Availability_P × Performance × Quality`, gdje je
///   `Availability_P = runTime / plannedProductionTime`.
/// - **OOE** — efikasnost u **operativnom vremenu**:
///   `OOE = Availability_O × Performance × Quality`, gdje je
///   `Availability_O = runTime / operatingTime`.
/// - **Utilization** (za ovaj projekt): koliki dio **kalendara** je planirano za proizvodnju:
///   `Utilization = plannedProductionTime / calendarTime`.
/// - **TEEP** — iskorištenje **punog kalendara**:
///   `TEEP = OEE × Utilization = Availability_P × Performance × Quality × Utilization`.
///
/// Time je **TEEP najši** pokazatelj (skrivena fabrika / dodatne smjene / vikend), a **OEE** i **OOE**
/// ostaju čitljivi jer imaju užu bazu — ne prikazuj ih kao tri paralelna „slična %" bez ovog konteksta.
class TeepCalculationService {
  TeepCalculationService._();

  static double _clamp01(double x) => x.clamp(0.0, 1.0);

  /// Utilization = PPT / CT (poslovno pravilo za ovaj repo).
  static double utilizationFromSeconds({
    required int calendarTimeSeconds,
    required int plannedProductionTimeSeconds,
  }) {
    if (calendarTimeSeconds <= 0) return 0;
    return _clamp01(plannedProductionTimeSeconds / calendarTimeSeconds);
  }

  /// Jednostavni OEE iz faktora (Availability već na bazi planirane proizvodnje).
  static double oeeFromApq({
    required double availabilityOnPlannedBase,
    required double performance,
    required double quality,
  }) {
    return _clamp01(availabilityOnPlannedBase * performance * quality);
  }

  /// OOE iz faktora (Availability na bazi operativnog vremena).
  static double ooeFromApq({
    required double availabilityOnOperatingBase,
    required double performance,
    required double quality,
  }) {
    return _clamp01(availabilityOnOperatingBase * performance * quality);
  }

  /// `TEEP = OEE × Utilization` (preporučeni oblik kada OEE dolazi iz planirane baze).
  static double teepFromOeeAndUtilization({
    required double oee,
    required double utilization,
  }) {
    return _clamp01(oee * utilization);
  }

  /// Eksplicitno: `A_P × P × Q × U`
  static double teepFromFactors({
    required double availabilityPlanned,
    required double performance,
    required double quality,
    required double utilization,
  }) {
    return _clamp01(
      availabilityPlanned * performance * quality * utilization,
    );
  }

  /// Availability ako imaš run i bazu (plan ili operativno).
  static double availabilityFromRunAndBase({
    required int runTimeSeconds,
    required int baseSeconds,
  }) {
    if (baseSeconds <= 0) return 0;
    return _clamp01(runTimeSeconds / baseSeconds);
  }

  /// Verifikacija hijerarhije sekundi (ne baca — vraća false ako nije konzistentno).
  static bool isValidTimeHierarchy(CapacityTimeLayers layers) {
    final c = layers.calendarTimeSeconds;
    final o = layers.operatingTimeSeconds;
    final p = layers.plannedProductionTimeSeconds;
    if (c < 0 || o < 0 || p < 0) return false;
    if (o > c) return false;
    if (p > o) return false;
    return true;
  }
}
