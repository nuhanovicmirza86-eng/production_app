import 'package:cloud_functions/cloud_functions.dart';

import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';

String productionStationTerminalLaunchErrorMessage(Object error) {
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

class ProductionStationTerminalLaunchResult {
  const ProductionStationTerminalLaunchResult({
    required this.assignedStationConfigId,
    required this.launchKind,
    required this.stationConfig,
    this.profile,
  });

  final String assignedStationConfigId;
  final String launchKind;
  final ProductionStationConfig stationConfig;
  final ProductionStationProfileCatalogEntry? profile;

  bool get isLegacyPreparation => launchKind == 'legacy_preparation';
  bool get isLegacyFirstControl => launchKind == 'legacy_first_control';
  bool get isLegacyFinalControl => launchKind == 'legacy_final_control';
  bool get isProfileStation => launchKind == 'profile_station';
}

class ProductionStationTerminalLaunchService {
  ProductionStationTerminalLaunchService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<ProductionStationTerminalLaunchResult> resolveLaunch({
    required String companyId,
  }) async {
    final res = await _functions
        .httpsCallable('resolveProductionStationTerminalLaunch')
        .call<Map<String, dynamic>>({'companyId': companyId.trim()});
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje terminal stanice nije uspjelo.');
    }

    final configRaw = data['stationConfig'];
    if (configRaw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }

    final configMap = Map<String, dynamic>.from(configRaw);
    final assignedId = (data['assignedStationConfigId'] ?? configMap['id'] ?? '')
        .toString()
        .trim();
    if (assignedId.isNotEmpty) {
      configMap['id'] = assignedId;
    }

    ProductionStationProfileCatalogEntry? profile;
    final profileRaw = data['profile'];
    if (profileRaw is Map) {
      profile = ProductionStationProfileCatalogEntry.fromMap(
        Map<String, dynamic>.from(profileRaw),
      );
    }

    return ProductionStationTerminalLaunchResult(
      assignedStationConfigId: assignedId,
      launchKind: (data['launchKind'] ?? '').toString().trim(),
      stationConfig: ProductionStationConfig.fromMap(configMap),
      profile: profile,
    );
  }
}
