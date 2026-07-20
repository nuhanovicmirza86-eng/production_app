import '../models/production_station_config.dart';

/// Legacy freeze — slot 1–3 / plamingo pilot (M1-G0 / M1-G1).
class ProductionStationLegacyLock {
  ProductionStationLegacyLock._();

  static const Set<String> lockedConfigIds = {
    'plamingo__1',
    'plamingo__2',
    'plamingo__3',
  };

  static bool isLocked(ProductionStationConfig config) {
    if (lockedConfigIds.contains(config.id.trim())) return true;
    final slot = config.legacyOperatorNavSlot;
    return slot != null && slot >= 1 && slot <= 3;
  }

  static bool isLockedId(String configId) =>
      lockedConfigIds.contains(configId.trim());
}
