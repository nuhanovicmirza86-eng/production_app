import 'package:cloud_firestore/cloud_firestore.dart';

import 'packing_box_callable_service.dart';

/// Jedna stavka u kutiji (proizvod + količina + veza na tracking unos).
class PackingBoxLine {
  PackingBoxLine({
    required this.productCode,
    required this.productName,
    required this.qtyGood,
    required this.unit,
    this.productionOrderCode,
    this.productId,
    this.trackingEntryId,
    this.preparedByDisplayName,
    this.preparedByUid,
  });

  final String productCode;
  final String productName;
  final double qtyGood;
  final String unit;
  final String? productionOrderCode;
  final String? productId;
  final String? trackingEntryId;
  final String? preparedByDisplayName;
  final String? preparedByUid;

  Map<String, dynamic> toMap() => {
    'productCode': productCode,
    'productName': productName,
    'qtyGood': qtyGood,
    'unit': unit,
    if (productionOrderCode != null && productionOrderCode!.isNotEmpty)
      'productionOrderCode': productionOrderCode,
    if (productId != null && productId!.isNotEmpty) 'productId': productId,
    if (trackingEntryId != null && trackingEntryId!.isNotEmpty)
      'trackingEntryId': trackingEntryId,
    if (preparedByDisplayName != null && preparedByDisplayName!.isNotEmpty)
      'preparedByDisplayName': preparedByDisplayName,
    if (preparedByUid != null && preparedByUid!.isNotEmpty)
      'preparedByUid': preparedByUid,
  };

  static PackingBoxLine fromMap(Map<String, dynamic> m) {
    final q = m['qtyGood'];
    double qty = 0;
    if (q is num) {
      qty = q.toDouble();
    }
    return PackingBoxLine(
      productCode: (m['productCode'] ?? '').toString().trim(),
      productName: (m['productName'] ?? '').toString().trim(),
      qtyGood: qty,
      unit: (m['unit'] ?? 'kom').toString().trim(),
      productionOrderCode: _s(m['productionOrderCode']),
      productId: _s(m['productId']),
      trackingEntryId: _s(m['trackingEntryId']),
      preparedByDisplayName: _s(m['preparedByDisplayName']),
      preparedByUid: _s(m['preparedByUid']),
    );
  }

  static String? _s(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }
}

/// Zapis u `packing_boxes`.
class PackingBoxRecord {
  PackingBoxRecord({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.stationKey,
    required this.classification,
    required this.lines,
    required this.status,
    required this.createdByUid,
    this.createdAt,
    this.receivedAt,
    this.receivedByUid,
    this.toWarehouseId,
    this.stationSlot = 1,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String stationKey;
  /// Slot stanice (1–3) — mapiranje na `production_station_pages` za magacin prijema.
  final int stationSlot;
  final String classification;
  final List<PackingBoxLine> lines;
  final String status;
  final String createdByUid;
  final DateTime? createdAt;
  final DateTime? receivedAt;
  final String? receivedByUid;
  final String? toWarehouseId;

  static PackingBoxRecord fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final rawLines = d['lines'];
    final lines = <PackingBoxLine>[];
    if (rawLines is List) {
      for (final x in rawLines) {
        if (x is Map<String, dynamic>) {
          lines.add(PackingBoxLine.fromMap(x));
        } else if (x is Map) {
          lines.add(PackingBoxLine.fromMap(Map<String, dynamic>.from(x)));
        }
      }
    }
    DateTime? cr;
    final ca = d['createdAt'];
    if (ca is Timestamp) cr = ca.toDate();
    DateTime? ra;
    final rx = d['receivedAt'];
    if (rx is Timestamp) ra = rx.toDate();
    final slotRaw = d['stationSlot'];
    final stationSlot = slotRaw is int
        ? slotRaw
        : int.tryParse('${slotRaw ?? ''}') ?? 1;
    final ss = stationSlot < 1 || stationSlot > 3 ? 1 : stationSlot;

    return PackingBoxRecord(
      id: doc.id,
      companyId: (d['companyId'] ?? '').toString().trim(),
      plantKey: (d['plantKey'] ?? '').toString().trim(),
      stationKey: (d['stationKey'] ?? '').toString().trim(),
      classification: (d['classification'] ?? '').toString().trim(),
      lines: lines,
      status: (d['status'] ?? '').toString().trim(),
      createdByUid: (d['createdByUid'] ?? '').toString().trim(),
      createdAt: cr,
      receivedAt: ra,
      receivedByUid: _opt(d['receivedByUid']),
      toWarehouseId: _opt(d['toWarehouseId']),
      stationSlot: ss,
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}

class PackingBoxService {
  PackingBoxService({FirebaseFirestore? firestore, PackingBoxCallableService? callable})
    : _db = firestore ?? FirebaseFirestore.instance,
      _callable = callable ?? PackingBoxCallableService();

  final FirebaseFirestore _db;
  final PackingBoxCallableService _callable;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('packing_boxes');

  final String _stationKey = 'preparation';

  /// Kreira kutiju, vraća [id] dokumenta (Callable — ne direktan Firestore write).
  Future<String> createBox({
    required String companyId,
    required String plantKey,
    required String classification,
    required List<PackingBoxLine> lines,
    int stationSlot = 1,
  }) async {
    if (lines.isEmpty) {
      throw StateError('Lista kutije je prazna.');
    }
    return _callable.createPackingBox(
      companyId: companyId,
      plantKey: plantKey,
      classification: classification,
      lines: lines.map((e) => e.toMap()).toList(),
      stationSlot: stationSlot,
    );
  }

  Stream<List<PackingBoxRecord>> watchClosedPendingReceipt({
    required String companyId,
    required String plantKey,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const Stream.empty();
    }
    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('stationKey', isEqualTo: _stationKey)
        .where('status', isEqualTo: 'closed')
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snap) => snap.docs.map(PackingBoxRecord.fromDoc).toList());
  }

  Future<PackingBoxRecord?> getBox(String boxId) async {
    final doc = await _col.doc(boxId.trim()).get();
    if (!doc.exists) return null;
    return PackingBoxRecord.fromDoc(doc);
  }

  Future<void> markReceived({
    required String companyId,
    required String boxId,
  }) async {
    await _callable.markPackingBoxReceived(
      companyId: companyId,
      boxId: boxId,
    );
  }

  /// Upozorenja za operatore: stavke bez `packedBoxId` za dan (Callable).
  Future<void> writeAlertsForUnpackedEntries({
    required String companyId,
    required String plantKey,
    required String workDate,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final wd = workDate.trim();
    if (cid.isEmpty || pk.isEmpty || wd.isEmpty) return;
    await _callable.writePackingOperatorAlertsUnpacked(
      companyId: cid,
      plantKey: pk,
      workDate: wd,
    );
  }
}
