import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/downtime_event_model.dart';

class DowntimeService {
  DowntimeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('downtime_events');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  String _generateDowntimeCode({
    required String plantKey,
    required DateTime now,
  }) {
    final y = now.year.toString().substring(2);
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final millis = now.millisecondsSinceEpoch.toString();
    final tail = millis.length > 4 ? millis.substring(millis.length - 4) : millis;
    final pk = plantKey.trim().isEmpty ? 'PL' : plantKey.trim();
    return 'Z-$pk-$y$mo$d-$tail';
  }

  Stream<List<DowntimeEventModel>> watchDowntimeEvents({
    required String companyId,
    required String plantKey,
    int limit = 400,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return Stream.value(const []);
    }

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(DowntimeEventModel.fromDoc).toList());
  }

  Future<String> createDowntime({
    required String companyId,
    required String plantKey,
    required String productionOrderId,
    required String productionOrderCode,
    required String workCenterId,
    required String workCenterCode,
    required String workCenterName,
    required String processId,
    required String processCode,
    required String processName,
    required String downtimeCategory,
    required String downtimeReason,
    required String description,
    required String severity,
    required DateTime startedAt,
    required bool isPlanned,
    required bool affectsOee,
    required bool affectsOoe,
    required bool affectsTeep,
    required String operatorId,
    required String reportedBy,
    required String reportedByName,
    String shiftId = '',
    String shiftName = '',
    bool correctiveActionRequired = false,
    String correctiveActionId = '',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final uid = _s(reportedBy);
    if (uid.isEmpty) throw Exception('Nedostaje korisnik za audit.');

    final doc = _col.doc();
    final now = DateTime.now();
    final code = _generateDowntimeCode(plantKey: plantKey, now: now);

    await doc.set({
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'downtimeCode': code,
      'productionOrderId': productionOrderId.trim(),
      'productionOrderCode': productionOrderCode.trim(),
      'workCenterId': workCenterId.trim(),
      'workCenterCode': workCenterCode.trim(),
      'workCenterName': workCenterName.trim(),
      'processId': processId.trim(),
      'processCode': processCode.trim(),
      'processName': processName.trim(),
      'shiftId': shiftId.trim(),
      'shiftName': shiftName.trim(),
      'downtimeCategory': downtimeCategory.trim(),
      'downtimeReason': downtimeReason.trim(),
      'description': description.trim(),
      'status': DowntimeEventStatus.open,
      'severity': severity.trim().isEmpty ? DowntimeSeverity.medium : severity.trim(),
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': null,
      'durationMinutes': null,
      'isPlanned': isPlanned,
      'affectsOee': affectsOee,
      'affectsOoe': affectsOoe,
      'affectsTeep': affectsTeep,
      'operatorId': operatorId.trim().isEmpty ? uid : operatorId.trim(),
      'reportedBy': uid,
      'reportedByName': reportedByName.trim(),
      'resolvedBy': '',
      'resolvedByName': '',
      'verifiedBy': '',
      'verifiedByName': '',
      'correctiveActionRequired': correctiveActionRequired,
      'correctiveActionId': correctiveActionId.trim(),
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(now),
      'createdBy': uid,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': uid,
    });

    return doc.id;
  }

  Future<void> updateStatus({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorUid,
    required String newStatus,
  }) async {
    final id = downtimeId.trim();
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final uid = actorUid.trim();
    if (id.isEmpty || cid.isEmpty || pk.isEmpty || uid.isEmpty) {
      throw Exception('Nedostaju parametri za ažuriranje.');
    }

    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Zastoj nije pronađen.');
    final m = DowntimeEventModel.fromDoc(snap);
    if (m.companyId != cid || m.plantKey != pk) {
      throw Exception('Nemaš pristup ovom zastoju.');
    }

    final now = DateTime.now();
    await ref.update({
      'status': newStatus.trim(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': uid,
    });
  }

  Future<void> resolveDowntime({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorUid,
    required String actorDisplayName,
    DateTime? endedAt,
  }) async {
    final id = downtimeId.trim();
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final uid = actorUid.trim();
    if (id.isEmpty || cid.isEmpty || pk.isEmpty || uid.isEmpty) {
      throw Exception('Nedostaju parametri za zatvaranje.');
    }

    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Zastoj nije pronađen.');
    final m = DowntimeEventModel.fromDoc(snap);
    if (m.companyId != cid || m.plantKey != pk) {
      throw Exception('Nemaš pristup ovom zastoju.');
    }

    final end = endedAt ?? DateTime.now();
    var mins = end.difference(m.startedAt).inMinutes;
    if (mins < 0) mins = 0;

    final now = DateTime.now();
    await ref.update({
      'status': DowntimeEventStatus.resolved,
      'endedAt': Timestamp.fromDate(end),
      'durationMinutes': mins,
      'resolvedBy': uid,
      'resolvedByName': actorDisplayName.trim(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': uid,
    });
  }

  Future<void> verifyDowntime({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorUid,
    required String actorDisplayName,
  }) async {
    final id = downtimeId.trim();
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final uid = actorUid.trim();
    if (id.isEmpty || cid.isEmpty || pk.isEmpty || uid.isEmpty) {
      throw Exception('Nedostaju parametri za verifikaciju.');
    }

    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Zastoj nije pronađen.');
    final m = DowntimeEventModel.fromDoc(snap);
    if (m.companyId != cid || m.plantKey != pk) {
      throw Exception('Nemaš pristup ovom zastoju.');
    }
    if (m.status != DowntimeEventStatus.resolved) {
      throw Exception('Samo zastoj u statusu „Riješen“ može biti verificiran.');
    }

    final now = DateTime.now();
    await ref.update({
      'status': DowntimeEventStatus.verified,
      'verifiedBy': uid,
      'verifiedByName': actorDisplayName.trim(),
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': uid,
    });
  }

  Future<void> rejectDowntime({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorUid,
    required String actorDisplayName,
    String? noteAppend,
  }) async {
    final id = downtimeId.trim();
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final uid = actorUid.trim();
    if (id.isEmpty || cid.isEmpty || pk.isEmpty || uid.isEmpty) {
      throw Exception('Nedostaju parametri.');
    }

    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Zastoj nije pronađen.');
    final m = DowntimeEventModel.fromDoc(snap);
    if (m.companyId != cid || m.plantKey != pk) {
      throw Exception('Nemaš pristup ovom zastoju.');
    }

    final now = DateTime.now();
    final extra = _s(noteAppend);
    final desc = extra.isEmpty
        ? m.description
        : '${m.description}\n[Odbijeno: $extra]'.trim();

    await ref.update({
      'status': DowntimeEventStatus.rejected,
      'description': desc,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': uid,
      'resolvedBy': uid,
      'resolvedByName': actorDisplayName.trim(),
    });
  }

  Future<void> archiveDowntime({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorUid,
  }) async {
    await updateStatus(
      downtimeId: downtimeId,
      companyId: companyId,
      plantKey: plantKey,
      actorUid: actorUid,
      newStatus: DowntimeEventStatus.archived,
    );
  }

  /// Zastoji za analitiku: `startedAt` od (početak perioda minus [bufferDaysBeforeRange])
  /// do min(sada, kraj perioda). Paginacija do [maxPages] stranica.
  Future<List<DowntimeEventModel>> fetchEventsForAnalytics({
    required String companyId,
    required String plantKey,
    required DateTime rangeStartLocal,
    required DateTime rangeEndExclusiveLocal,
    int bufferDaysBeforeRange = 120,
    int pageSize = 500,
    int maxPages = 60,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final from = rangeStartLocal.subtract(
      Duration(days: bufferDaysBeforeRange),
    );
    var to = rangeEndExclusiveLocal;
    final n = DateTime.now();
    if (to.isAfter(n)) to = n;

    if (!to.isAfter(from)) return const [];

    final out = <DowntimeEventModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;

    for (var p = 0; p < maxPages; p++) {
      Query<Map<String, dynamic>> q = _col
          .where('companyId', isEqualTo: cid)
          .where('plantKey', isEqualTo: pk)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('startedAt', isLessThan: Timestamp.fromDate(to))
          .orderBy('startedAt')
          .limit(pageSize);

      final cur = cursor;
      if (cur != null) {
        q = q.startAfterDocument(cur);
      }

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      for (final d in snap.docs) {
        out.add(DowntimeEventModel.fromDoc(d));
      }
      cursor = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }

    return out;
  }
}
