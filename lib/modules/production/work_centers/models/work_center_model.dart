import 'package:cloud_firestore/cloud_firestore.dart';

/// MES radni centar — mjesto izvršenja (stroj, linija, stanica, pakovanje, QC, …).
class WorkCenter {
  final String id;
  final String companyId;
  final String plantKey;
  final String workCenterCode;
  final String name;
  final String type;
  final String status;
  final String locationName;
  final String linkedAssetId;
  final String linkedAssetName;
  final double capacityPerHour;
  final double standardCycleTimeSec;
  final int operatorCount;
  final bool isOeeRelevant;
  final bool isOoeRelevant;
  final bool isTeepRelevant;
  final bool active;
  final DateTime? createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String updatedBy;

  const WorkCenter({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.workCenterCode,
    required this.name,
    required this.type,
    required this.status,
    required this.locationName,
    required this.linkedAssetId,
    required this.linkedAssetName,
    required this.capacityPerHour,
    required this.standardCycleTimeSec,
    required this.operatorCount,
    required this.isOeeRelevant,
    required this.isOoeRelevant,
    required this.isTeepRelevant,
    required this.active,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(_s(v)) ?? 0;
  }

  static bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    return fallback;
  }

  factory WorkCenter.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Radni centar nema podataka');
    }
    return WorkCenter.fromMap(doc.id, data);
  }

  factory WorkCenter.fromMap(String id, Map<String, dynamic> data) {
    return WorkCenter(
      id: id,
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      workCenterCode: _s(data['workCenterCode']),
      name: _s(data['name']),
      type: _s(data['type']),
      status: _s(data['status']).isEmpty ? 'idle' : _s(data['status']),
      locationName: _s(data['locationName']),
      linkedAssetId: _s(data['linkedAssetId']),
      linkedAssetName: _s(data['linkedAssetName']),
      capacityPerHour: _d(data['capacityPerHour']),
      standardCycleTimeSec: _d(data['standardCycleTimeSec']),
      operatorCount: _i(data['operatorCount']),
      isOeeRelevant: _b(data['isOeeRelevant']),
      isOoeRelevant: _b(data['isOoeRelevant']),
      isTeepRelevant: _b(data['isTeepRelevant']),
      active: _b(data['active'], fallback: true),
      createdAt: _ts(data['createdAt']),
      createdBy: _s(data['createdBy']),
      updatedAt: _ts(data['updatedAt']),
      updatedBy: _s(data['updatedBy']),
    );
  }

  /// Kanonski tipovi (Firestore `type`).
  static const String typeMachine = 'machine';
  static const String typeProductionLine = 'production_line';
  static const String typeAssemblyStation = 'assembly_station';
  static const String typePackaging = 'packaging';
  static const String typeQualityControl = 'quality_control';
  static const String typeManual = 'manual';
  static const String typeExternal = 'external';

  static const Map<String, String> typeLabels = {
    typeMachine: 'Mašina',
    typeProductionLine: 'Proizvodna linija',
    typeAssemblyStation: 'Montažna stanica',
    typePackaging: 'Pakovanje',
    typeQualityControl: 'Kontrolna stanica',
    typeManual: 'Ručni radni centar',
    typeExternal: 'Eksterni proces',
  };

  static String labelForType(String type) =>
      typeLabels[type] ?? (type.isEmpty ? '—' : type);

  static const String statusOperational = 'operational';
  static const String statusIdle = 'idle';
  static const String statusMaintenance = 'maintenance';
  static const String statusDown = 'down';

  static const Map<String, String> statusLabels = {
    statusOperational: 'Aktivan / u radu',
    statusIdle: 'Miruje',
    statusMaintenance: 'Održavanje',
    statusDown: 'Van pogona',
  };

  static String labelForStatus(String status) =>
      statusLabels[status] ?? (status.isEmpty ? '—' : status);

  static List<MapEntry<String, String>> get selectableTypes =>
      typeLabels.entries.toList();

  static List<MapEntry<String, String>> get selectableStatuses =>
      statusLabels.entries.toList();
}
