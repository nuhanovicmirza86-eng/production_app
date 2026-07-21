import 'package:production_app/core/access/production_access_helper.dart';

import 'production_station_config.dart';
import 'production_station_display_options.dart';

/// Kompanijska instanca evidencije — `production_evidence_configs/{companyId}__ev_{slot}`.
class ProductionEvidenceConfig {
  /// M1-H3 pilot profili za operator runtime.
  static const List<String> h3OperatorRuntimeProfileKeys = [
    'chemical_dosing',
    'wastewater_treatment',
    'production_counting',
  ];

  static bool isH3OperatorRuntimeProfile(String profileKey) =>
      h3OperatorRuntimeProfileKeys.contains(profileKey.trim());

  final String evidenceConfigId;
  final String companyId;
  final int evidenceSlot;
  final String plantKey;
  final String processKey;
  final String phaseKey;
  final String displayName;
  final String profileKey;
  final String profileNameSnapshot;
  final bool active;
  final bool runtimeVisible;
  final List<String> runtimeAllowedRoles;
  final int? displayOrder;
  final ProductionStationDisplayOptions displayOptions;
  final bool controlledInputEnabled;
  final String controlledInputMode;
  final String? controlledInputScope;
  final DateTime? archivedAt;

  const ProductionEvidenceConfig({
    required this.evidenceConfigId,
    required this.companyId,
    required this.evidenceSlot,
    required this.plantKey,
    required this.processKey,
    required this.phaseKey,
    required this.displayName,
    required this.profileKey,
    required this.profileNameSnapshot,
    required this.active,
    required this.runtimeVisible,
    required this.runtimeAllowedRoles,
    this.displayOrder,
    this.displayOptions = const ProductionStationDisplayOptions(),
    this.controlledInputEnabled = false,
    this.controlledInputMode = 'off',
    this.controlledInputScope,
    this.archivedAt,
  });

  bool get supportsControlledInput =>
      ProductionStationConfig.supportsControlledInputProfile(profileKey);

  bool get isArchived => archivedAt != null;

  bool isRuntimeVisibleToRole(String role) {
    if (!active || isArchived || !runtimeVisible) return false;
    final r = ProductionAccessHelper.normalizeRole(role);
    if (ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleSuperAdmin ||
        r == 'production_manager') {
      return true;
    }
    return runtimeAllowedRoles.contains(r);
  }

  static int parseEvidenceSlotFromMap(Map<String, dynamic> data) {
    final slotRaw = data['evidenceSlot'];
    if (slotRaw is int && slotRaw > 0) return slotRaw;
    if (slotRaw is num && slotRaw > 0) return slotRaw.toInt();
    final parsed = int.tryParse('${slotRaw ?? ''}'.trim());
    if (parsed != null && parsed > 0) return parsed;

    final id = (data['evidenceConfigId'] ?? data['id'] ?? '').toString();
    const prefix = '__ev_';
    final idx = id.indexOf(prefix);
    if (idx >= 0) {
      final fromId = int.tryParse(id.substring(idx + prefix.length));
      if (fromId != null && fromId > 0) return fromId;
    }
    return 1;
  }

  static String buildConfigId({
    required String companyId,
    required int evidenceSlot,
  }) {
    return '${companyId.trim()}__ev_$evidenceSlot';
  }

  factory ProductionEvidenceConfig.fromMap(Map<String, dynamic> data) {
    final id = (data['evidenceConfigId'] ?? data['id'] ?? '').toString().trim();
    final slot = parseEvidenceSlotFromMap(data);
    final rolesRaw = data['runtimeAllowedRoles'];
    final roles = <String>[];
    if (rolesRaw is List) {
      for (final item in rolesRaw) {
        final r = item.toString().trim();
        if (r.isNotEmpty) roles.add(r);
      }
    }
    final displayOptionsRaw = data['displayOptions'];
    final displayOptions = displayOptionsRaw is Map
        ? ProductionStationDisplayOptions.fromMap(
            Map<String, dynamic>.from(displayOptionsRaw),
          )
        : const ProductionStationDisplayOptions();

    DateTime? archivedAt;
    final archivedRaw = data['archivedAt'];
    if (archivedRaw != null) {
      if (archivedRaw is DateTime) {
        archivedAt = archivedRaw;
      } else {
        archivedAt = DateTime.tryParse(archivedRaw.toString());
      }
    }

    return ProductionEvidenceConfig(
      evidenceConfigId: id.isEmpty ? buildConfigId(
        companyId: (data['companyId'] ?? '').toString(),
        evidenceSlot: slot,
      ) : id,
      companyId: (data['companyId'] ?? '').toString().trim(),
      evidenceSlot: slot,
      plantKey: (data['plantKey'] ?? '').toString().trim(),
      processKey: (data['processKey'] ?? '').toString().trim(),
      phaseKey: (data['phaseKey'] ?? '').toString().trim(),
      displayName: (data['displayName'] ?? '').toString().trim(),
      profileKey: (data['profileKey'] ?? '').toString().trim(),
      profileNameSnapshot: (data['profileNameSnapshot'] ?? '').toString().trim(),
      active: data['active'] == true,
      runtimeVisible: data['runtimeVisible'] == true,
      runtimeAllowedRoles: roles,
      displayOrder: data['displayOrder'] is int
          ? data['displayOrder'] as int
          : int.tryParse('${data['displayOrder'] ?? ''}'),
      displayOptions: displayOptions,
      controlledInputEnabled: data['controlledInputEnabled'] == true,
      controlledInputMode: (data['controlledInputMode'] ?? 'off').toString().trim().isEmpty
          ? 'off'
          : (data['controlledInputMode'] ?? 'off').toString().trim(),
      controlledInputScope: (data['controlledInputScope'] ?? '').toString().trim().isEmpty
          ? null
          : (data['controlledInputScope'] ?? '').toString().trim(),
      archivedAt: archivedAt,
    );
  }

  Map<String, dynamic> toUpsertPayload() {
    final id = evidenceConfigId.trim();
    final payload = <String, dynamic>{
      'companyId': companyId,
      if (id.isNotEmpty) 'evidenceConfigId': id,
      if (evidenceSlot > 0) 'evidenceSlot': evidenceSlot,
      'plantKey': plantKey,
      'processKey': processKey,
      'phaseKey': phaseKey,
      'displayName': displayName,
      'profileKey': profileKey,
      'active': active,
      'runtimeVisible': runtimeVisible,
      if (runtimeVisible) 'runtimeAllowedRoles': runtimeAllowedRoles,
      if (displayOrder != null) 'displayOrder': displayOrder,
      ...displayOptions.toMap().isEmpty
          ? const <String, dynamic>{}
          : {'displayOptions': displayOptions.toMap()},
    };
    if (ProductionStationConfig.supportsControlledInputProfile(profileKey)) {
      final enabled = controlledInputEnabled;
      final mode = enabled
          ? (controlledInputMode == 'off' ? 'strict' : controlledInputMode)
          : 'off';
      payload['controlledInputEnabled'] = enabled;
      payload['controlledInputMode'] = mode;
      if (enabled) {
        payload['controlledInputScope'] =
            controlledInputScope ??
            ProductionStationConfig.controlledInputScopeWorkBath;
      }
    }
    return payload;
  }
}
