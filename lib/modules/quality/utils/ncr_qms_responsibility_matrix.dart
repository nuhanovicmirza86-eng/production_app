import '../../../core/access/production_access_helper.dart';

/// Kontrolisana odgovorna uloga / kategorija za dodjelu (dropdown).
///
/// Izvor: [NcrQmsResponsibilityMatrix] — **ne** „Vidljivo operaterima“.
class NcrDispositionRoleOption {
  const NcrDispositionRoleOption({
    required this.id,
    required this.labelBs,
    required this.matchRoles,
  });

  /// Stabilni ključ opcije (nije Firebase UID).
  final String id;

  /// Poslovni naziv za UI (nikad tehnički `users.role` string).
  final String labelBs;

  /// Kanonski `users.role` vrijednosti koje spadaju pod ovu opciju.
  final List<String> matchRoles;
}

/// Faza dodjele (M1-I12-B dvofazni model za doradu).
enum NcrDispositionFlowPhase {
  /// Kontrola kvaliteta pokreće „Potrebna dorada” → vlasnik = menadžer proizvodnje.
  initiateReworkOwner,

  /// Menadžer proizvodnje dodjeljuje izvršioca + proizvodni rok.
  assignReworkExecutor,

  /// Jednofazne akcije (ponovna kontrola, zaustavljanje).
  singleStep,
}

/// M1-I12-B — matrica odgovornosti za akcije neusaglašenosti.
///
/// **Zaključano:**
/// - „Vidljivo operaterima” ≠ odgovornost za akciju.
/// - Za doradu: kvaliteta **pokreće**; menadžer proizvodnje je **vlasnik** i
///   zatim dodjeljuje **izvršioca** + rok.
abstract final class NcrQmsResponsibilityMatrix {
  static NcrDispositionRoleOption roleOption(
    String canonicalRole, {
    String? labelOverrideBs,
  }) {
    final r = ProductionAccessHelper.normalizeRole(canonicalRole);
    return NcrDispositionRoleOption(
      id: r,
      labelBs: (labelOverrideBs ?? '').trim().isNotEmpty
          ? labelOverrideBs!.trim()
          : ProductionAccessHelper.displayRoleLabel(r),
      matchRoles: [r],
    );
  }

  /// Vlasnik akcije „Potrebna dorada” — uvijek menadžer proizvodnje.
  static List<NcrDispositionRoleOption> reworkOwnerRoles() => [
        roleOption(ProductionAccessHelper.roleProductionManager),
      ];

  /// Izvršioci koje menadžer proizvodnje može dodijeliti.
  /// Samo uloge iz stvarnog role modela projekta (bez izmišljenih labela).
  static List<NcrDispositionRoleOption> reworkExecutorRoles() => [
        roleOption(ProductionAccessHelper.roleProductionOperator),
        roleOption(ProductionAccessHelper.roleShiftLead),
      ];

  static List<NcrDispositionRoleOption> rolesForActionKey(String actionKey) {
    switch ((actionKey).trim().toLowerCase()) {
      case 'send_to_rework':
        return reworkOwnerRoles();
      case 'schedule_recheck':
        return [
          roleOption(ProductionAccessHelper.roleQualityControl),
          roleOption(ProductionAccessHelper.roleQualityOperator),
        ];
      case 'stop_production':
        return [
          roleOption(ProductionAccessHelper.roleProductionManager),
          roleOption(ProductionAccessHelper.roleShiftLead),
        ];
      default:
        return const [];
    }
  }

  static List<String> allMatchRolesForActionKey(String actionKey) {
    final out = <String>{};
    for (final opt in rolesForActionKey(actionKey)) {
      out.addAll(opt.matchRoles);
    }
    return out.toList(growable: false);
  }

  static List<String> allMatchRolesForOptions(
    List<NcrDispositionRoleOption> options,
  ) {
    final out = <String>{};
    for (final opt in options) {
      out.addAll(opt.matchRoles);
    }
    return out.toList(growable: false);
  }

  static const reworkOwnerTaskBs =
      'Organizovati doradu komada i dodijeliti izvršioca.';

  static const reworkExecutorTaskBs =
      'Izvršiti doradu komada i vratiti ih na ponovnu kontrolu kvaliteta.';

  /// Odredi fazu dijaloga prema postojećim podacima neusaglašenosti.
  static NcrDispositionFlowPhase resolveFlowPhase({
    required String actionKey,
    required String? existingActionKey,
    required String? existingOwner,
    required String? existingExecutor,
  }) {
    final key = actionKey.trim().toLowerCase();
    if (key != 'send_to_rework') {
      return NcrDispositionFlowPhase.singleStep;
    }
    final existing = (existingActionKey ?? '').trim().toLowerCase();
    final owner = (existingOwner ?? '').trim();
    final executor = (existingExecutor ?? '').trim();
    if (existing == 'send_to_rework' && owner.isNotEmpty && executor.isEmpty) {
      return NcrDispositionFlowPhase.assignReworkExecutor;
    }
    if (existing == 'send_to_rework' && owner.isNotEmpty && executor.isNotEmpty) {
      // Ponovna dodjela izvršioca.
      return NcrDispositionFlowPhase.assignReworkExecutor;
    }
    return NcrDispositionFlowPhase.initiateReworkOwner;
  }

  static String phaseLabelBs(String? phaseKey) {
    switch ((phaseKey ?? '').trim().toLowerCase()) {
      case 'awaiting_executor':
        return 'Čeka dodjelu izvršioca';
      case 'executor_assigned':
        return 'Izvršilac dodijeljen';
      case 'assigned':
        return 'Dodijeljeno';
      default:
        return '';
    }
  }
}
