import 'package:cloud_functions/cloud_functions.dart';

import '../models/production_evidence_config.dart';

String productionEvidenceConfigErrorMessage(Object error) {
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

class ProductionEvidenceConfigCallableService {
  ProductionEvidenceConfigCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<ProductionEvidenceConfig>> listProductionEvidenceConfigs({
    required String companyId,
    bool includeArchived = false,
    bool operatorRuntimeOnly = false,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      if (includeArchived) 'includeArchived': true,
      if (operatorRuntimeOnly) 'operatorRuntimeOnly': true,
    };
    final res = await _functions
        .httpsCallable('listProductionEvidenceConfigs')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje evidencija nije uspjelo.');
    }
    final rawConfigs = data['configs'];
    final configs = <ProductionEvidenceConfig>[];
    if (rawConfigs is List) {
      for (final item in rawConfigs) {
        if (item is Map) {
          configs.add(
            ProductionEvidenceConfig.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return configs;
  }

  Future<ProductionEvidenceConfig> getProductionEvidenceConfig({
    required String companyId,
    required String evidenceConfigId,
  }) async {
    final res = await _functions
        .httpsCallable('getProductionEvidenceConfig')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'evidenceConfigId': evidenceConfigId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje evidencije nije uspjelo.');
    }
    final raw = data['config'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionEvidenceConfig.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<String?> upsertProductionEvidenceConfig(
    ProductionEvidenceConfig config,
  ) async {
    final res = await _functions
        .httpsCallable('upsertProductionEvidenceConfig')
        .call<Map<String, dynamic>>(config.toUpsertPayload());
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Spremanje evidencije nije uspjelo.');
    }
    final audit = data['auditLogId'];
    return audit?.toString();
  }

  Future<String?> archiveProductionEvidenceConfig({
    required String companyId,
    required String evidenceConfigId,
  }) async {
    final res = await _functions
        .httpsCallable('archiveProductionEvidenceConfig')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'evidenceConfigId': evidenceConfigId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Arhiviranje evidencije nije uspjelo.');
    }
    final audit = data['auditLogId'];
    return audit?.toString();
  }
}
