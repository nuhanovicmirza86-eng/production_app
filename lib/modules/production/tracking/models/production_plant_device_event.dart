import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductionPlantDeviceEventKind { alarm, downtime }

enum ProductionPlantDeviceEventSeverity { info, warning, critical }

/// Zastoj ili alarm na razini pogona (ručno ili iz budućeg SCADA/MES izvora).
class ProductionPlantDeviceEvent {
  const ProductionPlantDeviceEvent({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.kind,
    required this.severity,
    required this.title,
    this.detail,
    this.assetCode,
    this.occurredAt,
    this.resolvedAt,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final ProductionPlantDeviceEventKind kind;
  final ProductionPlantDeviceEventSeverity severity;
  final String title;
  final String? detail;
  final String? assetCode;
  final DateTime? occurredAt;
  final DateTime? resolvedAt;

  bool get isResolved => resolvedAt != null;

  static ProductionPlantDeviceEvent? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    if (d == null) return null;
    final cid = (d['companyId'] ?? '').toString().trim();
    final pk = (d['plantKey'] ?? '').toString().trim();
    if (cid.isEmpty || pk.isEmpty) return null;

    final kind = _parseKind((d['kind'] ?? '').toString());
    final sev = _parseSeverity((d['severity'] ?? 'warning').toString());
    final title = (d['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;

    DateTime? occ;
    final to = d['occurredAt'];
    if (to is Timestamp) occ = to.toDate();

    DateTime? res;
    final tr = d['resolvedAt'];
    if (tr is Timestamp) res = tr.toDate();

    final detail = (d['detail'] ?? '').toString().trim();
    final ac = (d['assetCode'] ?? '').toString().trim();

    return ProductionPlantDeviceEvent(
      id: doc.id,
      companyId: cid,
      plantKey: pk,
      kind: kind,
      severity: sev,
      title: title,
      detail: detail.isEmpty ? null : detail,
      assetCode: ac.isEmpty ? null : ac,
      occurredAt: occ,
      resolvedAt: res,
    );
  }

  static ProductionPlantDeviceEventKind _parseKind(String s) {
    switch (s.trim().toLowerCase()) {
      case 'downtime':
        return ProductionPlantDeviceEventKind.downtime;
      default:
        return ProductionPlantDeviceEventKind.alarm;
    }
  }

  static ProductionPlantDeviceEventSeverity _parseSeverity(String s) {
    switch (s.trim().toLowerCase()) {
      case 'info':
        return ProductionPlantDeviceEventSeverity.info;
      case 'critical':
        return ProductionPlantDeviceEventSeverity.critical;
      default:
        return ProductionPlantDeviceEventSeverity.warning;
    }
  }
}
