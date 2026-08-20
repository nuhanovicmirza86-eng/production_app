import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/production_evidence_config.dart';

/// Mapirani rezultat greške spremanja — polje + BS poruka (M1-I5-C2).
class ProductionEvidenceConfigUiError {
  const ProductionEvidenceConfigUiError({
    required this.snackMessage,
    this.fieldKey,
    this.fieldMessage,
  });

  /// Kratka opšta poruka (snackbar).
  final String snackMessage;

  /// Ključ polja: name | processKey | plantKey | roles | active | formCode | profile
  final String? fieldKey;

  /// Poruka ispod polja.
  final String? fieldMessage;
}

const String _kGenericSaveFail =
    'Nije moguće spremiti evidenciju. Provjerite unesene podatke i pokušajte ponovo.';

const String _kGenericActionFail =
    'Nije moguće izvršiti radnju. Provjerite unesene podatke i pokušajte ponovo.';

bool _looksTechnicalMessage(String raw) {
  final m = raw.toLowerCase();
  if (m.isEmpty) return true;
  if (m.contains('is not defined')) return true;
  if (m.contains('undefined')) return true;
  if (m.contains('cannot read propert')) return true;
  if (m.contains('null is not')) return true;
  if (m.contains('typeerror')) return true;
  if (m.contains('referenceerror')) return true;
  if (m.contains('internal') && m.contains('error')) return true;
  if (m.contains('stack')) return true;
  if (RegExp(r'\bat\s+\S+\s+\(').hasMatch(raw)) return true;
  // Engleski Firebase code / engleski fragment bez BS dijakritike / razmaka.
  if (RegExp(r'^[a-z][a-z0-9_-]*$', caseSensitive: false).hasMatch(raw.trim()) &&
      raw.trim().length < 40) {
    return true;
  }
  return false;
}

String _rawMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final msg = (error.message ?? '').trim();
    if (msg.isNotEmpty) return msg;
    return (error.code).trim();
  }
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst(RegExp(r'^\[firebase_functions/[^\]]+\]\s*'), '')
      .trim();
}

/// Mapira backend / lokalne greške na BS + polje (M1-I5-C2).
ProductionEvidenceConfigUiError mapProductionEvidenceConfigError(Object error) {
  final raw = _rawMessage(error);
  debugPrint('productionEvidenceConfig error (dev): $error');

  final lower = raw.toLowerCase();

  if (lower.contains('runtimeallowedroles') ||
      lower.contains('barem jednu ulogu') ||
      lower.contains('najmanje jednu')) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
      fieldKey: 'roles',
      fieldMessage:
          'Odaberite najmanje jednu dozvoljenu ulogu za runtime prikaz.',
    );
  }

  if (lower.contains('displayname') || lower.contains('naziv prikaza')) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
      fieldKey: 'name',
      fieldMessage: 'Naziv prikaza je obavezan.',
    );
  }

  if (lower.contains('plantkey') || lower.contains('pogon')) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
      fieldKey: 'plantKey',
      fieldMessage: 'Odaberite pogon.',
    );
  }

  if (lower.contains('processkey') || lower.contains('proces ')) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
      fieldKey: 'processKey',
      fieldMessage: 'Proces je obavezan.',
    );
  }

  if (lower.contains('profilekey') || lower.contains('profil')) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
      fieldKey: 'profile',
      fieldMessage: 'Odaberite profil evidencije.',
    );
  }

  if (lower.contains('controlledform') ||
      lower.contains('obrazac') ||
      lower.contains('qms') ||
      lower.contains('documentcode')) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
      fieldKey: 'formCode',
      fieldMessage:
          'Oznaka obrasca nije ispravna ili obrazac nije odobren u QMS dokumentaciji.',
    );
  }

  if (lower.contains('aktivna') && lower.contains('obavezna')) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
      fieldKey: 'active',
      fieldMessage:
          'Evidencija ne može biti aktivna dok nisu popunjena obavezna polja.',
    );
  }

  if (lower.contains('arhivir')) {
    return ProductionEvidenceConfigUiError(
      snackMessage: raw.contains('ne može')
          ? raw
          : 'Arhivirana evidencija se ne može uređivati — kreirajte novu.',
    );
  }

  if (_looksTechnicalMessage(raw)) {
    return const ProductionEvidenceConfigUiError(
      snackMessage: _kGenericSaveFail,
    );
  }

  // Već BS poruka s backenda (HttpsError).
  return ProductionEvidenceConfigUiError(snackMessage: raw);
}

String productionEvidenceConfigErrorMessage(Object error) {
  return mapProductionEvidenceConfigError(error).snackMessage;
}

String productionEvidenceConfigArchiveErrorMessage(Object error) {
  final mapped = mapProductionEvidenceConfigError(error);
  if (mapped.snackMessage == _kGenericSaveFail) {
    return _kGenericActionFail;
  }
  return mapped.snackMessage;
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

  Future<String> upsertProductionEvidenceConfig(
    ProductionEvidenceConfig config, {
    required bool isCreate,
  }) async {
    final res = await _functions
        .httpsCallable('upsertProductionEvidenceConfig')
        .call<Map<String, dynamic>>(
          config.toUpsertPayload(isCreate: isCreate),
        );
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Spremanje evidencije nije uspjelo.');
    }
    final savedId = (data['evidenceConfigId'] ?? '').toString().trim();
    if (savedId.isEmpty) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return savedId;
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
