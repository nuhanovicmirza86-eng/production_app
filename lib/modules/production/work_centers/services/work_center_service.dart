import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/work_center_model.dart';

class WorkCenterService {
  WorkCenterService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('work_centers');

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _ensureUniqueCode({
    required String companyId,
    required String plantKey,
    required String workCenterCode,
    String? excludeWorkCenterId,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final code = workCenterCode.trim();
    if (cid.isEmpty || pk.isEmpty || code.isEmpty) {
      throw Exception('Nedostaju companyId, plantKey ili šifra radnog centra.');
    }

    final q = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('workCenterCode', isEqualTo: code)
        .limit(5)
        .get();

    for (final doc in q.docs) {
      if (excludeWorkCenterId != null && doc.id == excludeWorkCenterId) {
        continue;
      }
      throw Exception('Radni centar s ovom šifrom već postoji na ovom pogonu.');
    }
  }

  /// Jednokratno učitavanje za padajuće izbore (filtrira aktivne lokalno).
  Future<List<WorkCenter>> listWorkCentersForPlant({
    required String companyId,
    required String plantKey,
    bool onlyActive = true,
    int limit = 300,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final snap = await _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .limit(limit)
        .get();

    var list = snap.docs.map(WorkCenter.fromDoc).toList();
    if (onlyActive) {
      list = list.where((w) => w.active).toList();
    }
    list.sort(
      (a, b) => a.workCenterCode.toLowerCase().compareTo(
        b.workCenterCode.toLowerCase(),
      ),
    );
    return list;
  }

  Stream<List<WorkCenter>> watchWorkCenters({
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
          final list = snap.docs.map(WorkCenter.fromDoc).toList();
          list.sort(
            (a, b) => a.workCenterCode.toLowerCase().compareTo(
              b.workCenterCode.toLowerCase(),
            ),
          );
          return list;
        });
  }

  Future<WorkCenter?> getById({
    required String companyId,
    required String plantKey,
    required String workCenterId,
  }) async {
    final id = workCenterId.trim();
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (id.isEmpty || cid.isEmpty || pk.isEmpty) return null;

    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;

    final wc = WorkCenter.fromDoc(doc);
    if (wc.companyId != cid || wc.plantKey != pk) return null;
    return wc;
  }

  Future<String> createWorkCenter({
    required String companyId,
    required String plantKey,
    required String workCenterCode,
    required String name,
    required String type,
    required String status,
    required String locationName,
    required String linkedAssetId,
    required String linkedAssetName,
    required double capacityPerHour,
    required double standardCycleTimeSec,
    required int operatorCount,
    required bool isOeeRelevant,
    required bool isOoeRelevant,
    required bool isTeepRelevant,
    required bool active,
    required String createdBy,
  }) async {
    final uid = _s(createdBy);
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit polja.');
    }

    await _ensureUniqueCode(
      companyId: companyId,
      plantKey: plantKey,
      workCenterCode: workCenterCode,
    );

    final now = DateTime.now();
    final ref = _col.doc();

    await ref.set({
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'workCenterCode': workCenterCode.trim(),
      'name': name.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'locationName': locationName.trim(),
      'linkedAssetId': linkedAssetId.trim(),
      'linkedAssetName': linkedAssetName.trim(),
      'capacityPerHour': capacityPerHour,
      'standardCycleTimeSec': standardCycleTimeSec,
      'operatorCount': operatorCount,
      'isOeeRelevant': isOeeRelevant,
      'isOoeRelevant': isOoeRelevant,
      'isTeepRelevant': isTeepRelevant,
      'active': active,
      'createdAt': now,
      'createdBy': uid,
      'updatedAt': now,
      'updatedBy': uid,
    });

    return ref.id;
  }

  Future<void> updateWorkCenter({
    required WorkCenter existing,
    required String workCenterCode,
    required String name,
    required String type,
    required String status,
    required String locationName,
    required String linkedAssetId,
    required String linkedAssetName,
    required double capacityPerHour,
    required double standardCycleTimeSec,
    required int operatorCount,
    required bool isOeeRelevant,
    required bool isOoeRelevant,
    required bool isTeepRelevant,
    required bool active,
    required String updatedBy,
  }) async {
    final uid = _s(updatedBy);
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit polja.');
    }

    await _ensureUniqueCode(
      companyId: existing.companyId,
      plantKey: existing.plantKey,
      workCenterCode: workCenterCode,
      excludeWorkCenterId: existing.id,
    );

    await _col.doc(existing.id).update({
      'workCenterCode': workCenterCode.trim(),
      'name': name.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'locationName': locationName.trim(),
      'linkedAssetId': linkedAssetId.trim(),
      'linkedAssetName': linkedAssetName.trim(),
      'capacityPerHour': capacityPerHour,
      'standardCycleTimeSec': standardCycleTimeSec,
      'operatorCount': operatorCount,
      'isOeeRelevant': isOeeRelevant,
      'isOoeRelevant': isOoeRelevant,
      'isTeepRelevant': isTeepRelevant,
      'active': active,
      'updatedAt': DateTime.now(),
      'updatedBy': uid,
    });
  }

  Future<void> deactivateWorkCenter({
    required String workCenterId,
    required String companyId,
    required String plantKey,
    required String updatedBy,
  }) async {
    final wc = await getById(
      companyId: companyId,
      plantKey: plantKey,
      workCenterId: workCenterId,
    );
    if (wc == null) {
      throw Exception('Radni centar nije pronađen.');
    }

    final uid = _s(updatedBy);
    if (uid.isEmpty) {
      throw Exception('Nedostaje korisnik za audit polja.');
    }

    await _col.doc(workCenterId).update({
      'active': false,
      'status': WorkCenter.statusIdle,
      'updatedAt': DateTime.now(),
      'updatedBy': uid,
    });
  }
}
