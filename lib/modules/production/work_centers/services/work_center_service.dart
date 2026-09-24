import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/work_center_model.dart';

class WorkCenterService {
  WorkCenterService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('work_centers');

  String _s(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _asStringKeyMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

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

    final existing = await listWorkCentersForPlant(
      companyId: cid,
      plantKey: pk,
      onlyActive: false,
    );
    for (final wc in existing) {
      if (excludeWorkCenterId != null && wc.id == excludeWorkCenterId) {
        continue;
      }
      if (wc.workCenterCode.trim().toLowerCase() == code.toLowerCase()) {
        throw Exception(
          'Radni centar s ovom šifrom već postoji na ovom pogonu.',
        );
      }
    }
  }

  /// APP-RBAC-M1-C — lista preko Callable, ne klijentski Firestore.
  Future<List<WorkCenter>> listWorkCentersForPlant({
    required String companyId,
    required String plantKey,
    bool onlyActive = true,
    int limit = 300,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    try {
      final res = await _functions.httpsCallable('listWorkCenters').call({
        'companyId': cid,
        'plantKey': pk,
      });
      final data = _asStringKeyMap(res.data);
      final rawItems = data['items'];
      final list = <WorkCenter>[];
      if (rawItems is List) {
        for (final row in rawItems) {
          final map = _asStringKeyMap(row);
          final id = _s(map['id']);
          if (id.isEmpty) continue;
          list.add(WorkCenter.fromMap(id, map));
        }
      }
      var out = list;
      if (onlyActive) {
        out = out.where((w) => w.active).toList();
      }
      if (out.length > limit) {
        out = out.take(limit).toList();
      }
      out.sort(
        (a, b) => a.workCenterCode.toLowerCase().compareTo(
          b.workCenterCode.toLowerCase(),
        ),
      );
      return out;
    } catch (e) {
      throw Exception(AppErrorMapper.toMessage(e));
    }
  }

  Stream<List<WorkCenter>> watchWorkCenters({
    required String companyId,
    required String plantKey,
  }) {
    return Stream.fromFuture(
      listWorkCentersForPlant(
        companyId: companyId,
        plantKey: plantKey,
        onlyActive: false,
      ),
    );
  }

  Future<WorkCenter?> getById({
    required String companyId,
    required String plantKey,
    required String workCenterId,
  }) async {
    final id = workCenterId.trim();
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (id.isEmpty || cid.isEmpty) return null;

    try {
      final res = await _functions.httpsCallable('getWorkCenter').call({
        'companyId': cid,
        'workCenterId': id,
      });
      final data = _asStringKeyMap(res.data);
      final item = _asStringKeyMap(data['item']);
      final itemId = _s(item['id']);
      if (itemId.isEmpty) return null;
      final wc = WorkCenter.fromMap(itemId, item);
      if (pk.isNotEmpty && wc.plantKey != pk) return null;
      return wc;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') return null;
      throw Exception(AppErrorMapper.toMessage(e));
    } catch (e) {
      throw Exception(AppErrorMapper.toMessage(e));
    }
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
