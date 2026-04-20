/// Jedna ruta između magacina (`warehouse_routes`).
class WarehouseRouteRow {
  final String id;
  final String companyId;
  final String fromWarehouseId;
  final String toWarehouseId;
  final List<String> allowedItemTypes;
  final bool requiresQualityCheck;
  final bool active;
  final String? notes;

  const WarehouseRouteRow({
    required this.id,
    required this.companyId,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.allowedItemTypes,
    required this.requiresQualityCheck,
    required this.active,
    this.notes,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  factory WarehouseRouteRow.fromDoc(String id, Map<String, dynamic> d) {
    final raw = d['allowedItemTypes'];
    final types = <String>[];
    if (raw is List) {
      for (final x in raw) {
        final t = _s(x).toLowerCase();
        if (t.isNotEmpty) types.add(t);
      }
    }
    return WarehouseRouteRow(
      id: id,
      companyId: _s(d['companyId']),
      fromWarehouseId: _s(d['fromWarehouseId']),
      toWarehouseId: _s(d['toWarehouseId']),
      allowedItemTypes: types,
      requiresQualityCheck: d['requiresQualityCheck'] == true,
      active: d['active'] != false,
      notes: _s(d['notes']).isEmpty ? null : _s(d['notes']),
    );
  }
}
