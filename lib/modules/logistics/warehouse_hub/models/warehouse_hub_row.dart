/// Red u katalogu magacina (Firestore `warehouses`).
class WarehouseHubRow {
  final String id;
  /// Prikazni kod (npr. MAG_12 ili legacy `code`).
  final String code;
  final String name;
  final String? systemWarehouseCode;
  final String? plantKey;
  final bool isHub;
  final String type;
  final int displayOrder;
  final bool isActive;
  final bool canReceive;
  final bool canShip;

  const WarehouseHubRow({
    required this.id,
    required this.code,
    required this.name,
    this.systemWarehouseCode,
    this.plantKey,
    required this.isHub,
    required this.type,
    required this.displayOrder,
    required this.isActive,
    required this.canReceive,
    required this.canShip,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static int _i(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? fallback;
  }

  static bool _bool(dynamic v, {bool defaultValue = true}) {
    if (v is bool) return v;
    return defaultValue;
  }

  factory WarehouseHubRow.fromDoc(String id, Map<String, dynamic> d) {
    final sys = _s(d['systemWarehouseCode']);
    final legacyCode = _s(d['code']);
    final whCode = _s(d['warehouseCode']);
    final code = sys.isNotEmpty
        ? sys
        : (legacyCode.isNotEmpty
              ? legacyCode
              : (whCode.isNotEmpty ? whCode : id));
    return WarehouseHubRow(
      id: id,
      code: code,
      name: _s(d['name']).isEmpty ? code : _s(d['name']),
      systemWarehouseCode: sys.isNotEmpty ? sys : null,
      plantKey: _s(d['plantKey']).isEmpty ? null : _s(d['plantKey']),
      isHub: d['isHub'] == true,
      type: _s(d['type']).isEmpty ? 'other' : _s(d['type']),
      displayOrder: _i(d['displayOrder'] ?? d['order'], fallback: 0),
      isActive: _bool(d['isActive'] ?? d['active'], defaultValue: true),
      canReceive: _bool(d['canReceive'], defaultValue: true),
      canShip: _bool(d['canShip'], defaultValue: true),
    );
  }
}
