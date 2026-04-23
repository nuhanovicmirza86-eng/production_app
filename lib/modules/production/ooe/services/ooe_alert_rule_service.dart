import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ooe_alert_rule.dart';
import 'ooe_catalog_callable_service.dart';

class OoeAlertRuleService {
  OoeAlertRuleService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final OoeCatalogCallableService _cc = OoeCatalogCallableService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('ooe_alert_rules');

  String _s(dynamic v) => (v ?? '').toString().trim();

  Stream<List<OoeAlertRule>> watchRules({
    required String companyId,
    required String plantKey,
  }) {
    final c = _s(companyId);
    final p = _s(plantKey);
    if (c.isEmpty || p.isEmpty) {
      return const Stream.empty();
    }
    return _col
        .where('companyId', isEqualTo: c)
        .where('plantKey', isEqualTo: p)
        .snapshots()
        .map((s) {
          final list = s.docs.map(OoeAlertRule.fromDoc).toList();
          list.sort((a, b) => a.machineId.compareTo(b.machineId));
          return list;
        });
  }

  Future<String> createRule({
    required String companyId,
    required String plantKey,
    required String machineId,
    required String ruleType,
    required double threshold,
    String? name,
    bool active = true,
  }) async {
    return _cc.upsertOoeAlertRule(
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      machineId: _s(machineId),
      ruleType: _s(ruleType),
      threshold: threshold,
      name: name != null && name.trim().isNotEmpty ? name.trim() : null,
      active: active,
      isUpdate: false,
    );
  }

  Future<void> updateRule({
    required String ruleId,
    required String companyId,
    required String plantKey,
    required String machineId,
    required String ruleType,
    required double threshold,
    required String name,
    required bool active,
  }) async {
    await _cc.upsertOoeAlertRule(
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      ruleId: _s(ruleId),
      machineId: _s(machineId),
      ruleType: _s(ruleType),
      threshold: threshold,
      name: name,
      active: active,
      isUpdate: true,
    );
  }

  Future<void> deleteRule({
    required String ruleId,
    required String companyId,
    required String plantKey,
  }) async {
    await _cc.deleteOoeAlertRule(
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      ruleId: _s(ruleId),
    );
  }
}
