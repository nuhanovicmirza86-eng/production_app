import 'package:cloud_firestore/cloud_firestore.dart';

/// Pravilo mapiranja Operonix → ERP (`finance_mapping_rules`).
class FinanceMappingRuleModel {
  const FinanceMappingRuleModel({
    required this.id,
    required this.companyId,
    required this.ruleType,
    required this.sourceEntityType,
    required this.targetEntityType,
    this.connectionId = '',
    this.enabled = true,
    this.priority = 0,
    this.sourcePattern = '',
    this.targetPattern = '',
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String ruleType;
  final String sourceEntityType;
  final String targetEntityType;
  final String connectionId;
  final bool enabled;
  final int priority;
  final String sourcePattern;
  final String targetPattern;
  final DateTime? updatedAt;

  factory FinanceMappingRuleModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceMappingRuleModel(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      ruleType: (data['ruleType'] ?? '').toString().trim(),
      sourceEntityType: (data['sourceEntityType'] ?? '').toString().trim(),
      targetEntityType: (data['targetEntityType'] ?? '').toString().trim(),
      connectionId: (data['connectionId'] ?? '').toString().trim(),
      enabled: data['enabled'] != false,
      priority: _i(data['priority']),
      sourcePattern: (data['sourcePattern'] ?? '').toString().trim(),
      targetPattern: (data['targetPattern'] ?? '').toString().trim(),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
