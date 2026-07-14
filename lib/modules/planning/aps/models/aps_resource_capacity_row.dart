/// Jedan red opterećenja resursa iz rough capacity proračuna.
class ApsResourceCapacityRow {
  const ApsResourceCapacityRow({
    required this.resourceId,
    required this.resourceCode,
    required this.availableMinutes,
    required this.allocatedMinutes,
  });

  final String resourceId;
  final String resourceCode;
  final num availableMinutes;
  final num allocatedMinutes;

  num get utilizationPercent {
    if (availableMinutes <= 0) return allocatedMinutes > 0 ? 999 : 0;
    return ((allocatedMinutes / availableMinutes) * 1000).round() / 10;
  }

  String get displayCode =>
      resourceCode.trim().isNotEmpty ? resourceCode.trim() : resourceId;

  factory ApsResourceCapacityRow.fromMap(Map<String, dynamic> map) {
    return ApsResourceCapacityRow(
      resourceId: (map['resourceId'] ?? '').toString().trim(),
      resourceCode: (map['resourceCode'] ?? '').toString().trim(),
      availableMinutes: (map['availableMinutes'] as num?) ?? 0,
      allocatedMinutes: (map['allocatedMinutes'] as num?) ?? 0,
    );
  }
}
