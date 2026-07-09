import 'package:cloud_functions/cloud_functions.dart';

/// Stavka master podataka za entity select (kada, hemikalija).
class ControlledInputEntityOption {
  const ControlledInputEntityOption({
    required this.id,
    required this.displayName,
    this.code,
    this.active = true,
  });

  final String id;
  final String displayName;
  final String? code;
  final bool active;

  String get dropdownLabel {
    final code = (this.code ?? '').trim();
    if (code.isEmpty) return displayName;
    return '$code — $displayName';
  }

  factory ControlledInputEntityOption.fromMap(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString().trim();
    final displayName = (data['displayName'] ?? '').toString().trim();
    final code = (data['chemicalCode'] ?? data['bathCode'] ?? '')
        .toString()
        .trim();
    return ControlledInputEntityOption(
      id: id,
      displayName: displayName.isEmpty ? id : displayName,
      code: code.isEmpty ? null : code,
      active: data['active'] != false,
    );
  }
}

class ProductionControlledInputMasterCallableService {
  ProductionControlledInputMasterCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<ControlledInputEntityOption>> listProcessWorkBaths({
    required String companyId,
    required String plantKey,
    bool activeOnly = true,
  }) async {
    final res = await _functions
        .httpsCallable('listProcessWorkBaths')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'plantKey': plantKey.trim(),
          'activeOnly': activeOnly,
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje radnih kada nije uspjelo.');
    }
    return _parseEntityList(data['workBaths']);
  }

  Future<List<ControlledInputEntityOption>> listChemicals({
    required String companyId,
    String? plantKey,
    bool activeOnly = true,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'activeOnly': activeOnly,
    };
    final pk = plantKey?.trim();
    if (pk != null && pk.isNotEmpty) {
      payload['plantKey'] = pk;
    }
    final res = await _functions
        .httpsCallable('listChemicals')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje hemikalija nije uspjelo.');
    }
    return _parseEntityList(data['chemicals']);
  }

  Future<List<ControlledInputEntityOption>> listChemicalsAllowedForWorkBath({
    required String companyId,
    required String workBathId,
    String? plantKey,
    bool activeOnly = true,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'workBathId': workBathId.trim(),
      'activeOnly': activeOnly,
    };
    final pk = plantKey?.trim();
    if (pk != null && pk.isNotEmpty) {
      payload['plantKey'] = pk;
    }
    final res = await _functions
        .httpsCallable('listWorkBathAllowedChemicals')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje dozvoljenih hemikalija nije uspjelo.');
    }
    final allowed = data['allowedChemicals'];
    if (allowed is! List) return const [];

    final chemicalIds = <String>{};
    for (final item in allowed) {
      if (item is! Map) continue;
      final cid = (item['chemicalId'] ?? '').toString().trim();
      if (cid.isNotEmpty) chemicalIds.add(cid);
    }
    if (chemicalIds.isEmpty) return const [];

    final allChemicals = await listChemicals(
      companyId: companyId,
      plantKey: plantKey,
      activeOnly: activeOnly,
    );
    return allChemicals
        .where((c) => chemicalIds.contains(c.id))
        .toList(growable: false);
  }

  List<ControlledInputEntityOption> _parseEntityList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ControlledInputEntityOption>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(
          ControlledInputEntityOption.fromMap(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }
    out.sort((a, b) => a.dropdownLabel.compareTo(b.dropdownLabel));
    return out;
  }
}
