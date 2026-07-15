import 'package:cloud_functions/cloud_functions.dart';

import '../models/structured_entity_search_result.dart';

String productionEvidenceEntitySearchErrorMessage(Object error) {
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

/// M1-D2 entity search + scan Callables za structured evidenciju.
class ProductionEvidenceEntitySearchCallableService {
  ProductionEvidenceEntitySearchCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<StructuredEntitySearchResult>> searchProducts({
    required String companyId,
    required String query,
    int limit = 20,
  }) async {
    final res = await _functions
        .httpsCallable('searchProducts')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'query': query.trim(),
          'limit': limit,
        });
    return _parseItems(res.data);
  }

  Future<List<StructuredEntitySearchResult>> searchMaterials({
    required String companyId,
    required String query,
    int limit = 20,
  }) async {
    final res = await _functions
        .httpsCallable('searchMaterials')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'query': query.trim(),
          'limit': limit,
        });
    return _parseItems(res.data);
  }

  Future<List<StructuredEntitySearchResult>> searchPlantOperators({
    required String companyId,
    required String query,
    String? assignedPlantKey,
    int limit = 20,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'query': query.trim(),
      'limit': limit,
    };
    final stationPlant = assignedPlantKey?.trim();
    if (stationPlant != null && stationPlant.isNotEmpty) {
      payload['assignedPlantKey'] = stationPlant;
    }
    final res = await _functions
        .httpsCallable('searchPlantOperators')
        .call<Map<String, dynamic>>(payload);
    return _parseItems(res.data);
  }

  Future<List<StructuredEntitySearchResult>> searchProductionOrders({
    required String companyId,
    required String query,
    int limit = 20,
  }) async {
    final res = await _functions
        .httpsCallable('searchProductionOrders')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'query': query.trim(),
          'limit': limit,
        });
    return _parseItems(res.data);
  }

  Future<StructuredScanResolveResult> resolveProductionEvidenceScan({
    required String companyId,
    required String scanPayload,
  }) async {
    final res = await _functions
        .httpsCallable('resolveProductionEvidenceScan')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'scanPayload': scanPayload.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Skeniranje nije uspjelo.');
    }
    return StructuredScanResolveResult.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<StructuredEntitySearchResult>> searchByCallable({
    required String callableName,
    required String companyId,
    required String query,
    String? assignedPlantKey,
    int limit = 20,
  }) {
    switch (callableName.trim()) {
      case 'searchProducts':
        return searchProducts(
          companyId: companyId,
          query: query,
          limit: limit,
        );
      case 'searchMaterials':
        return searchMaterials(
          companyId: companyId,
          query: query,
          limit: limit,
        );
      case 'searchPlantOperators':
        return searchPlantOperators(
          companyId: companyId,
          query: query,
          assignedPlantKey: assignedPlantKey,
          limit: limit,
        );
      case 'searchProductionOrders':
        return searchProductionOrders(
          companyId: companyId,
          query: query,
          limit: limit,
        );
      default:
        throw Exception('Nepodržana pretraga: $callableName');
    }
  }

  List<StructuredEntitySearchResult> _parseItems(Map<String, dynamic>? data) {
    if (data == null || data['success'] != true) {
      throw Exception('Pretraga nije uspjela.');
    }
    final raw = data['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => StructuredEntitySearchResult.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }
}
