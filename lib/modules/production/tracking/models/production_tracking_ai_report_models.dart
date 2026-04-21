import 'production_operator_tracking_entry.dart';

/// Agregat po proizvodu (šifra) za jedan radni dan — sve faze.
class ProductScrapDayRollup {
  const ProductScrapDayRollup({
    required this.itemKey,
    required this.itemCode,
    required this.itemName,
    required this.goodQty,
    required this.scrapQty,
    required this.entries,
  });

  final String itemKey;
  final String itemCode;
  final String itemName;
  final double goodQty;
  final double scrapQty;
  final List<ProductionOperatorTrackingEntry> entries;

  double get totalMass => goodQty + scrapQty;

  /// Postotak škarta u odnosu na prijavljenu masu (dobro + škart).
  double get scrapPct => totalMass > 0 ? (scrapQty / totalMass) * 100 : 0;
}

/// Uređaj / linija — događaji iz praćenja + prijave kvarova.
/// [displayName] je uvijek ljudski naziv iz šifrarnika ili opisna oznaka, ne Firestore ID.
class DeviceIssueDayRollup {
  const DeviceIssueDayRollup({
    required this.displayName,
    required this.downtimeCount,
    required this.alarmCount,
    required this.faultCount,
  });

  final String displayName;
  final int downtimeCount;
  final int alarmCount;
  final int faultCount;

  int get score => downtimeCount * 3 + alarmCount * 2 + faultCount;
}
