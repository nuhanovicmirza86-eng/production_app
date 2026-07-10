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

/// Radna kada s procesnim područjem (master podatak).
class ControlledInputWorkBathOption extends ControlledInputEntityOption {
  const ControlledInputWorkBathOption({
    required super.id,
    required super.displayName,
    super.code,
    super.active = true,
    this.processArea,
  });

  final String? processArea;

  factory ControlledInputWorkBathOption.fromMap(Map<String, dynamic> data) {
    final base = ControlledInputEntityOption.fromMap(data);
    final processArea = (data['processArea'] ?? '').toString().trim();
    return ControlledInputWorkBathOption(
      id: base.id,
      displayName: base.displayName,
      code: base.code,
      active: base.active,
      processArea: processArea.isEmpty ? null : processArea,
    );
  }
}

/// Hemikalija s master allowedUnits (kontrolisan unos / unit dropdown).
class ControlledInputChemicalOption extends ControlledInputEntityOption {
  const ControlledInputChemicalOption({
    required super.id,
    required super.displayName,
    super.code,
    super.active = true,
    this.allowedUnits = const [],
    this.defaultUnit,
    this.concentrationDefault,
  });

  final List<String> allowedUnits;
  final String? defaultUnit;
  final num? concentrationDefault;

  factory ControlledInputChemicalOption.fromMap(Map<String, dynamic> data) {
    final base = ControlledInputEntityOption.fromMap(data);
    final unitsRaw = data['allowedUnits'];
    final units = <String>[];
    if (unitsRaw is List) {
      for (final item in unitsRaw) {
        final u = item.toString().trim();
        if (u.isNotEmpty) units.add(u);
      }
    }
    final defaultUnit = (data['defaultUnit'] ?? '').toString().trim();
    final concRaw = data['concentrationDefault'];
    num? concentrationDefault;
    if (concRaw is num) {
      concentrationDefault = concRaw;
    } else if (concRaw != null && concRaw.toString().trim().isNotEmpty) {
      concentrationDefault = num.tryParse(concRaw.toString());
    }
    return ControlledInputChemicalOption(
      id: base.id,
      displayName: base.displayName,
      code: base.code,
      active: base.active,
      allowedUnits: units,
      defaultUnit: defaultUnit.isEmpty ? null : defaultUnit,
      concentrationDefault: concentrationDefault,
    );
  }
}

/// Rezultat filtriranja hemikalija po radnoj kadi (strict kontrolisan unos).
class WorkBathFilteredChemicalsResult {
  const WorkBathFilteredChemicalsResult({
    required this.chemicals,
    required this.mappingAllowedUnitsByChemicalId,
  });

  final List<ControlledInputChemicalOption> chemicals;
  final Map<String, List<String>> mappingAllowedUnitsByChemicalId;
}

class ProductionControlledInputMasterCallableService {
  ProductionControlledInputMasterCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<ControlledInputWorkBathOption>> listProcessWorkBaths({
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
    return _parseWorkBathList(data['workBaths']);
  }

  Future<List<ControlledInputChemicalOption>> listChemicals({
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
    return _parseChemicalList(data['chemicals']);
  }

  Future<WorkBathFilteredChemicalsResult> listChemicalsAllowedForWorkBath({
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
    if (allowed is! List) {
      return const WorkBathFilteredChemicalsResult(
        chemicals: [],
        mappingAllowedUnitsByChemicalId: {},
      );
    }

    final chemicalIds = <String>{};
    final mappingUnits = <String, List<String>>{};
    for (final item in allowed) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final cid = (map['chemicalId'] ?? '').toString().trim();
      if (cid.isEmpty) continue;
      chemicalIds.add(cid);
      final unitsRaw = map['allowedUnits'];
      if (unitsRaw is List && unitsRaw.isNotEmpty) {
        mappingUnits[cid] = unitsRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
    }
    if (chemicalIds.isEmpty) {
      return const WorkBathFilteredChemicalsResult(
        chemicals: [],
        mappingAllowedUnitsByChemicalId: {},
      );
    }

    final allChemicals = await listChemicals(
      companyId: companyId,
      plantKey: plantKey,
      activeOnly: activeOnly,
    );
    return WorkBathFilteredChemicalsResult(
      chemicals: allChemicals
          .where((c) => chemicalIds.contains(c.id))
          .toList(growable: false),
      mappingAllowedUnitsByChemicalId: mappingUnits,
    );
  }

  List<ControlledInputWorkBathOption> _parseWorkBathList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ControlledInputWorkBathOption>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(
          ControlledInputWorkBathOption.fromMap(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }
    out.sort((a, b) => a.dropdownLabel.compareTo(b.dropdownLabel));
    return out;
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

  List<ControlledInputChemicalOption> _parseChemicalList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ControlledInputChemicalOption>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(
          ControlledInputChemicalOption.fromMap(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }
    out.sort((a, b) => a.dropdownLabel.compareTo(b.dropdownLabel));
    return out;
  }
}
