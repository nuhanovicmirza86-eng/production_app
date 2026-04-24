import 'downtime_analytics_engine.dart';

/// Usporedba: cilj OOE (iz kataloga strojeva) vs OEE gubitak u minutama (zastoji) za povezani radni centar.
class DowntimeMachineTargetRow {
  final String machineId;
  final String machineLabel;
  final double? targetOoeFraction;
  final String workCenterLabel;
  final int oeeLossMinutes;

  const DowntimeMachineTargetRow({
    required this.machineId,
    required this.machineLabel,
    required this.targetOoeFraction,
    required this.workCenterLabel,
    required this.oeeLossMinutes,
  });
}

/// Prikaz cilja OOE (udio 0–1) kao postotak.
String downtimeMachineTargetOoeLabel(double? fraction) {
  final t = fraction;
  if (t == null) return '—';
  return '${(t * 100).toStringAsFixed(1)} %';
}

/// Gradi retke samo za strojeve koji imaju postavljen cilj OOE u `ooe_machine_targets`.
List<DowntimeMachineTargetRow> buildDowntimeMachineTargetRows({
  required DowntimeAnalyticsReport report,
  required Map<String, double?> targetOoeByMachineId,
  required List<({String id, String linkedAssetId, String label})> workCenters,
  required Map<String, String> machineLabelById,
}) {
  final byWc = <String, DowntimeGroupStats>{
    for (final g in report.byWorkCenter) g.key: g,
  };

  final rows = <DowntimeMachineTargetRow>[];
  for (final e in targetOoeByMachineId.entries) {
    final mid = e.key.trim();
    if (mid.isEmpty) continue;
    final tgt = e.value;
    if (tgt == null) continue;

    final wcLabels = <String>[];
    var oeeSum = 0;
    for (final w in workCenters) {
      if (w.linkedAssetId.trim() != mid) continue;
      wcLabels.add(w.label);
      final st = byWc[w.id];
      if (st != null) oeeSum += st.minutesOee;
    }

    rows.add(
      DowntimeMachineTargetRow(
        machineId: mid,
        machineLabel: machineLabelById[mid]?.trim().isNotEmpty == true
            ? machineLabelById[mid]!.trim()
            : mid,
        targetOoeFraction: tgt,
        workCenterLabel: wcLabels.isEmpty ? '—' : wcLabels.join(', '),
        oeeLossMinutes: oeeSum,
      ),
    );
  }

  rows.sort((a, b) => b.oeeLossMinutes.compareTo(a.oeeLossMinutes));
  return rows;
}
