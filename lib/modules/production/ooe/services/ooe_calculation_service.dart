import '../models/machine_state_event.dart';
import '../models/ooe_loss_reason.dart';

/// Deterministički OOE iz raw događaja i kataloga razloga (parametri su eksplicitni).
class OoeCalculationService {
  OoeCalculationService._();

  /// Zadano operativno vrijeme smjene ako firma još nema pravilo u UI (npr. 8 h).
  static const int defaultOperatingTimeSeconds = 28800;

  static OoeCalculationResult compute({
    required int operatingTimeSeconds,
    required List<MachineStateEvent> stateEvents,
    required Map<String, OoeLossReason> reasonByCode,
    required double totalCount,
    required double goodCount,
    required double scrapCount,
    required double reworkCount,
    double? idealCycleTimeSeconds,
  }) {
    final op = operatingTimeSeconds <= 0 ? 1 : operatingTimeSeconds;

    var plannedStop = 0;
    var unplannedStop = 0;
    var setup = 0;
    var materialWait = 0;
    var operatorWait = 0;
    var maintenance = 0;
    var qualityHold = 0;
    var microStop = 0;
    final lossByReason = <String, int>{};

    var availabilityLossSeconds = 0;

    for (final e in stateEvents) {
      final dur = e.durationSeconds ?? 0;
      if (dur <= 0 || e.endedAt == null) continue;

      final reason = e.reasonCode != null && e.reasonCode!.trim().isNotEmpty
          ? reasonByCode[e.reasonCode!.trim()]
          : null;

      final bucket = _bucketFor(
        state: e.state,
        reason: reason,
        reasonCategory: e.reasonCategory,
      );
      _applyBucket(
        bucket,
        dur,
        (b, v) {
          switch (b) {
            case _Bucket.plannedStop:
              plannedStop += v;
              break;
            case _Bucket.unplannedStop:
              unplannedStop += v;
              break;
            case _Bucket.setup:
              setup += v;
              break;
            case _Bucket.materialWait:
              materialWait += v;
              break;
            case _Bucket.operatorWait:
              operatorWait += v;
              break;
            case _Bucket.maintenance:
              maintenance += v;
              break;
            case _Bucket.qualityHold:
              qualityHold += v;
              break;
            case _Bucket.microStop:
              microStop += v;
              break;
            case _Bucket.ignore:
              break;
          }
        },
      );

      final affectsA = reason != null
          ? reason.affectsAvailability
          : _defaultAvailabilityLossFromState(e.state);

      if (affectsA) {
        availabilityLossSeconds += dur;
        final key = (e.reasonCode ?? e.state).trim();
        if (key.isNotEmpty) {
          lossByReason[key] = (lossByReason[key] ?? 0) + dur;
        }
      }
    }

    final runTimeSeconds =
        (op - availabilityLossSeconds).clamp(0, op).toInt();

    final stopTimeSeconds = (plannedStop +
            unplannedStop +
            setup +
            materialWait +
            operatorWait +
            maintenance +
            qualityHold +
            microStop)
        .clamp(0, op * 2);

    final availability = runTimeSeconds / op;

    double performance = 0;
    final ict = idealCycleTimeSeconds;
    if (runTimeSeconds > 0 && ict != null && ict > 0) {
      performance = (ict * totalCount) / runTimeSeconds;
    }

    final qualityMetric = totalCount <= 0 ? 0.0 : goodCount / totalCount;

    double clamp01(double x) => x.clamp(0.0, 1.0);

    final ooe = clamp01(availability) * clamp01(performance) * clamp01(qualityMetric);

    final topLosses = lossByReason.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return OoeCalculationResult(
      operatingTimeSeconds: operatingTimeSeconds,
      runTimeSeconds: runTimeSeconds,
      stopTimeSeconds: stopTimeSeconds,
      plannedStopSeconds: plannedStop,
      unplannedStopSeconds: unplannedStop,
      setupSeconds: setup,
      materialWaitSeconds: materialWait,
      operatorWaitSeconds: operatorWait,
      maintenanceSeconds: maintenance,
      qualityHoldSeconds: qualityHold,
      microStopSeconds: microStop,
      totalCount: totalCount,
      goodCount: goodCount,
      scrapCount: scrapCount,
      reworkCount: reworkCount,
      idealCycleTimeSeconds: idealCycleTimeSeconds,
      actualCycleTimeSeconds: totalCount > 0 && runTimeSeconds > 0
          ? runTimeSeconds / totalCount
          : null,
      availability: clamp01(availability),
      performance: clamp01(performance),
      quality: clamp01(qualityMetric),
      ooe: clamp01(ooe),
      topLosses: topLosses
          .take(8)
          .map(
            (e) => {
              'reasonKey': e.key,
              'seconds': e.value,
            },
          )
          .toList(),
    );
  }

