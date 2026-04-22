import 'package:flutter/foundation.dart';

/// Korak rute iz [routing_steps] (kanonska polja + opcionalno [machineId] u dokumentu).
@immutable
class PlanningRoutingStep {
  const PlanningRoutingStep({
    required this.id,
    required this.routingId,
    required this.stepOrder,
    this.operationCode = '',
    this.operationName = '',
    this.setupTimeMinutes,
    this.standardTimeMinutesPerUnit,
    this.machineId,
  });

  final String id;
  final String routingId;
  final int stepOrder;
  final String operationCode;
  final String operationName;
  final double? setupTimeMinutes;
  /// Standardno vrijeme po jedinici u **minutama** (MVP interpretacija s polja [standardTimeMinutes]).
  final double? standardTimeMinutesPerUnit;
  final String? machineId;

  String get displayLabel =>
      operationCode.isNotEmpty ? operationCode : (operationName.isNotEmpty ? operationName : 'Korak $stepOrder');

  static PlanningRoutingStep fromMap(String id, Map<String, dynamic> m) {
    int order = 0;
    final so = m['stepOrder'];
    if (so is num) order = so.round();
    if (so is int) order = so;

    double? setup;
    final su = m['setupTimeMinutes'];
    if (su is num) setup = su.toDouble();

    double? std;
    final st = m['standardTimeMinutes'];
    if (st is num) std = st.toDouble();

    String? mid;
    final midRaw = m['machineId'];
    if (midRaw is String && midRaw.trim().isNotEmpty) {
      mid = midRaw.trim();
    }

    return PlanningRoutingStep(
      id: id,
      routingId: (m['routingId'] as String?)?.trim() ?? '',
      stepOrder: order,
      operationCode: (m['operationCode'] as String?)?.trim() ?? '',
      operationName: (m['operationName'] as String?)?.trim() ?? '',
      setupTimeMinutes: setup,
      standardTimeMinutesPerUnit: std,
      machineId: mid,
    );
  }

}
