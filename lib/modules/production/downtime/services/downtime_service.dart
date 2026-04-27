import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/downtime_event_model.dart';
import 'downtime_callable_service.dart';

class DowntimeService {
  DowntimeService({FirebaseFirestore? firestore, DowntimeCallableService? callables})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _callables = callables ?? DowntimeCallableService();

  final FirebaseFirestore _firestore;
  final DowntimeCallableService _callables;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('downtime_events');

  static String _s(dynamic v) => (v ?? '').toString().trim();

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

    final create = <String, dynamic>{
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
      'severity': severity.trim().isEmpty ? DowntimeSeverity.medium : severity.trim(),
      'startedAt': startedAt.toIso8601String(),
      'isPlanned': isPlanned,
      'affectsOee': affectsOee,
      'affectsOoe': affectsOoe,
      'affectsTeep': affectsTeep,
      'operatorId': operatorId.trim().isEmpty ? uid : operatorId.trim(),
      'reportedBy': uid,
      'reportedByName': reportedByName.trim(),
      'correctiveActionRequired': correctiveActionRequired,
      'correctiveActionId': correctiveActionId.trim(),
      'attachments': attachments,
    };
    return _callables.create(
      companyId: companyId,
      plantKey: plantKey,
      create: create,
    );
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
    await _callables.updateStatus(
      downtimeId: id,
      companyId: cid,
      plantKey: pk,
      newStatus: newStatus,
    );
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
    await _callables.resolve(
      downtimeId: id,
      companyId: cid,
      plantKey: pk,
      actorDisplayName: actorDisplayName,
      endedAt: endedAt,
    );
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
    await _callables.verify(
      downtimeId: id,
      companyId: cid,
      plantKey: pk,
      actorDisplayName: actorDisplayName,
    );
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
    await _callables.reject(
      downtimeId: id,
      companyId: cid,
      plantKey: pk,
      actorDisplayName: actorDisplayName,
      noteAppend: noteAppend,
    );
  }

  Future<void> archiveDowntime({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorUid,
  }) async {
    await _callables.archive(
      downtimeId: downtimeId,
      companyId: companyId,
      plantKey: plantKey,
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
