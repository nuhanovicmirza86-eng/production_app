import 'package:cloud_firestore/cloud_firestore.dart';

/// Magacin (master) — kolekcija `warehouses`.
class WarehouseRef {
  final String id;
  final String code;
  final String name;
  final String? plantKey;
  final int displayOrder;
  final bool isActive;

  const WarehouseRef({
    required this.id,
    required this.code,
    required this.name,
    this.plantKey,
    required this.displayOrder,
    required this.isActive,
  });
}

/// Jedan red: zaliha proizvoda u magacinu (nakon spajanja master + stanje).
class ProductWarehouseStockLine {
  final String warehouseId;
  final String warehouseCode;
  final String warehouseName;
  final String? warehousePlantKey;
  final double quantityOnHand;
  final String? unit;

  const ProductWarehouseStockLine({
    required this.warehouseId,
    required this.warehouseCode,
    required this.warehouseName,
    this.warehousePlantKey,
    required this.quantityOnHand,
    this.unit,
  });
}

/// Agregat zaliha po magacinima za jedan proizvod.
///
/// Firestore:
/// - `warehouses`: companyId, code, name, plantKey?, displayOrder, isActive
/// - `inventory_balances`: companyId, warehouseId, productId, quantityOnHand, unit?
class ProductWarehouseStockService {
  ProductWarehouseStockService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _warehouses =>
      _firestore.collection('warehouses');

  CollectionReference<Map<String, dynamic>> get _balances =>
      _firestore.collection('inventory_balances');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  static double _qty(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;
  }

  static bool _bool(dynamic v, {bool defaultValue = true}) {
    if (v is bool) return v;
    return defaultValue;
  }

  /// Ako je [plantKey] zadan, prikazuju se aktivni magacini: dijeljeni (bez pogona)
  /// ili vezani za taj pogon. Ako je null/prazan — svi aktivni magacini kompanije.
  Future<List<ProductWarehouseStockLine>> loadStockLinesForProduct({
    required String companyId,
    required String productId,
    String? plantKey,
  }) async {
    final cid = companyId.trim();
    final pid = productId.trim();
    if (cid.isEmpty || pid.isEmpty) return const [];

    final warehousesSnap = await _warehouses
        .where('companyId', isEqualTo: cid)
        .get();

    final plant = plantKey?.trim() ?? '';
    final warehouses = <WarehouseRef>[];

    for (final doc in warehousesSnap.docs) {
      final d = doc.data();
      if (_s(d['companyId']) != cid) continue;
      if (!_bool(d['isActive'], defaultValue: true)) continue;

      final whPlant = _s(d['plantKey']);
      if (plant.isNotEmpty) {
        final shared = whPlant.isEmpty;
        if (!shared && whPlant != plant) continue;
      }

      warehouses.add(
        WarehouseRef(
          id: doc.id,
          code: _s(d['code']).isEmpty ? doc.id : _s(d['code']),
          name: _s(d['name']).isEmpty ? doc.id : _s(d['name']),
          plantKey: whPlant.isEmpty ? null : whPlant,
          displayOrder: _i(d['displayOrder']),
          isActive: true,
        ),
      );
    }

    warehouses.sort((a, b) {
      final c = a.displayOrder.compareTo(b.displayOrder);
      if (c != 0) return c;
      return a.code.toLowerCase().compareTo(b.code.toLowerCase());
    });

    final balSnap = await _balances
        .where('companyId', isEqualTo: cid)
        .where('productId', isEqualTo: pid)
        .get();

    final byWh = <String, Map<String, dynamic>>{};
    for (final doc in balSnap.docs) {
      final d = doc.data();
      final wid = _s(d['warehouseId']);
      if (wid.isEmpty) continue;
      byWh[wid] = d;
    }

    return warehouses.map((w) {
      final raw = byWh[w.id];
      final q = raw != null
          ? _qty(
              raw['quantityOnHand'] ??
                  raw['qtyOnHand'] ??
                  raw['quantity'] ??
                  raw['onHand'],
            )
          : 0.0;
      final u = raw != null ? _nullableString(raw['unit']) : null;

      return ProductWarehouseStockLine(
        warehouseId: w.id,
        warehouseCode: w.code,
        warehouseName: w.name,
        warehousePlantKey: w.plantKey,
        quantityOnHand: q,
        unit: u,
      );
    }).toList();
  }

  static String? _nullableString(dynamic v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }
}
