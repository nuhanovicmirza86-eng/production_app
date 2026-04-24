import 'package:cloud_firestore/cloud_firestore.dart';

import '../../work_centers/models/work_center_model.dart';

/// MES master-data: standardni tip aktivnosti (proces), odvojeno od routingu.
class ProductionProcess {
  final String id;
  final String companyId;
  final String plantKey;
  final String processCode;
  final String name;
  final String description;
  final String processType;
  final String status;
  final bool isActive;
  final bool iatfRelevant;
  final bool traceabilityRequired;
  final bool qualityControlRequired;
  final bool firstPieceApprovalRequired;
  final bool processParametersRequired;
  final bool operatorQualificationRequired;
  final bool workInstructionRequired;
  final bool pfmeaRequired;
  final bool controlPlanRequired;
  final List<String> linkedWorkCenterTypes;
  final List<String> linkedWorkCenterIds;
  /// Opcionalne reference (ID ili tekst) za kasniji Quality modul.
  final String pfmeaReference;
  final String controlPlanReference;
  final String workInstructionReference;
  final DateTime? createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String updatedBy;

  const ProductionProcess({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.processCode,
    required this.name,
    required this.description,
    required this.processType,
    required this.status,
    required this.isActive,
    required this.iatfRelevant,
    required this.traceabilityRequired,
    required this.qualityControlRequired,
    required this.firstPieceApprovalRequired,
    required this.processParametersRequired,
    required this.operatorQualificationRequired,
    required this.workInstructionRequired,
    required this.pfmeaRequired,
    required this.controlPlanRequired,
    required this.linkedWorkCenterTypes,
    required this.linkedWorkCenterIds,
    required this.pfmeaReference,
    required this.controlPlanReference,
    required this.workInstructionReference,
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

  static bool _b(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    return fallback;
  }

  static List<String> _strList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  factory ProductionProcess.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Proces nema podataka');
    }
    return ProductionProcess.fromMap(doc.id, data);
  }

  factory ProductionProcess.fromMap(String id, Map<String, dynamic> data) {
    final statusRaw = _s(data['status']);
    final resolvedStatus = statusRaw.isEmpty ? statusDraft : statusRaw;
    final isActive = _b(
      data['isActive'],
      fallback: resolvedStatus == statusActive,
    );

    return ProductionProcess(
      id: id,
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      processCode: _s(data['processCode']),
      name: _s(data['name']),
      description: _s(data['description']),
      processType: _s(data['processType']),
      status: resolvedStatus,
      isActive: isActive,
      iatfRelevant: _b(data['iatfRelevant']),
      traceabilityRequired: _b(data['traceabilityRequired']),
      qualityControlRequired: _b(data['qualityControlRequired']),
      firstPieceApprovalRequired: _b(data['firstPieceApprovalRequired']),
      processParametersRequired: _b(data['processParametersRequired']),
      operatorQualificationRequired: _b(data['operatorQualificationRequired']),
      workInstructionRequired: _b(data['workInstructionRequired']),
      pfmeaRequired: _b(data['pfmeaRequired']),
      controlPlanRequired: _b(data['controlPlanRequired']),
      linkedWorkCenterTypes: _strList(data['linkedWorkCenterTypes']),
      linkedWorkCenterIds: _strList(data['linkedWorkCenterIds']),
      pfmeaReference: _s(data['pfmeaReference']),
      controlPlanReference: _s(data['controlPlanReference']),
      workInstructionReference: _s(data['workInstructionReference']),
      createdAt: _ts(data['createdAt']),
      createdBy: _s(data['createdBy']),
      updatedAt: _ts(data['updatedAt']),
      updatedBy: _s(data['updatedBy']),
    );
  }

  bool get isArchived => status == statusArchived;
  bool get isSelectableForNewRouting =>
      status == statusActive && isActive && !isArchived;

  static const String statusDraft = 'draft';
  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';
  static const String statusArchived = 'archived';

  static const Map<String, String> statusLabels = {
    statusDraft: 'Nacrt',
    statusActive: 'Aktivan',
    statusInactive: 'Neaktivan',
    statusArchived: 'Arhiviran',
  };

  static String labelForStatus(String status) =>
      statusLabels[status] ?? (status.isEmpty ? '—' : status);

  /// Kanonski kod tipa procesa (Firestore `processType`).
  static const String typeCutting = 'cutting';
  static const String typeMachining = 'machining';
  static const String typeInjectionMolding = 'injection_molding';
  static const String typeAssembly = 'assembly';
  static const String typeWelding = 'welding';
  static const String typeHeatTreatment = 'heat_treatment';
  static const String typeSurfaceTreatment = 'surface_treatment';
  static const String typeWashing = 'washing';
  static const String typeQualityControl = 'quality_control';
  static const String typePackaging = 'packaging';
  static const String typeWarehousing = 'warehousing';
  static const String typeInternalTransport = 'internal_transport';
  static const String typeExternalProcess = 'external_process';

  static const Map<String, String> typeLabels = {
    typeCutting: 'Rezanje',
    typeMachining: 'Mašinska obrada',
    typeInjectionMolding: 'Brizganje plastike',
    typeAssembly: 'Montaža',
    typeWelding: 'Zavarivanje',
    typeHeatTreatment: 'Termička obrada',
    typeSurfaceTreatment: 'Površinska obrada',
    typeWashing: 'Pranje',
    typeQualityControl: 'Kontrola kvaliteta',
    typePackaging: 'Pakovanje',
    typeWarehousing: 'Skladištenje',
    typeInternalTransport: 'Interni transport',
    typeExternalProcess: 'Eksterni proces',
  };

  static String labelForType(String type) =>
      typeLabels[type] ?? (type.isEmpty ? '—' : type);

  static List<MapEntry<String, String>> get selectableTypes =>
      typeLabels.entries.toList();

  static List<MapEntry<String, String>> get selectableStatuses =>
      statusLabels.entries.toList();

  /// Tipovi radnih centara iz [WorkCenter] — za ograničenje „gdje smije proces”.
  static List<MapEntry<String, String>> get selectableWorkCenterTypes =>
      WorkCenter.typeLabels.entries.toList();
}
