import 'ooe_loss_reason.dart';

/// TPM / OEE „šest velikih gubitaka“ (OEE best practice) — **stabilni string ključevi** u
/// Firestoreu (`tpmLossKey` na katalogu razloga i na `machine_state_events`).
///
/// Riješava enterprise sloj: Pareto i trendovi po **loss klasi**, ne samo po operativnim
/// kategorijama ([OoeLossReason.category]).
class MesTpmLossKeys {
  MesTpmLossKeys._();

  static const String breakdown = 'tpm_breakdown';
  static const String setupAndAdjustments = 'tpm_setup_adjustments';
  static const String idlingAndMinorStops = 'tpm_idling_minor_stops';
  static const String reducedSpeed = 'tpm_reduced_speed';
  static const String processDefects = 'tpm_process_defects';
  static const String reducedYieldStartup = 'tpm_reduced_yield_startup';
  static const String unclassified = 'tpm_unclassified';

  static const List<String> ordered = <String>[
    breakdown,
    setupAndAdjustments,
    idlingAndMinorStops,
    reducedSpeed,
    processDefects,
    reducedYieldStartup,
  ];

  /// [reasonKey] → ljudski naziv (za Pareto widget).
  static Map<String, String> reasonKeyLabelMapHr() {
    final m = <String, String>{for (final k in ordered) k: labelHr(k)};
    m[unclassified] = labelHr(unclassified);
    return m;
  }

  static bool isKnown(String? key) {
    final k = (key ?? '').trim();
    if (k.isEmpty) return false;
    if (k == unclassified) return true;
    return ordered.contains(k);
  }

  /// Kratak HR naziv za UI (wallboard, katalog, Pareto po TPM).
  static String labelHr(String? key) {
    switch ((key ?? '').trim()) {
      case breakdown:
        return 'Kvar / breakdown';
      case setupAndAdjustments:
        return 'Priprema i podešavanje';
      case idlingAndMinorStops:
        return 'Mirovanje i kratki zastoji';
      case reducedSpeed:
        return 'Smanjena brzina';
      case processDefects:
        return 'Procesni defekti';
      case reducedYieldStartup:
        return 'Start / smanjen prinos';
      case unclassified:
        return 'Neklasificirano';
      default:
        return key?.trim().isNotEmpty == true ? key!.trim() : '—';
    }
  }

  /// Heuristika: kad u starim dokumentima nema [OoeLossReason.tpmLossKey], mapiraj iz
  /// postojećeg [OoeLossReason.category] (MVP kategorije).
  static String guessFromOoeCategory(String category) {
    switch (category) {
      case OoeLossReason.categoryMaintenance:
        return breakdown;
      case OoeLossReason.categorySetupChangeover:
        return setupAndAdjustments;
      case OoeLossReason.categoryReducedSpeed:
        return reducedSpeed;
      case OoeLossReason.categoryQualityHold:
        return processDefects;
      case OoeLossReason.categoryPlannedStop:
      case OoeLossReason.categoryUnplannedStop:
      case OoeLossReason.categoryMaterialWait:
      case OoeLossReason.categoryOperatorWait:
      case OoeLossReason.categoryMicroStop:
        return idlingAndMinorStops;
      case OoeLossReason.categoryOther:
      default:
        return unclassified;
    }
  }
}

extension OoeLossReasonTpm on OoeLossReason {
  /// Efektivni TPM klaster: eksplicitno polje ili heuristika s [OoeLossReason.category].
  String get effectiveTpmLossKey {
    final k = tpmLossKey?.trim() ?? '';
    if (k == MesTpmLossKeys.unclassified) {
      return MesTpmLossKeys.guessFromOoeCategory(category);
    }
    if (k.isNotEmpty) return k;
    return MesTpmLossKeys.guessFromOoeCategory(category);
  }
}
