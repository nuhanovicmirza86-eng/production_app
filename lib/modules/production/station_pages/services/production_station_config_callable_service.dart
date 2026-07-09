import 'package:cloud_functions/cloud_functions.dart';

import '../models/production_station_config.dart';
import '../models/production_station_profile_catalog_entry.dart';

class ProductionStationConfigCallableService {
  ProductionStationConfigCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<({
    List<ProductionStationConfig> configs,
    ProductionStationLimitsSummary limits,
  })> listProductionStationConfigs({
    required String companyId,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    final res = await _functions
        .httpsCallable('listProductionStationConfigs')
        .call<Map<String, dynamic>>({'companyId': cid});
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje stanica nije uspjelo.');
    }
    final rawList = data['configs'];
    final configs = <ProductionStationConfig>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          configs.add(
            ProductionStationConfig.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final limitsRaw = data['limits'];
    final limits = limitsRaw is Map
        ? ProductionStationLimitsSummary.fromMap(
            Map<String, dynamic>.from(limitsRaw),
          )
        : const ProductionStationLimitsSummary(
            maxProductionStations: 3,
            maxMachineStations: 0,
            activeProductionStations: 0,
            activeMachineStations: 0,
          );
    return (configs: configs, limits: limits);
  }

  Future<ProductionStationProfileCatalogResult> listProductionStationProfiles({
    required String companyId,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    final res = await _functions
        .httpsCallable('listProductionStationProfiles')
        .call<Map<String, dynamic>>({'companyId': cid});
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje kataloga profila nije uspjelo.');
    }
    final versionRaw = data['catalogVersion'];
    final catalogVersion = versionRaw is int
        ? versionRaw
        : int.tryParse(versionRaw?.toString() ?? '') ?? 0;
    final rawList = data['profiles'];
    final profiles = <ProductionStationProfileCatalogEntry>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          profiles.add(
            ProductionStationProfileCatalogEntry.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    return ProductionStationProfileCatalogResult(
      catalogVersion: catalogVersion,
      profiles: profiles,
    );
  }

  Future<void> upsertProductionStationConfig(
    ProductionStationConfig config,
  ) async {
    final res = await _functions
        .httpsCallable('upsertProductionStationConfig')
        .call<Map<String, dynamic>>(config.toUpsertPayload());
    if (res.data['success'] != true) {
      throw Exception('Spremanje stanice nije uspjelo.');
    }
  }
}

String productionStationLimitMessage(Object error) {
  final text = error.toString();
  if (text.contains('maksimalan broj proizvodnih stanica')) {
    return 'Dostigli ste maksimalan broj proizvodnih stanica za vaš paket. '
        'Za povećanje limita kontaktirajte administratora platforme.';
  }
  if (text.contains('maksimalan broj mašinskih stanica')) {
    return 'Dostigli ste maksimalan broj mašinskih stanica za vaš paket. '
        'Za dodatne mašinske stanice potrebno je proširenje paketa.';
  }
  return text.replaceFirst('Exception: ', '').replaceFirst('[firebase_functions/', '');
}