  static bool _defaultAvailabilityLossFromState(String state) {
    switch (state) {
      case MachineStateEvent.stateRunning:
        return false;
      case MachineStateEvent.statePlannedBreak:
        return false;
      case MachineStateEvent.stateIdle:
        return false;
      default:
        return true;
    }
  }

  static _Bucket _bucketFor({
    required String state,
    OoeLossReason? reason,
    String? reasonCategory,
  }) {
    if (reason != null) {
      switch (reason.category) {
        case OoeLossReason.categoryPlannedStop:
          return _Bucket.plannedStop;
        case OoeLossReason.categoryUnplannedStop:
          return _Bucket.unplannedStop;
        case OoeLossReason.categorySetupChangeover:
          return _Bucket.setup;
        case OoeLossReason.categoryMaterialWait:
          return _Bucket.materialWait;
        case OoeLossReason.categoryOperatorWait:
          return _Bucket.operatorWait;
        case OoeLossReason.categoryMaintenance:
          return _Bucket.maintenance;
        case OoeLossReason.categoryQualityHold:
          return _Bucket.qualityHold;
        case OoeLossReason.categoryMicroStop:
          return _Bucket.microStop;
        case OoeLossReason.categoryReducedSpeed:
          return _Bucket.microStop;
        default:
          break;
      }
    }
    final c = (reasonCategory ?? '').trim().toLowerCase();
    if (c.isNotEmpty) {
      if (c.contains('planned')) return _Bucket.plannedStop;
      if (c.contains('micro')) return _Bucket.microStop;
    }

    switch (state) {
      case MachineStateEvent.stateSetup:
        return _Bucket.setup;
      case MachineStateEvent.stateWaitingMaterial:
        return _Bucket.materialWait;
      case MachineStateEvent.stateWaitingOperator:
        return _Bucket.operatorWait;
      case MachineStateEvent.stateMaintenance:
        return _Bucket.maintenance;
      case MachineStateEvent.stateQualityHold:
        return _Bucket.qualityHold;
      case MachineStateEvent.statePlannedBreak:
        return _Bucket.plannedStop;
      case MachineStateEvent.stateRunning:
      case MachineStateEvent.stateIdle:
        return _Bucket.ignore;
      default:
        return _Bucket.unplannedStop;
    }
  }

  static void _applyBucket(
    _Bucket b,
    int dur,
    void Function(_Bucket bucket, int v) emit,
  ) {
    emit(b, dur);
  }
}

enum _Bucket {
  plannedStop,
  unplannedStop,
  setup,
  materialWait,
  operatorWait,
  maintenance,
  qualityHold,
  microStop,
  ignore,
}

class OoeCalculationResult {
  final int operatingTimeSeconds;
  final int runTimeSeconds;
  final int stopTimeSeconds;

  final int plannedStopSeconds;
  final int unplannedStopSeconds;
  final int setupSeconds;
  final int materialWaitSeconds;
  final int operatorWaitSeconds;
  final int maintenanceSeconds;
  final int qualityHoldSeconds;
  final int microStopSeconds;

  final double totalCount;
  final double goodCount;
  final double scrapCount;
  final double reworkCount;

  final double? idealCycleTimeSeconds;
  final double? actualCycleTimeSeconds;

  final double availability;
  final double performance;
  final double quality;
  final double ooe;

  final List<Map<String, dynamic>> topLosses;

  OoeCalculationResult({
    required this.operatingTimeSeconds,
    required this.runTimeSeconds,
    required this.stopTimeSeconds,
    required this.plannedStopSeconds,
    required this.unplannedStopSeconds,
    required this.setupSeconds,
    required this.materialWaitSeconds,
    required this.operatorWaitSeconds,
    required this.maintenanceSeconds,
    required this.qualityHoldSeconds,
    required this.microStopSeconds,
    required this.totalCount,
    required this.goodCount,
    required this.scrapCount,
    required this.reworkCount,
    this.idealCycleTimeSeconds,
    this.actualCycleTimeSeconds,
    required this.availability,
    required this.performance,
    required this.quality,
    required this.ooe,
    required this.topLosses,
  });
}
