import 'package:cloud_functions/cloud_functions.dart';

/// M1-I11-B — lookup WMS lotova za Pripremu materijala za operaciju.
class OmpWmsLotLookupService {
  OmpWmsLotLookupService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<OmpWmsLotLookupResult> lookup({
    required String companyId,
    required String materialId,
    String? warehouseId,
    String? lotDocId,
    String? lotId,
  }) async {
    final res = await _functions
        .httpsCallable('lookupInventoryLotsForMaterialPreparation')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'materialId': materialId,
          if ((warehouseId ?? '').trim().isNotEmpty)
            'warehouseId': warehouseId!.trim(),
          if ((lotDocId ?? '').trim().isNotEmpty) 'lotDocId': lotDocId!.trim(),
          if ((lotId ?? '').trim().isNotEmpty) 'lotId': lotId!.trim(),
        });
    return OmpWmsLotLookupResult.fromMap(
      Map<String, dynamic>.from(res.data as Map),
    );
  }
}

class OmpWmsLotRow {
  const OmpWmsLotRow({
    required this.lotDocId,
    required this.lotId,
    this.batchNumber,
    required this.availableQty,
    this.unit,
    this.status,
    required this.statusLabel,
    this.warehouseId,
    this.warehouseName,
    this.warehouseCode,
    required this.warehouseDisplay,
    this.selectable = false,
  });

  final String lotDocId;
  final String lotId;
  final String? batchNumber;
  final num availableQty;
  final String? unit;
  final String? status;
  final String statusLabel;
  final String? warehouseId;
  final String? warehouseName;
  final String? warehouseCode;
  final String warehouseDisplay;
  final bool selectable;

  factory OmpWmsLotRow.fromMap(Map<String, dynamic> m) {
    return OmpWmsLotRow(
      lotDocId: (m['lotDocId'] ?? '').toString().trim(),
      lotId: (m['lotId'] ?? '').toString().trim(),
      batchNumber: _opt(m['batchNumber']),
      availableQty: m['availableQty'] is num
          ? m['availableQty'] as num
          : num.tryParse('${m['availableQty']}') ?? 0,
      unit: _opt(m['unit']),
      status: _opt(m['status']),
      statusLabel: (m['statusLabel'] ?? '—').toString().trim(),
      warehouseId: _opt(m['warehouseId']),
      warehouseName: _opt(m['warehouseName']),
      warehouseCode: _opt(m['warehouseCode']),
      warehouseDisplay: (m['warehouseDisplay'] ?? '—').toString().trim(),
      selectable: m['selectable'] == true,
    );
  }

  static String? _opt(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  String get qtyDisplay {
    final q = availableQty == availableQty.roundToDouble()
        ? availableQty.toInt().toString()
        : availableQty.toStringAsFixed(2);
    final u = (unit ?? '').trim();
    return u.isEmpty ? q : '$q $u';
  }

  String get lotDisplay {
    final batch = (batchNumber ?? '').trim();
    if (batch.isNotEmpty && batch != lotId) {
      return '$lotId (šarža $batch)';
    }
    return lotId;
  }
}

class OmpWmsLotLookupResult {
  const OmpWmsLotLookupResult({
    required this.success,
    required this.logisticsModuleActive,
    required this.softFallbackAllowed,
    this.softFallbackReason,
    required this.lots,
    required this.selectableLots,
    this.resolvedLot,
    this.message,
    this.mismatch = false,
  });

  final bool success;
  final bool logisticsModuleActive;
  final bool softFallbackAllowed;
  final String? softFallbackReason;
  final List<OmpWmsLotRow> lots;
  final List<OmpWmsLotRow> selectableLots;
  final OmpWmsLotRow? resolvedLot;
  final String? message;
  final bool mismatch;

  factory OmpWmsLotLookupResult.fromMap(Map<String, dynamic> m) {
    List<OmpWmsLotRow> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => OmpWmsLotRow.fromMap(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    OmpWmsLotRow? resolved;
    final r = m['resolvedLot'];
    if (r is Map) {
      resolved = OmpWmsLotRow.fromMap(Map<String, dynamic>.from(r));
    }

    return OmpWmsLotLookupResult(
      success: m['success'] != false,
      logisticsModuleActive: m['logisticsModuleActive'] == true,
      softFallbackAllowed: m['softFallbackAllowed'] == true,
      softFallbackReason: OmpWmsLotRow._opt(m['softFallbackReason']),
      lots: parseList(m['lots']),
      selectableLots: parseList(m['selectableLots']),
      resolvedLot: resolved,
      message: OmpWmsLotRow._opt(m['message']),
      mismatch: m['mismatch'] == true,
    );
  }
}
