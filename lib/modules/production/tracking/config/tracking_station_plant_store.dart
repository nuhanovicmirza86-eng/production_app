import 'station_tracking_setup_store.dart';

/// Lokalno na uređaju: koji je pogon odabran na ovoj stanici (po tvrtki).
///
/// Implementacija dijeli spremište s [StationTrackingSetupStore] — spremanje samo
/// pogona zadržava ostale postavke stanice (klasifikacija, etiketa).
class TrackingStationPlantStore {
  TrackingStationPlantStore._();

  static Future<String?> load(String companyId) async {
    final full = await StationTrackingSetupStore.load(companyId);
    if (full != null && full.plantKey.isNotEmpty) return full.plantKey;
    return null;
  }

  static Future<void> save(String companyId, String plantKey) async {
    final pk = plantKey.trim();
    if (pk.isEmpty) return;
    final existing = await StationTrackingSetupStore.load(companyId);
    await StationTrackingSetupStore.save(
      companyId,
      StationTrackingSetup(
        plantKey: pk,
        classification: existing?.classification ?? 'PRIMARY',
        labelPrintingEnabled: existing?.labelPrintingEnabled ?? true,
        labelLayoutKey: existing?.labelLayoutKey ?? kStationLabelLayoutStandard,
      ),
    );
  }

  static Future<void> clear(String companyId) async {
    await StationTrackingSetupStore.clear(companyId);
  }
}
