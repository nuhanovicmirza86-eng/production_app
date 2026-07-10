import 'package:cloud_functions/cloud_functions.dart';

import '../models/production_station_config.dart';
import '../models/production_station_profile_catalog_entry.dart';

String productionStationLimitMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final msg = (error.message ?? '').trim();
    if (msg.isNotEmpty) return msg;
    return error.code;
  }
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('[firebase_functions/', '');
}

class ProductionStationConfigListResult {
  const ProductionStationConfigListResult({
    required this.configs,
    required this.limits,
  });

  final List<ProductionStationConfig> configs;
  final ProductionStationLimitsSummary limits;
}

class ProductionStationConfigCallableService {
  ProductionStationConfigCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<ProductionStationConfigListResult> listProductionStationConfigs({
    required String companyId,
    bool operatorRuntimeOnly = false,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      if (operatorRuntimeOnly) 'operatorRuntimeOnly': true,
    };
    final res = await _functions
        .httpsCallable('listProductionStationConfigs')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje stanica nije uspjelo.');
    }
    final rawConfigs = data['configs'];
    final configs = <ProductionStationConfig>[];
    if (rawConfigs is List) {
      for (final item in rawConfigs) {
        if (item is Map) {
          configs.add(
            ProductionStationConfig.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return ProductionStationConfigListResult(
      configs: configs,
      limits: ProductionStationLimitsSummary.fromMap(
        data['limits'] is Map
            ? Map<String, dynamic>.from(data['limits'] as Map)
            : null,
      ),
    );
  }

  Future<ProductionStationProfileCatalogResult> listProductionStationProfiles({
    required String companyId,
  }) async {
    final res = await _functions
        .httpsCallable('listProductionStationProfiles')
        .call<Map<String, dynamic>>({'companyId': companyId.trim()});
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje kataloga profila nije uspjelo.');
    }
    final rawProfiles = data['profiles'];
    final profiles = <ProductionStationProfileCatalogEntry>[];
    if (rawProfiles is List) {
      for (final item in rawProfiles) {
        if (item is Map) {
          profiles.add(
            ProductionStationProfileCatalogEntry.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    final versionRaw = data['catalogVersion'];
    final catalogVersion = versionRaw is int
        ? versionRaw
        : int.tryParse(versionRaw?.toString() ?? '') ?? 0;
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
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Spremanje stanice nije uspjelo.');
    }
  }
}
