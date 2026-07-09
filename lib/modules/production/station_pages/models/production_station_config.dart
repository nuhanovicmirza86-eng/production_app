/// Kanonski model stanice — `production_station_configs/{companyId}__{stationSlot}`.
class ProductionStationConfig {
  static const String stationTypeProduction = 'production_station';
  static const String stationTypeMachine = 'machine_station';

  static const List<String> stationTypes = [
    stationTypeProduction,
    stationTypeMachine,
  ];

  static const List<String> productionProfiles = [
    'standard_production',
    'wastewater_treatment',
    'chemical_dosing',
    'rework_and_painting',
    'process_log',
  ];

  static const List<String> productionPhaseKeys = [
    'pripremna',
    'priprema_proizvodnje',
    'pakovanje',
    'montaza',
    'obrada',
    'kontrola',
    'zavrsna_kontrola',
    'etiketiranje',
    'zavrsna_obrada',
    'ostalo',
  ];

  final String id;
  final String companyId;
  final int stationSlot;
  final String? stationCode;
  final String? displayName;
  final int order;
  final bool active;
  final String? description;
  final String? notes;
  final String stationType;
  final String processProfileType;
  final String assignedPlantKey;
  final String? productionPhaseKey;
  final String phase;
  final String? workCenterId;
  final String? processId;
  final String? routingStepId;
  final bool requiresOperatorLogin;
  final bool requiresWorkOrder;
  final bool requiresProduct;
  final bool requiresQuantityOutput;
  final bool requiresMaterialConsumption;
  final bool requiresQualityCheck;
  final bool supportsManualProductionInput;
  final bool supportsMachineCounters;
  final String? defaultUnit;
  final List<String> allowedUnits;
  final ProductionStationMachineIntegration machineIntegration;
  final bool packingFlowEnabled;
  final String? inboundWarehouseId;
  final String? outboundWarehouseId;
  final int? legacyOperatorNavSlot;

  const ProductionStationConfig({
    required this.id,
    required this.companyId,
    required this.stationSlot,
    this.stationCode,
    this.displayName,
    required this.order,
    required this.active,
    this.description,
    this.notes,
    required this.stationType,
    required this.processProfileType,
    required this.assignedPlantKey,
    this.productionPhaseKey,
    required this.phase,
    this.workCenterId,
    this.processId,
    this.routingStepId,
    required this.requiresOperatorLogin,
    required this.requiresWorkOrder,
    required this.requiresProduct,
    required this.requiresQuantityOutput,
    required this.requiresMaterialConsumption,
    required this.requiresQualityCheck,
    required this.supportsManualProductionInput,
    required this.supportsMachineCounters,
    this.defaultUnit,
    this.allowedUnits = const [],
    required this.machineIntegration,
    required this.packingFlowEnabled,
    this.inboundWarehouseId,
    this.outboundWarehouseId,
    this.legacyOperatorNavSlot,
  });

  static String buildConfigId({
    required String companyId,
    required int stationSlot,
  }) {
    return '${companyId.trim()}__$stationSlot';
  }

  String get title {
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final code = (stationCode ?? '').trim();
    if (code.isNotEmpty) return code;
    return 'Stanica $stationSlot';
  }

  bool get isMachineStation => stationType == stationTypeMachine;

