import 'package:cloud_firestore/cloud_firestore.dart';

/// Prag za OOE alarm (`ooe_alert_rules`).
class OoeAlertRule {
  final String id;
  final String companyId;
  final String plantKey;
  final String machineId;
  final String ruleType;
  final double threshold;
  final String? name;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OoeAlertRule({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.machineId,
    required this.ruleType,
    required this.threshold,
    this.name,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  static const String typeOoeBelow = 'ooe_below';
  static const String typeScrapRateAbove = 'scrap_rate_above';

  factory OoeAlertRule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null) {
      return OoeAlertRule(
        id: doc.id,
        companyId: '',
        plantKey: '',
        machineId: '',
        ruleType: typeOoeBelow,
        threshold: 0,
        active: true,
      );
    }
    return OoeAlertRule.fromMap(doc.id, m);
  }

  factory OoeAlertRule.fromMap(String id, Map<String, dynamic> m) {
    return OoeAlertRule(
      id: id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      machineId: (m['machineId'] ?? '').toString(),
      ruleType: (m['ruleType'] ?? typeOoeBelow).toString(),
      threshold: (m['threshold'] as num?)?.toDouble() ?? 0,
      name: m['name']?.toString(),
      active: m['active'] != false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'machineId': machineId,
      'ruleType': ruleType,
      'threshold': threshold,
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      'active': active,
    };
  }
}
