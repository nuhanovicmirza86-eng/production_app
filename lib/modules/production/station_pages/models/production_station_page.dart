import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tracking/models/production_operator_tracking_entry.dart';

/// Dokument u `production_station_pages/{pageId}` — definicija stanice za terminal.
class ProductionStationPage {
  final String id;
  final String companyId;
  final String plantKey;
  final int stationSlot;
  final String phase;
  final String? displayName;
  final bool active;
  final String provisionedByUid;
  final String? provisionedByEmail;
  final DateTime provisionedAt;
  final DateTime updatedAt;
  final String? updatedByUid;
  final String? notes;

  /// Odakle roba dolazi **na** ovu stanicu (ulazni tok / prijem na podu).
  final String? inboundWarehouseId;

  /// Kamo roba odlazi **nakon** ove stanice (izlazni tok; npr. prijem kutije u logistici).
  final String? outboundWarehouseId;

  const ProductionStationPage({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.stationSlot,
    required this.phase,
    this.displayName,
    required this.active,
    required this.provisionedByUid,
    this.provisionedByEmail,
    required this.provisionedAt,
    required this.updatedAt,
    this.updatedByUid,
    this.notes,
    this.inboundWarehouseId,
    this.outboundWarehouseId,
  });

  /// Deterministički id: `{companyId}__{escapedPlantKey}__{stationSlot}`.
  static String buildPageId({
    required String companyId,
    required String plantKey,
    required int stationSlot,
  }) {
    final safePlant = plantKey.replaceAll(RegExp(r'[/\s#]'), '_');
    return '${companyId}__${safePlant}__$stationSlot';
  }

  static String defaultPhaseForSlot(int stationSlot) {
    switch (stationSlot) {
      case 1:
        return ProductionOperatorTrackingEntry.phasePreparation;
      case 2:
        return ProductionOperatorTrackingEntry.phaseFirstControl;
      case 3:
        return ProductionOperatorTrackingEntry.phaseFinalControl;
      default:
        return ProductionOperatorTrackingEntry.phasePreparation;
    }
  }

  /// Slot 1/2/3 za kanonsku fazu (isti mapping kao u `STATION_PAGES_FIRESTORE_SCHEMA.md`).
  static int stationSlotForPhase(String phase) {
    final p = phase.trim();
    if (p == ProductionOperatorTrackingEntry.phaseFirstControl) return 2;
    if (p == ProductionOperatorTrackingEntry.phaseFinalControl) return 3;
    return 1;
  }

  factory ProductionStationPage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    DateTime ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final outboundNew = _trimOrNull(d['outboundWarehouseId']?.toString());
    final outboundLegacy = _trimOrNull(d['packedBoxReceiptWarehouseId']?.toString());

    return ProductionStationPage(
      id: doc.id,
      companyId: (d['companyId'] ?? '').toString(),
      plantKey: (d['plantKey'] ?? '').toString(),
      stationSlot: (d['stationSlot'] is int)
          ? d['stationSlot'] as int
          : int.tryParse('${d['stationSlot']}') ?? 1,
      phase: (d['phase'] ?? ProductionOperatorTrackingEntry.phasePreparation)
          .toString(),
      displayName: _trimOrNull(d['displayName']?.toString()),
      active: d['active'] == true,
      provisionedByUid: (d['provisionedByUid'] ?? '').toString(),
      provisionedByEmail: _trimOrNull(d['provisionedByEmail']?.toString()),
      provisionedAt: ts(d['provisionedAt']),
      updatedAt: ts(d['updatedAt']),
      updatedByUid: _trimOrNull(d['updatedByUid']?.toString()),
      notes: _trimOrNull(d['notes']?.toString()),
      inboundWarehouseId: _trimOrNull(d['inboundWarehouseId']?.toString()),
      outboundWarehouseId: outboundNew ?? outboundLegacy,
    );
  }

  static String? _trimOrNull(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toFirestoreCreate({
    required String currentUid,
    String? currentEmail,
  }) {
    final now = FieldValue.serverTimestamp();
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'stationSlot': stationSlot,
      'phase': phase,
      if (displayName != null && displayName!.trim().isNotEmpty)
        'displayName': displayName!.trim(),
      'active': active,
      'provisionedByUid': currentUid,
      if (currentEmail != null && currentEmail.trim().isNotEmpty)
        'provisionedByEmail': currentEmail.trim(),
      'provisionedAt': now,
      'updatedAt': now,
      if (updatedByUid != null && updatedByUid!.trim().isNotEmpty)
        'updatedByUid': updatedByUid!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (inboundWarehouseId != null && inboundWarehouseId!.trim().isNotEmpty)
        'inboundWarehouseId': inboundWarehouseId!.trim(),
      if (outboundWarehouseId != null && outboundWarehouseId!.trim().isNotEmpty)
        'outboundWarehouseId': outboundWarehouseId!.trim(),
    };
  }

  /// Ažuriranje postojećeg dokumenta — ne smije mijenjati [provisionedByUid] / [provisionedAt].
  Map<String, dynamic> toFirestoreUpdate({
    required String currentUid,
  }) {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'stationSlot': stationSlot,
      'phase': phase,
      'active': active,
      'provisionedByUid': provisionedByUid,
      'provisionedAt': Timestamp.fromDate(provisionedAt),
      if (provisionedByEmail != null && provisionedByEmail!.trim().isNotEmpty)
        'provisionedByEmail': provisionedByEmail!.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': currentUid,
      if (displayName != null && displayName!.trim().isNotEmpty)
        'displayName': displayName!.trim()
      else
        'displayName': FieldValue.delete(),
      if (notes != null && notes!.trim().isNotEmpty)
        'notes': notes!.trim()
      else
        'notes': FieldValue.delete(),
      if (inboundWarehouseId != null && inboundWarehouseId!.trim().isNotEmpty)
        'inboundWarehouseId': inboundWarehouseId!.trim()
      else
        'inboundWarehouseId': FieldValue.delete(),
      if (outboundWarehouseId != null && outboundWarehouseId!.trim().isNotEmpty)
        'outboundWarehouseId': outboundWarehouseId!.trim()
      else
        'outboundWarehouseId': FieldValue.delete(),
      'packedBoxReceiptWarehouseId': FieldValue.delete(),
    };
  }

  ProductionStationPage copyWith({
    String? phase,
    String? displayName,
    bool? active,
    String? notes,
    DateTime? updatedAt,
    String? updatedByUid,
    String? inboundWarehouseId,
    String? outboundWarehouseId,
  }) {
    return ProductionStationPage(
      id: id,
      companyId: companyId,
      plantKey: plantKey,
      stationSlot: stationSlot,
      phase: phase ?? this.phase,
      displayName: displayName ?? this.displayName,
      active: active ?? this.active,
      provisionedByUid: provisionedByUid,
      provisionedByEmail: provisionedByEmail,
      provisionedAt: provisionedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      notes: notes ?? this.notes,
      inboundWarehouseId: inboundWarehouseId ?? this.inboundWarehouseId,
      outboundWarehouseId: outboundWarehouseId ?? this.outboundWarehouseId,
    );
  }
}
