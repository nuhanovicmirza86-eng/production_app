import '../models/aps_capacity_warning_view.dart';
import '../models/aps_demand_view.dart';
import '../models/aps_objective_profile_view.dart';
import '../models/aps_scenario_item_view.dart';
import '../models/aps_scenario_view.dart';

/// Kanonski poslovni cilj optimizacije (P5.4) — UI label, ne Firestore `profileName`.
enum ApsOptimizationGoalKind {
  balanced,
  minLate,
  maxUtilization,
  minMakespan,
  minChanges,
}

/// Predloženi cilj + razlog (poslovno pravilo, ne AI).
class ApsOptimizationGoalSuggestion {
  const ApsOptimizationGoalSuggestion({
    required this.kind,
    required this.reason,
  });

  final ApsOptimizationGoalKind kind;
  final String reason;
}

/// Mapiranje poslovnog cilja ↔ `objectiveProfileId` (P5.4).
abstract final class ApsOptimizationGoalCatalog {
  static const allKinds = <ApsOptimizationGoalKind>[
    ApsOptimizationGoalKind.balanced,
    ApsOptimizationGoalKind.minLate,
    ApsOptimizationGoalKind.maxUtilization,
    ApsOptimizationGoalKind.minMakespan,
    ApsOptimizationGoalKind.minChanges,
  ];

  static String label(ApsOptimizationGoalKind kind) {
    switch (kind) {
      case ApsOptimizationGoalKind.balanced:
        return 'Balansiran plan';
      case ApsOptimizationGoalKind.minLate:
        return 'Najkraće kašnjenje';
      case ApsOptimizationGoalKind.maxUtilization:
        return 'Najbolja iskorištenost resursa';
      case ApsOptimizationGoalKind.minMakespan:
        return 'Najkraće ukupno trajanje';
      case ApsOptimizationGoalKind.minChanges:
        return 'Najmanje promjena u rasporedu';
    }
  }

  static String infoBody(ApsOptimizationGoalKind kind) {
    switch (kind) {
      case ApsOptimizationGoalKind.balanced:
        return 'Uravnotežen izbor između rokova, iskorištenosti resursa i stabilnosti '
            'rasporeda. Prikladan kao siguran početni cilj.';
      case ApsOptimizationGoalKind.minLate:
        return 'Prioritet je smanjiti kašnjenja potražnji u odnosu na rokove. '
            'Koristite kad postoje rizici od kašnjenja.';
      case ApsOptimizationGoalKind.maxUtilization:
        return 'Prioritet je bolje iskoristiti raspoloživo vrijeme resursa. '
            'Koristite kad je kapacitet pod pritiskom.';
      case ApsOptimizationGoalKind.minMakespan:
        return 'Prioritet je skratiti ukupno trajanje plana (makespan). '
            'Koristite kad želite brži završetak cijelog scenarija.';
      case ApsOptimizationGoalKind.minChanges:
        return 'Prioritet je zadržati postojeći raspored uz minimalne pomake. '
            'Koristite kad je plan već pregledan ili potvrđen.';
    }
  }

  static const generalInfoBody =
      'Cilj optimizacije govori sistemu šta je važnije pri izradi boljeg prijedloga '
      'rasporeda: manje kašnjenja, bolja iskorištenost resursa, kraće trajanje ili '
      'manje promjena. Vi birate poslovni cilj; sistem ga mapira na profil u pozadini.';

  /// Operativni prikaz — nikad sirovi P0 `profileName` ako se može mapirati.
  static String labelForProfile(
    ApsObjectiveProfileView profile, {
    String? objectiveProfileId,
  }) {
    final kind = kindForProfile(profile, objectiveProfileId: objectiveProfileId);
    if (kind != null) return label(kind);
    return label(ApsOptimizationGoalKind.balanced);
  }

  static String labelForProfileId(
    String? objectiveProfileId,
    List<ApsObjectiveProfileView> profiles,
  ) {
    final id = objectiveProfileId?.trim() ?? '';
    if (id.isEmpty) return '';
    for (final p in profiles) {
      if (p.id == id) return labelForProfile(p, objectiveProfileId: id);
    }
    return '';
  }

  static ApsOptimizationGoalKind? kindForProfile(
    ApsObjectiveProfileView profile, {
    String? objectiveProfileId,
  }) {
    final fromObjectives = _kindFromObjectives(profile.objectives);
    if (fromObjectives != null) return fromObjectives;

    final name = profile.profileName.toLowerCase();
    for (final kind in allKinds) {
      if (_nameMatchesKind(name, kind)) return kind;
    }
    return null;
  }

  static ApsObjectiveProfileView? profileForKind(
    ApsOptimizationGoalKind kind,
    List<ApsObjectiveProfileView> profiles,
  ) {
    if (profiles.isEmpty) return null;

    ApsObjectiveProfileView? objectivesMatch;
    ApsObjectiveProfileView? nameMatch;
    for (final p in profiles) {
      if (!p.isActive) continue;
      if (_kindFromObjectives(p.objectives) == kind) {
        objectivesMatch ??= p;
      }
      if (_nameMatchesKind(p.profileName.toLowerCase(), kind)) {
        nameMatch ??= p;
      }
    }
    return objectivesMatch ?? nameMatch ?? _fallbackForKind(kind, profiles);
  }

  static String? profileIdForKind(
    ApsOptimizationGoalKind kind,
    List<ApsObjectiveProfileView> profiles,
  ) {
    return profileForKind(kind, profiles)?.id;
  }

