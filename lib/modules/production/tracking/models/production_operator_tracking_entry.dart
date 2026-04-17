import 'package:cloud_firestore/cloud_firestore.dart';

import 'tracking_scrap_line.dart';

/// Jedan unos u operativnom praćenju (pripremna / prva / završna kontrola).
/// Kolekcija: `production_operator_tracking/{entryId}`.
class ProductionOperatorTrackingEntry {
  final String id;
  final String companyId;
  final String plantKey;
  final String phase;
  final String workDate;

  final String itemCode;
  final String itemName;
  final double quantity;
  final String unit;

  final String? productId;
  final String? productionOrderId;
  final String? commercialOrderId;

  /// Broj / oznaka naloga izrade sirovih komada (tekst s etikete ili ručni unos).
  final String? rawMaterialOrderCode;

  /// Palica, šarža, linija ili druga interna referenca.
  final String? lineOrBatchRef;

  /// Broj alata ili palice na koju je pripremljen proizvod za puštanje u proizvodnju (pripremna faza).
  final String? releaseToolOrRodRef;
  final String? customerName;

  /// Operater koji radi izradu sirovog komada (evidencija).
  final String? rawWorkOperatorName;

  /// Ime i prezime (ili nadimak) operatera koji je pripremio — snapshot pri spremanju.
  final String? preparedByDisplayName;

  /// ID kutije u [packing_boxes] ako je stavka uključena u zatvorenu kutiju (Stanica 1).
  final String? packedBoxId;
  final String? sourceQrPayload;
  final String? notes;

  /// Škart po tipu (opcionalno); [quantity] je i dalje „pripremljeno / dobro“.
  final List<TrackingScrapLine> scrapBreakdown;

  final DateTime? createdAt;
  final String createdByUid;
  final String createdByEmail;

  /// Jedna ispravka po zapisu; nakon toga više izmjena nije dozvoljeno (Callable).
  final bool correctionApplied;
  final DateTime? correctedAt;
  final String? correctionReason;

  const ProductionOperatorTrackingEntry({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.phase,
    required this.workDate,
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.productId,
    this.productionOrderId,
    this.commercialOrderId,
    this.rawMaterialOrderCode,
    this.lineOrBatchRef,
    this.releaseToolOrRodRef,
    this.customerName,
    this.rawWorkOperatorName,
    this.preparedByDisplayName,
    this.packedBoxId,
    this.sourceQrPayload,
    this.notes,
    this.scrapBreakdown = const [],
    this.createdAt,
    required this.createdByUid,
    required this.createdByEmail,
    this.correctionApplied = false,
    this.correctedAt,
    this.correctionReason,
  });

  static const String phasePreparation = 'preparation';
  static const String phaseFirstControl = 'first_control';
  static const String phaseFinalControl = 'final_control';

  factory ProductionOperatorTrackingEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    DateTime? created;
    final ca = d['createdAt'];
    if (ca is Timestamp) {
      created = ca.toDate();
    }
    DateTime? corrAt;
    final cx = d['correctedAt'];
    if (cx is Timestamp) {
      corrAt = cx.toDate();
    }
    final qty = d['quantity'];
    double q = 0;
    if (qty is num) {
      q = qty.toDouble();
    }
    final scrap = <TrackingScrapLine>[];
    final sb = d['scrapBreakdown'];
    if (sb is List) {
      for (final x in sb) {
        if (x is Map<String, dynamic>) {
          final line = TrackingScrapLine.tryParse(x);
          if (line != null) scrap.add(line);
        } else if (x is Map) {
          final line = TrackingScrapLine.tryParse(Map<String, dynamic>.from(x));
          if (line != null) scrap.add(line);
        }
      }
    }
    return ProductionOperatorTrackingEntry(
      id: doc.id,
      companyId: (d['companyId'] ?? '').toString(),
      plantKey: (d['plantKey'] ?? '').toString(),
      phase: (d['phase'] ?? '').toString(),
      workDate: (d['workDate'] ?? '').toString(),
      itemCode: (d['itemCode'] ?? '').toString(),
      itemName: (d['itemName'] ?? '').toString(),
      quantity: q,
      unit: (d['unit'] ?? 'kom').toString(),
      productId: _s(d['productId']),
      productionOrderId: _s(d['productionOrderId']),
      commercialOrderId: _s(d['commercialOrderId']),
      rawMaterialOrderCode: _s(d['rawMaterialOrderCode']),
      lineOrBatchRef: _s(d['lineOrBatchRef']),
      releaseToolOrRodRef: _s(d['releaseToolOrRodRef']),
      customerName: _s(d['customerName']),
      rawWorkOperatorName: _s(d['rawWorkOperatorName']),
      preparedByDisplayName: _s(d['preparedByDisplayName']),
      packedBoxId: _s(d['packedBoxId']),
      sourceQrPayload: _s(d['sourceQrPayload']),
      notes: _s(d['notes']),
      scrapBreakdown: scrap,
      createdAt: created,
      createdByUid: (d['createdByUid'] ?? '').toString(),
      createdByEmail: (d['createdByEmail'] ?? '').toString(),
      correctionApplied: d['correctionApplied'] == true,
      correctedAt: corrAt,
      correctionReason: _s(d['correctionReason']),
    );
  }

  static String? _s(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  double get scrapTotalQty =>
      scrapBreakdown.fold<double>(0, (a, b) => a + b.qty);

  /// [quantity] u bazi = pripremljeno (dobro) + škart; ako nema škarta, cijeli iznos je dobro.
  double get effectiveGoodQty {
    final g = quantity - scrapTotalQty;
    return g < 0 ? 0 : g;
  }

  String scrapSummaryShort() {
    if (scrapBreakdown.isEmpty) return '';
    return scrapBreakdown
        .map((s) => '${s.label}: ${_fmtQty(s.qty)}')
        .join(' · ');
  }

  /// Sažetak škarta za prikaz / PDF: uvijek [namesByCode] (kompanijski naziv) kad postoji za [TrackingScrapLine.code].
  String scrapBreakdownSummaryForDisplay(Map<String, String> namesByCode) {
    if (scrapBreakdown.isEmpty) return '';
    return scrapBreakdown
        .map((s) {
          final dn = namesByCode[s.code]?.trim();
          final lbl = (dn != null && dn.isNotEmpty) ? dn : s.label;
          return '$lbl: ${_fmtQty(s.qty)}';
        })
        .join(' · ');
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  /// Prikaz kolone „nalog sirovih“: novo polje ili stari [productionOrderId].
  String get displayRawMaterialOrder =>
      (rawMaterialOrderCode ?? '').trim().isNotEmpty
      ? rawMaterialOrderCode!.trim()
      : (productionOrderId ?? '').trim();

  /// Tko je pripremio: snapshot ili e-mail.
  String get displayPreparedBy =>
      (preparedByDisplayName ?? '').trim().isNotEmpty
      ? preparedByDisplayName!.trim()
      : createdByEmail;
}
