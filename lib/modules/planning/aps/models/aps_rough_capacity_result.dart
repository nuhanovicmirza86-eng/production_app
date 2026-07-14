import '../helpers/aps_capacity_load_helper.dart';
import 'aps_resource_capacity_row.dart';

/// Rezultat rough capacity proračuna (P1).
class ApsRoughCapacityResult {
  const ApsRoughCapacityResult({
    required this.snapshotId,
    required this.utilizationPercent,
    required this.totalDemandMinutes,
    required this.totalAvailableMinutes,
    required this.demandCount,
    required this.resourceCount,
    required this.warningCount,
    required this.hasCriticalWarnings,
    required this.scenarioStatus,
    required this.summaryByResource,
  });

  final String snapshotId;
  final num utilizationPercent;
  final num totalDemandMinutes;
  final num totalAvailableMinutes;
  final int demandCount;
  final int resourceCount;
  final int warningCount;
  final bool hasCriticalWarnings;
  final String scenarioStatus;
  final List<ApsResourceCapacityRow> summaryByResource;

  ApsCapacityLoadLevel get overallLoadLevel =>
      ApsCapacityLoadHelper.scenarioLevel(
        utilizationPercent: utilizationPercent,
        hasCriticalWarnings: hasCriticalWarnings,
        warningCount: warningCount,
      );

  factory ApsRoughCapacityResult.fromCallableData(Map<String, dynamic>? data) {
    final map = data ?? const {};
    final rawSummary = map['summaryByResource'];
    final rows = <ApsResourceCapacityRow>[];
    if (rawSummary is List) {
      for (final raw in rawSummary) {
        if (raw is! Map) continue;
        rows.add(
          ApsResourceCapacityRow.fromMap(Map<String, dynamic>.from(raw)),
        );
      }
    }
    return ApsRoughCapacityResult(
      snapshotId: (map['snapshotId'] ?? '').toString().trim(),
      utilizationPercent: (map['utilizationPercent'] as num?) ?? 0,
      totalDemandMinutes: (map['totalDemandMinutes'] as num?) ?? 0,
      totalAvailableMinutes: (map['totalAvailableMinutes'] as num?) ?? 0,
      demandCount: (map['demandCount'] as num?)?.toInt() ?? 0,
      resourceCount: (map['resourceCount'] as num?)?.toInt() ?? 0,
      warningCount: (map['warningCount'] as num?)?.toInt() ?? 0,
      hasCriticalWarnings: map['hasCriticalWarnings'] == true,
      scenarioStatus: (map['scenarioStatus'] ?? '').toString().trim(),
      summaryByResource: rows,
    );
  }
}