  static ProductionStationConfig fromMap(Map<String, dynamic> data) {
    final miRaw = data['machineIntegration'];
    final mi = miRaw is Map
        ? Map<String, dynamic>.from(miRaw)
        : <String, dynamic>{};

    final slotRaw = data['stationSlot'];
    final slot = slotRaw is int
        ? slotRaw
        : int.tryParse(slotRaw?.toString() ?? '') ?? 1;

    final orderRaw = data['order'];
    final order = orderRaw is int
        ? orderRaw
        : int.tryParse(orderRaw?.toString() ?? '') ?? slot;

    int? legacyNav;
    final ln = data['legacyOperatorNavSlot'];
    if (ln is int) {
      legacyNav = ln;
    } else {
      legacyNav = int.tryParse(ln?.toString() ?? '');
    }

    final unitsRaw = data['allowedUnits'];
    final units = unitsRaw is List
        ? unitsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return ProductionStationConfig(
      id: (data['id'] ?? buildConfigId(
        companyId: (data['companyId'] ?? '').toString(),
        stationSlot: slot,
      )).toString(),
      companyId: (data['companyId'] ?? '').toString().trim(),
      stationSlot: slot,
      stationCode: _optString(data['stationCode']),
      displayName: _optString(data['displayName']),
      order: order,
      active: data['active'] == true,
      description: _optString(data['description']),
      notes: _optString(data['notes']),
      stationType: (data['stationType'] ?? stationTypeProduction).toString().trim(),
      processProfileType:
          (data['processProfileType'] ?? 'standard_production').toString().trim(),
      assignedPlantKey: (data['assignedPlantKey'] ?? '').toString().trim(),
      productionPhaseKey: _optString(data['productionPhaseKey']),
      phase: (data['phase'] ?? 'preparation').toString().trim(),
      workCenterId: _optString(data['workCenterId']),
      processId: _optString(data['processId']),
      routingStepId: _optString(data['routingStepId']),
      requiresOperatorLogin: data['requiresOperatorLogin'] == true,
      requiresWorkOrder: data['requiresWorkOrder'] == true,
      requiresProduct: data['requiresProduct'] == true,
      requiresQuantityOutput: data['requiresQuantityOutput'] == true,
      requiresMaterialConsumption: data['requiresMaterialConsumption'] == true,
      requiresQualityCheck: data['requiresQualityCheck'] == true,
      supportsManualProductionInput: data['supportsManualProductionInput'] != false,
      supportsMachineCounters: data['supportsMachineCounters'] == true,
      defaultUnit: _optString(data['defaultUnit']),
      allowedUnits: units,
      machineIntegration: ProductionStationMachineIntegration.fromMap(mi),
      packingFlowEnabled: data['packingFlowEnabled'] == true,
      inboundWarehouseId: _optString(data['inboundWarehouseId']),
      outboundWarehouseId: _optString(data['outboundWarehouseId']),
      legacyOperatorNavSlot: legacyNav,
    );
  }

  Map<String, dynamic> toUpsertPayload() {
    return {
      'companyId': companyId,
      'stationSlot': stationSlot,
      'stationCode': stationCode,
      'displayName': displayName,
      'order': order,
      'active': active,
      'description': description,
      'notes': notes,
      'stationType': stationType,
      'processProfileType': processProfileType,
      'assignedPlantKey': assignedPlantKey,
      'productionPhaseKey': productionPhaseKey,
      'phase': phase,
      'workCenterId': workCenterId,
      'processId': processId,
      'routingStepId': routingStepId,
      'requiresOperatorLogin': requiresOperatorLogin,
      'requiresWorkOrder': requiresWorkOrder,
      'requiresProduct': requiresProduct,
      'requiresQuantityOutput': requiresQuantityOutput,
      'requiresMaterialConsumption': requiresMaterialConsumption,
      'requiresQualityCheck': requiresQualityCheck,
      'supportsManualProductionInput': supportsManualProductionInput,
      'supportsMachineCounters': supportsMachineCounters,
      'defaultUnit': defaultUnit,
      'allowedUnits': allowedUnits,
      'machineIntegration': machineIntegration.toMap(),
      'packingFlowEnabled': packingFlowEnabled,
      'inboundWarehouseId': inboundWarehouseId,
      'outboundWarehouseId': outboundWarehouseId,
      'legacyOperatorNavSlot': legacyOperatorNavSlot,
    };
  }

