import 'package:flutter/foundation.dart';

@immutable
class PlanningScenarioRecord {
  const PlanningScenarioRecord({
    required this.id,
    required this.title,
    required this.scenarioType,
    this.basePlanId = '',
    this.notes,
  });

  final String id;
  final String title;
  /// `baseline` | `whatif`
  final String scenarioType;
  final String basePlanId;
  final String? notes;

  static PlanningScenarioRecord fromMap(String id, Map<String, dynamic> m) {
    var t = (m['title'] ?? '').toString().trim();
    if (t.isEmpty) {
      t = '(bez naslova)';
    }
    return PlanningScenarioRecord(
      id: id,
      title: t,
      scenarioType: (m['scenarioType'] ?? 'baseline').toString().trim().toLowerCase(),
      basePlanId: (m['basePlanId'] ?? '').toString().trim(),
      notes: m['notes'] as String?,
    );
  }
}
