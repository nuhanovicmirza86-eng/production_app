/// Upozorenje rough capacity / planiranja (aps_capacity_warnings).
class ApsCapacityWarningView {
  const ApsCapacityWarningView({
    required this.id,
    required this.severity,
    required this.warningCode,
    required this.message,
    this.snapshotId = '',
    this.demandId,
    this.resourceId,
  });

  final String id;
  final String severity;
  final String warningCode;
  final String message;
  final String snapshotId;
  final String? demandId;
  final String? resourceId;

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';

  factory ApsCapacityWarningView.fromMap(Map<String, dynamic> map) {
    final demand = (map['demandId'] ?? '').toString().trim();
    final resource = (map['resourceId'] ?? '').toString().trim();
    return ApsCapacityWarningView(
      id: (map['id'] ?? '').toString().trim(),
      severity: (map['severity'] ?? '').toString().trim(),
      warningCode: (map['warningCode'] ?? '').toString().trim(),
      message: (map['message'] ?? '').toString().trim(),
      snapshotId: (map['snapshotId'] ?? '').toString().trim(),
      demandId: demand.isEmpty ? null : demand,
      resourceId: resource.isEmpty ? null : resource,
    );
  }
}
