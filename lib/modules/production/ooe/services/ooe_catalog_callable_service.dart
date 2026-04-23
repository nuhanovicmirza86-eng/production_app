import 'package:cloud_functions/cloud_functions.dart';

/// OOE katalog: pragovi alarma + ciljevi — mutacije isključivo Callable (tanka pravila).
class OoeCatalogCallableService {
  OoeCatalogCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  String _c(String? s) => (s ?? '').toString().trim();

  /// Novo (bez [ruleId]) ili ažuriranje; vraća [ruleId] dokumenta.
  Future<String> upsertOoeAlertRule({
    required String companyId,
    required String plantKey,
    String? ruleId,
    required String machineId,
    required String ruleType,
    required double threshold,
    String? name,
    bool? active = true,
    required bool isUpdate,
  }) async {
    final h = _f.httpsCallable('upsertOoeAlertRule');
    final body = <String, dynamic>{
      'companyId': _c(companyId),
      'plantKey': _c(plantKey),
      'machineId': _c(machineId),
      'ruleType': _c(ruleType),
      'threshold': threshold,
    };
    if (active != null) {
      body['active'] = active;
    }
    if (isUpdate) {
      body['ruleId'] = _c(ruleId);
      if (name != null) {
        body['name'] = name;
      }
    } else {
      if (name != null && _c(name).isNotEmpty) {
        body['name'] = _c(name);
      }
    }
    final r = await h.call(body);
    final d = r.data;
    if (d is Map) {
      final id = d['ruleId']?.toString();
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }
    throw Exception('Nevaždan odgovor s poslužitelja (ruleId).');
  }

  Future<void> deleteOoeAlertRule({
    required String companyId,
    required String plantKey,
    required String ruleId,
  }) async {
    final h = _f.httpsCallable('deleteOoeAlertRule');
    await h.call({
      'companyId': _c(companyId),
      'plantKey': _c(plantKey),
      'ruleId': _c(ruleId),
    });
  }

  /// [targetOoe] u [0,1] ili uklanjanje cilja kada je [targetOoe] == null.
  Future<void> upsertOoeMachineTarget({
    required String companyId,
    required String plantKey,
    required String machineId,
    required double? targetOoe,
  }) async {
    final h = _f.httpsCallable('upsertOoeMachineTarget');
    final m = <String, dynamic>{
      'companyId': _c(companyId),
      'plantKey': _c(plantKey),
      'machineId': _c(machineId),
    };
    if (targetOoe == null) {
      m['targetOoe'] = null;
    } else {
      m['targetOoe'] = targetOoe;
    }
    await h.call(m);
  }
}