  static ApsOptimizationGoalKind? kindForProfileId(
    String? objectiveProfileId,
    List<ApsObjectiveProfileView> profiles,
  ) {
    final id = objectiveProfileId?.trim() ?? '';
    if (id.isEmpty) return null;
    for (final p in profiles) {
      if (p.id == id) return kindForProfile(p, objectiveProfileId: id);
    }
    return null;
  }

  /// Poslovna pravila (nije AI) — predloženi cilj za scenarij.
  static ApsOptimizationGoalSuggestion suggest({
    required ApsScenarioView scenario,
    required List<ApsDemandView> demands,
    required List<ApsScenarioItemView> scenarioItems,
    List<ApsCapacityWarningView> capacityWarnings = const [],
  }) {
    final status = scenario.status.trim().toLowerCase();
    if (status == 'approved' || status == 'review_required') {
      return const ApsOptimizationGoalSuggestion(
        kind: ApsOptimizationGoalKind.minChanges,
        reason:
            'Plan je već pregledan ili potvrđen — preporučujemo što manje promjena u rasporedu.',
      );
    }

    if (_hasDelayRisk(scenario, scenarioItems, demands, capacityWarnings)) {
      return const ApsOptimizationGoalSuggestion(
        kind: ApsOptimizationGoalKind.minLate,
        reason:
            'Postoje potražnje s rokom izvan perioda ili upozorenja o kašnjenju — '
            'prioritet je smanjiti kašnjenja.',
      );
    }

    if (_hasCapacityPressure(capacityWarnings)) {
      return const ApsOptimizationGoalSuggestion(
        kind: ApsOptimizationGoalKind.maxUtilization,
        reason:
            'Kapacitet resursa je pod pritiskom — preporučujemo bolju iskorištenost resursa.',
      );
    }

    return const ApsOptimizationGoalSuggestion(
      kind: ApsOptimizationGoalKind.balanced,
      reason: 'Siguran početni izbor za standardno planiranje bez posebnih problema.',
    );
  }

  static bool _hasDelayRisk(
    ApsScenarioView scenario,
    List<ApsScenarioItemView> items,
    List<ApsDemandView> demands,
    List<ApsCapacityWarningView> warnings,
  ) {
    for (final w in warnings) {
      final code = w.warningCode.trim().toLowerCase();
      if (code == 'demand_due_outside_period') return true;
    }

    final end = scenario.periodEnd;
    if (end == null || items.isEmpty) return false;

    final demandById = {for (final d in demands) d.id: d};
    for (final item in items) {
      final demand = demandById[item.demandId];
      final due = demand?.dueDate;
      if (due != null && due.isAfter(end)) return true;
    }
    return false;
  }

  static bool _hasCapacityPressure(List<ApsCapacityWarningView> warnings) {
    for (final w in warnings) {
      final code = w.warningCode.trim().toLowerCase();
      if (code == 'insufficient_capacity') return true;
      if (w.isCritical) return true;
    }
    return false;
  }

  static ApsOptimizationGoalKind? _kindFromObjectives(
    Map<String, String> objectives,
  ) {
    if (objectives.isEmpty) return null;

    String weight(String key) => (objectives[key] ?? '').trim().toLowerCase();
    bool isHigh(String key) => weight(key) == 'high';

    if (isHigh('minimizeLateOrders') || isHigh('deliveryDueDateWeight')) {
      return ApsOptimizationGoalKind.minLate;
    }
    if (isHigh('maximizeResourceUtilization')) {
      return ApsOptimizationGoalKind.maxUtilization;
    }
    if (isHigh('minimizeMakespan')) {
      return ApsOptimizationGoalKind.minMakespan;
    }
    if (isHigh('minimizeSetupChanges') || isHigh('setupOptimizationWeight')) {
      return ApsOptimizationGoalKind.minChanges;
    }

    final highs = objectives.values.where((v) => v.toLowerCase() == 'high').length;
    if (highs <= 1) return ApsOptimizationGoalKind.balanced;
    return null;
  }

  static bool _nameMatchesKind(String lowerName, ApsOptimizationGoalKind kind) {
    final hints = switch (kind) {
      ApsOptimizationGoalKind.balanced => ['balans', 'balanced', 'default'],
      ApsOptimizationGoalKind.minLate => [
        'kašnjen',
        'kasnjen',
        'late',
        'rok',
        'due',
      ],
      ApsOptimizationGoalKind.maxUtilization => [
        'iskorišten',
        'iskoristen',
        'utiliz',
        'zauzet',
        'kapacitet',
      ],
      ApsOptimizationGoalKind.minMakespan => [
        'trajanje',
        'makespan',
        'ukupno',
        'krać',
        'krac',
      ],
      ApsOptimizationGoalKind.minChanges => [
        'promjen',
        'setup',
        'stabil',
        'minimal',
        'change',
      ],
    };
    return hints.any(lowerName.contains);
  }

  static ApsObjectiveProfileView? _fallbackForKind(
    ApsOptimizationGoalKind kind,
    List<ApsObjectiveProfileView> profiles,
  ) {
    if (kind == ApsOptimizationGoalKind.balanced) {
      return ApsObjectiveProfileView.pickBalancedDefault(profiles);
    }
    final active = profiles.where((p) => p.isActive).toList();
    if (active.isNotEmpty) return active.first;
    return profiles.isNotEmpty ? profiles.first : null;
  }
}