  static String? _optString(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static String stationTypeLabel(String type) {
    switch (type) {
      case stationTypeMachine:
        return 'Mašinska stanica';
      case stationTypeProduction:
      default:
        return 'Proizvodna stanica';
    }
  }

  static String processProfileLabel(String profile) {
    switch (profile) {
      case 'wastewater_treatment':
        return 'Obrada otpadnih voda';
      case 'chemical_dosing':
        return 'Doziranje hemikalija';
      case 'rework_and_painting':
        return 'Dorade i lakiranje';
      case 'process_log':
        return 'Procesna evidencija';
      case 'standard_production':
      default:
        return 'Standardna proizvodnja';
    }
  }

  static String productionPhaseLabel(String key) {
    switch (key) {
      case 'pripremna':
        return 'Pripremna';
      case 'priprema_proizvodnje':
        return 'Priprema proizvodnje';
      case 'pakovanje':
        return 'Pakovanje';
      case 'montaza':
        return 'Montaža';
      case 'obrada':
        return 'Obrada';
      case 'kontrola':
        return 'Kontrola';
      case 'zavrsna_kontrola':
        return 'Završna kontrola';
      case 'etiketiranje':
        return 'Etiketiranje';
      case 'zavrsna_obrada':
        return 'Završna obrada';
      case 'ostalo':
        return 'Ostalo';
      default:
        return key;
    }
  }
}

class ProductionStationMachineIntegration {
  final String? assetId;
  final String? gatewayDeviceId;
  final String readMode;
  final String? goodCountTag;
  final String? scrapCountTag;
  final String? runSignalTag;
  final String? downtimeSignalTag;
  final String connectionStatus;

  const ProductionStationMachineIntegration({
    this.assetId,
    this.gatewayDeviceId,
    this.readMode = 'disabled',
    this.goodCountTag,
    this.scrapCountTag,
    this.runSignalTag,
    this.downtimeSignalTag,
    this.connectionStatus = 'not_configured',
  });

  factory ProductionStationMachineIntegration.fromMap(Map<String, dynamic> data) {
    return ProductionStationMachineIntegration(
      assetId: _opt(data['assetId']),
      gatewayDeviceId: _opt(data['gatewayDeviceId']),
      readMode: (data['readMode'] ?? 'disabled').toString().trim(),
      goodCountTag: _opt(data['goodCountTag']),
      scrapCountTag: _opt(data['scrapCountTag']),
      runSignalTag: _opt(data['runSignalTag']),
      downtimeSignalTag: _opt(data['downtimeSignalTag']),
      connectionStatus:
          (data['connectionStatus'] ?? 'not_configured').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assetId': assetId,
      'gatewayDeviceId': gatewayDeviceId,
      'readMode': readMode,
      'goodCountTag': goodCountTag,
      'scrapCountTag': scrapCountTag,
      'runSignalTag': runSignalTag,
      'downtimeSignalTag': downtimeSignalTag,
      'connectionStatus': connectionStatus,
    };
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}

class ProductionStationLimitsSummary {
  final int maxProductionStations;
  final int maxMachineStations;
  final int activeProductionStations;
  final int activeMachineStations;

  const ProductionStationLimitsSummary({
    required this.maxProductionStations,
    required this.maxMachineStations,
    required this.activeProductionStations,
    required this.activeMachineStations,
  });

  factory ProductionStationLimitsSummary.fromMap(Map<String, dynamic>? data) {
    final d = data ?? {};
    int read(dynamic v, int fallback) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return ProductionStationLimitsSummary(
      maxProductionStations: read(d['maxProductionStations'], 3),
      maxMachineStations: read(d['maxMachineStations'], 0),
      activeProductionStations: read(d['activeProductionStations'], 0),
      activeMachineStations: read(d['activeMachineStations'], 0),
    );
  }

  bool canAddProductionStation() =>
      activeProductionStations < maxProductionStations;

  bool canAddMachineStation() => activeMachineStations < maxMachineStations;
}
