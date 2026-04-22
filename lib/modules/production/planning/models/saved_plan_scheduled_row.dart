import 'package:flutter/foundation.dart';

/// Jedan red u tablici detalja plana — svi nizovi su za prikaz, bez golih ID-eva.
@immutable
class SavedPlanScheduledRow {
  const SavedPlanScheduledRow({
    required this.productionOrderCode,
    this.operationLabel,
    required this.operationSequence,
    required this.plannedStart,
    required this.plannedEnd,
    required this.resourceDisplayName,
  });

  final String productionOrderCode;
  final String? operationLabel;
  final int operationSequence;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final String resourceDisplayName;

  int get durationMinutes {
    final m = plannedEnd.difference(plannedStart).inMinutes;
    return m < 0 ? 0 : m;
  }
}
