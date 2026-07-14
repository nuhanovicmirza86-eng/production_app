import '../helpers/aps_callable_timestamp.dart';
import '../helpers/aps_gantt_info_copy.dart';

/// Scenarij za P3 picker — poslovni nazivi u UI, [id] samo za odabir.
class ApsScenarioView {
  const ApsScenarioView({
    required this.id,
    required this.scenarioCode,
    required this.scenarioName,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.isActive = true,
    this.lastSnapshotId,
    this.objectiveProfileId,
  });

  final String id;
  final String scenarioCode;
  final String scenarioName;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String status;
  final bool isActive;
  final String? lastSnapshotId;
  final String? objectiveProfileId;

  bool get hasOptimizationGoal =>
      objectiveProfileId != null && objectiveProfileId!.trim().isNotEmpty;

  String get displayLabel {
    if (scenarioName.trim().isNotEmpty) return scenarioName.trim();
    return scenarioCode.trim().isNotEmpty ? scenarioCode.trim() : 'Scenarij';
  }

  String get subtitleLabel {
    final code = scenarioCode.trim();
    final statusLabel = ApsGanttInfoCopy.scenarioStatusLabel(status);
    if (code.isEmpty || code == displayLabel) return statusLabel;
    return '$code · $statusLabel';
  }

  bool get isApprovedForPilotRelease => status == 'approved';

  bool get isPilotReleasedToMes => status == 'released_to_mes';

  /// P4a UI — scenarij s generiranim rasporedom, prije potvrde.
  bool get isReadyForPlanConfirmation => status == 'solved';

  /// P5.3 — scenarij spreman za pokretanje optimizacije.
  bool get isEligibleForOptimization {
    if (!hasOptimizationGoal) return false;
    switch (status.trim().toLowerCase()) {
      case 'solved':
      case 'review_required':
      case 'approved':
        return true;
      default:
        return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApsScenarioView && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory ApsScenarioView.fromMap(Map<String, dynamic> map) {
    final active = map['isActive'];
    return ApsScenarioView(
      id: (map['id'] ?? '').toString().trim(),
      scenarioCode: (map['scenarioCode'] ?? '').toString().trim(),
      scenarioName: (map['scenarioName'] ?? '').toString().trim(),
      periodStart: parseApsCallableTimestamp(map['periodStart']),
      periodEnd: parseApsCallableTimestamp(map['periodEnd']),
      status: (map['status'] ?? '').toString().trim(),
      isActive: active is bool ? active : true,
      lastSnapshotId: _optionalString(map['lastSnapshotId']),
      objectiveProfileId: _optionalString(map['objectiveProfileId']),
    );
  }

  static String? _optionalString(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
