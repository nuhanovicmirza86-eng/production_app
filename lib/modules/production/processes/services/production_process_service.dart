import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_process_model.dart';

class ProductionProcessService {
  ProductionProcessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('production_processes');

  String _s(dynamic v) => (v ?? '').toString().trim();

  static bool _isActiveForStatus(String status) =>
      status == ProductionProcess.statusActive;

  Future<void> _ensureUniqueCode({
    required String companyId,
    required String plantKey,
    required String processCode,
    String? excludeProcessId,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final code = processCode.trim();
    if (cid.isEmpty || pk.isEmpty || code.isEmpty) {
      throw Exception('Nedostaju companyId, plantKey ili šifra procesa.');
    }

    final q = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('processCode', isEqualTo: code)
        .limit(5)
        .get();

    for (final doc in q.docs) {
      if (excludeProcessId != null && doc.id == excludeProcessId) {
        continue;
      }
      throw Exception('Proces s ovom šifrom već postoji na ovom pogonu.');
    }
  }

  Map<String, dynamic> _buildPayload({
    required String companyId,
    required String plantKey,
    required String processCode,
    required String name,
    required String description,
    required String processType,
    required String status,
    required bool iatfRelevant,
    required bool traceabilityRequired,
    required bool qualityControlRequired,
    required bool firstPieceApprovalRequired,
    required bool processParametersRequired,
    required bool operatorQualificationRequired,
    required bool workInstructionRequired,
    required bool pfmeaRequired,
    required bool controlPlanRequired,
    required List<String> linkedWorkCenterTypes,
    required List<String> linkedWorkCenterIds,
    required String pfmeaReference,
    required String controlPlanReference,
    required String workInstructionReference,
    required String userId,
    required DateTime now,
    DateTime? createdAt,
    String? createdBy,
  }) {
    final uid = _s(userId);
    final st = status.trim();
    final isActive = _isActiveForStatus(st);
    return {
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'processCode': processCode.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'processType': processType.trim(),
      'status': st,
      'isActive': isActive,
      'iatfRelevant': iatfRelevant,
      'traceabilityRequired': traceabilityRequired,
      'qualityControlRequired': qualityControlRequired,
      'firstPieceApprovalRequired': firstPieceApprovalRequired,
      'processParametersRequired': processParametersRequired,
      'operatorQualificationRequired': operatorQualificationRequired,
      'workInstructionRequired': workInstructionRequired,
      'pfmeaRequired': pfmeaRequired,
      'controlPlanRequired': controlPlanRequired,
      'linkedWorkCenterTypes': linkedWorkCenterTypes,
      'linkedWorkCenterIds': linkedWorkCenterIds,
      'pfmeaReference': pfmeaReference.trim(),
      'controlPlanReference': controlPlanReference.trim(),
      'workInstructionReference': workInstructionReference.trim(),
      'createdAt': createdAt ?? now,
      'createdBy': (createdBy ?? uid).isEmpty ? uid : _s(createdBy),
      'updatedAt': now,
      'updatedBy': uid,
    };
  }

  Stream<List<ProductionProcess>> watchProcesses({
    required String companyId,
    required String plantKey,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return Stream.value(const []);
    }

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ProductionProcess.fromDoc).toList();
          list.sort(
            (a, b) => a.processCode.toLowerCase().compareTo(
              b.processCode.toLowerCase(),
            ),
          );
          return list;
        });
  }

  Future<ProductionProcess?> getById({
    required String companyId,
    required String plantKey,
    required String processId,
  }) async {
    final id = processId.trim();
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (id.isEmpty || cid.isEmpty || pk.isEmpty) return null;

    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;

    final p = ProductionProcess.fromDoc(doc);
    if (p.companyId != cid || p.plantKey != pk) return null;
    return p;
  }

  Future<String> createProcess({
    required String companyId,
    required String plantKey,
    required String processCode,
    required String name,
    required String description,
    required String processType,
    required String status,
    required bool iatfRelevant,
    required bool traceabilityRequired,
    required bool qualityControlRequired,
    required bool firstPieceApprovalRequired,
    required bool processParametersRequired,
    required bool operatorQualificationRequired,
    required bool workInstructionRequired,
    required bool pfmeaRequired,
    required bool controlPlanRequired,
    required List<String> linkedWorkCenterTypes,
    required List<String> linkedWorkCenterIds,
    required String pfmeaReference,
    required String controlPlanReference,
    required String workInstructionReference,
    required String createdBy,
  }) async {
    final uid = _s(createdBy);
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit polja.');
    }

    await _ensureUniqueCode(
      companyId: companyId,
      plantKey: plantKey,
      processCode: processCode,
    );

    final now = DateTime.now();
    final ref = _col.doc();
    final payload = _buildPayload(
      companyId: companyId,
      plantKey: plantKey,
      processCode: processCode,
      name: name,
      description: description,
      processType: processType,
      status: status,
      iatfRelevant: iatfRelevant,
      traceabilityRequired: traceabilityRequired,
      qualityControlRequired: qualityControlRequired,
      firstPieceApprovalRequired: firstPieceApprovalRequired,
      processParametersRequired: processParametersRequired,
      operatorQualificationRequired: operatorQualificationRequired,
      workInstructionRequired: workInstructionRequired,
      pfmeaRequired: pfmeaRequired,
      controlPlanRequired: controlPlanRequired,
      linkedWorkCenterTypes: linkedWorkCenterTypes,
      linkedWorkCenterIds: linkedWorkCenterIds,
      pfmeaReference: pfmeaReference,
      controlPlanReference: controlPlanReference,
      workInstructionReference: workInstructionReference,
      userId: uid,
      now: now,
    );

    await ref.set(payload);
    return ref.id;
  }

  Future<void> updateProcess({
    required ProductionProcess existing,
    required String processCode,
    required String name,
    required String description,
    required String processType,
    required String status,
    required bool iatfRelevant,
    required bool traceabilityRequired,
    required bool qualityControlRequired,
    required bool firstPieceApprovalRequired,
    required bool processParametersRequired,
    required bool operatorQualificationRequired,
    required bool workInstructionRequired,
    required bool pfmeaRequired,
    required bool controlPlanRequired,
    required List<String> linkedWorkCenterTypes,
    required List<String> linkedWorkCenterIds,
    required String pfmeaReference,
    required String controlPlanReference,
    required String workInstructionReference,
    required String updatedBy,
  }) async {
    final uid = _s(updatedBy);
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit polja.');
    }

    if (existing.isArchived) {
      throw Exception('Arhivirani proces se ne može uređivati.');
    }

    await _ensureUniqueCode(
      companyId: existing.companyId,
      plantKey: existing.plantKey,
      processCode: processCode,
      excludeProcessId: existing.id,
    );

    final now = DateTime.now();
    final st = status.trim();
    await _col.doc(existing.id).update({
      'processCode': processCode.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'processType': processType.trim(),
      'status': st,
      'isActive': _isActiveForStatus(st),
      'iatfRelevant': iatfRelevant,
      'traceabilityRequired': traceabilityRequired,
      'qualityControlRequired': qualityControlRequired,
      'firstPieceApprovalRequired': firstPieceApprovalRequired,
      'processParametersRequired': processParametersRequired,
      'operatorQualificationRequired': operatorQualificationRequired,
      'workInstructionRequired': workInstructionRequired,
      'pfmeaRequired': pfmeaRequired,
      'controlPlanRequired': controlPlanRequired,
      'linkedWorkCenterTypes': linkedWorkCenterTypes,
      'linkedWorkCenterIds': linkedWorkCenterIds,
      'pfmeaReference': pfmeaReference.trim(),
      'controlPlanReference': controlPlanReference.trim(),
      'workInstructionReference': workInstructionReference.trim(),
      'updatedAt': now,
      'updatedBy': uid,
    });
  }

  Future<void> setStatus({
    required ProductionProcess existing,
    required String newStatus,
    required String updatedBy,
  }) async {
    final uid = _s(updatedBy);
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit polja.');
    }

    final st = newStatus.trim();
    if (!ProductionProcess.statusLabels.containsKey(st)) {
      throw Exception('Nepoznat status procesa.');
    }

    if (existing.isArchived && st != ProductionProcess.statusArchived) {
      throw Exception('Arhivirani proces se ne može vraćati u rad iz ovog ekrana.');
    }

    await _col.doc(existing.id).update({
      'status': st,
      'isActive': _isActiveForStatus(st),
      'updatedAt': DateTime.now(),
      'updatedBy': uid,
    });
  }
}
