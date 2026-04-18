import '../config/tracking_station_plant_store.dart';

/// Usklađeno s operativnim tabovima: vezana stanica → lokalni odabir → sesija.
Future<String?> resolveEffectiveTrackingPlantKey(
  Map<String, dynamic> companyData,
) async {
  final bound = (companyData['stationBoundPlantKey'] ?? '').toString().trim();
  if (bound.isNotEmpty) return bound;

  final cid = (companyData['companyId'] ?? '').toString().trim();
  if (cid.isEmpty) return null;

  final saved = await TrackingStationPlantStore.load(cid);
  if (saved != null && saved.trim().isNotEmpty) return saved.trim();

  final session = (companyData['plantKey'] ?? '').toString().trim();
  if (session.isNotEmpty) return session;

  return null;
}
