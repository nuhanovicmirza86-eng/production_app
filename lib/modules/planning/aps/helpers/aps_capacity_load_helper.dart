/// Razina opterećenja kapaciteta za UI oznake.
enum ApsCapacityLoadLevel {
  ok,
  warning,
  bottleneck,
}

/// Pomoćnik za oznake OK / Upozorenje / Usko grlo.
abstract final class ApsCapacityLoadHelper {
  static const okLabel = 'OK';
  static const warningLabel = 'Upozorenje';
  static const bottleneckLabel = 'Usko grlo';

  static String label(ApsCapacityLoadLevel level) {
    switch (level) {
      case ApsCapacityLoadLevel.ok:
        return okLabel;
      case ApsCapacityLoadLevel.warning:
        return warningLabel;
      case ApsCapacityLoadLevel.bottleneck:
        return bottleneckLabel;
    }
  }

  static ApsCapacityLoadLevel scenarioLevel({
    required num utilizationPercent,
    required bool hasCriticalWarnings,
    required int warningCount,
  }) {
    if (hasCriticalWarnings || utilizationPercent > 100) {
      return ApsCapacityLoadLevel.bottleneck;
    }
    if (warningCount > 0 || utilizationPercent > 85) {
      return ApsCapacityLoadLevel.warning;
    }
    return ApsCapacityLoadLevel.ok;
  }

  static ApsCapacityLoadLevel resourceLevel({
    required num availableMinutes,
    required num allocatedMinutes,
    required bool hasCriticalWarning,
    required bool hasWarning,
  }) {
    if (hasCriticalWarning) return ApsCapacityLoadLevel.bottleneck;
    if (availableMinutes <= 0) {
      return allocatedMinutes > 0
          ? ApsCapacityLoadLevel.bottleneck
          : ApsCapacityLoadLevel.warning;
    }
    final util = (allocatedMinutes / availableMinutes) * 100;
    if (util > 100) return ApsCapacityLoadLevel.bottleneck;
    if (hasWarning || util >= 85) return ApsCapacityLoadLevel.warning;
    return ApsCapacityLoadLevel.ok;
  }
}
