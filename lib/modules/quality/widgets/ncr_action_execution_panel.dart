import 'package:flutter/material.dart';

import 'ncr_action_hodogram_model.dart';
import 'qms_iatf_help.dart';

/// M1-I12-D — koji korak izvršenja je sada na redu.
enum NcrExecutionStep {
  awaitingExecutor,
  executorAssigned,
  reworkDone,
  awaitingRecheck,
  recheckOk,
  recheckNok,
  stopPending,
  stopped,
  stopReleased,
  closed,
  none,
}

/// Primarna radnja koju panel nudi (uvijek najviše jedna).
enum NcrExecutionPrimaryAction {
  assignExecutor,
  confirmRework,
  runRecheck,
  closeNcr,
  newDecision,
  recordStop,
  releaseStop,
  none,
}

/// Sadržaj akcionog panela: gdje smo, šta se sada radi, ko i do kada.
class NcrExecutionPanelState {
  const NcrExecutionPanelState({
    required this.step,
    required this.currentStepBs,
    required this.whatToDoBs,
    required this.responsibleBs,
    required this.dueBs,
    required this.nextActionBs,
    required this.primaryAction,
    required this.primaryActionLabelBs,
    required this.userMayAct,
    required this.waitingForBs,
  });

  final NcrExecutionStep step;
  final String currentStepBs;
  final String whatToDoBs;
  final String responsibleBs;
  final String? dueBs;
  final String nextActionBs;
  final NcrExecutionPrimaryAction primaryAction;
  final String primaryActionLabelBs;

  /// Da li prijavljeni korisnik smije izvršiti primarnu radnju.
  final bool userMayAct;

  /// Ako ne smije: koga se čeka (poslovni tekst, bez raw ID-a).
  final String waitingForBs;
}

/// Logika stanja izvršenja — čita samo postojeća polja neusaglašenosti.
class NcrExecutionLogic {
  const NcrExecutionLogic._();

  static const _qualityRecheckRoles = <String>{
    'quality_control',
    'quality_operator',
  };
  static const _managerRoles = <String>{
    'super_admin',
    'admin',
    'production_manager',
  };

  static String _s(Object? v) => (v ?? '').toString().trim();

  static NcrExecutionStep stepOf(Map<String, dynamic>? ncr) {
    switch (_s(ncr?['executionStatus'])) {
      case 'awaiting_executor':
        return NcrExecutionStep.awaitingExecutor;
      case 'executor_assigned':
        return NcrExecutionStep.executorAssigned;
      case 'rework_done':
        return NcrExecutionStep.reworkDone;
      case 'awaiting_recheck':
        return NcrExecutionStep.awaitingRecheck;
      case 'recheck_ok':
        return NcrExecutionStep.recheckOk;
      case 'recheck_nok':
        return NcrExecutionStep.recheckNok;
      case 'stop_pending':
        return NcrExecutionStep.stopPending;
      case 'stopped':
        return NcrExecutionStep.stopped;
      case 'stop_released':
        return NcrExecutionStep.stopReleased;
      case 'closed':
        return NcrExecutionStep.closed;
      default:
        return NcrExecutionStep.none;
    }
  }

  static bool _isNcrClosed(Map<String, dynamic>? ncr) {
    return NcrActionHodogramLogic.isNcrClosed(_s(ncr?['status']));
  }

  /// Sastavlja panel za trenutno stanje; `null` ako akcija nije ni pokrenuta.
  static NcrExecutionPanelState? resolve({
    required Map<String, dynamic>? ncr,
    required String currentUid,
    required String normalizedRole,
  }) {
    if (_isNcrClosed(ncr)) {
      return const NcrExecutionPanelState(
        step: NcrExecutionStep.closed,
        currentStepBs: 'Neusaglašenost je zatvorena.',
        whatToDoBs: 'Tok je zatvoren. Nisu potrebne dodatne akcije.',
        responsibleBs: '—',
        dueBs: null,
        nextActionBs: 'Tok je zatvoren.',
        primaryAction: NcrExecutionPrimaryAction.none,
        primaryActionLabelBs: '',
        userMayAct: false,
        waitingForBs: 'Tok je zatvoren. Nisu potrebne dodatne akcije.',
      );
    }

    final step = stepOf(ncr);
    if (step == NcrExecutionStep.none) return null;

    final owner = _s(ncr?['nextDispositionOwner']);
    final ownerRole = _s(ncr?['nextDispositionRoleLabel']);
    final executor = _s(ncr?['nextDispositionExecutor']);
    final executorRole = _s(ncr?['nextDispositionExecutorRoleLabel']);
    final executorUserKey = _s(ncr?['nextDispositionExecutorUserKey']);
    final dueRaw = _s(ncr?['nextDispositionDueAt']);
    final dueBs =
        dueRaw.isEmpty ? null : NcrActionHodogramLogic.formatDueBs(dueRaw);

    final isManager = _managerRoles.contains(normalizedRole);
    final isQualityRecheck = _qualityRecheckRoles.contains(normalizedRole);
    final isAssignedExecutor =
        executorUserKey.isNotEmpty && executorUserKey == currentUid;

    String person(String name, String role) {
      if (name.isEmpty) return role.isEmpty ? 'Nije određeno' : role;
      return role.isEmpty ? name : '$name — $role';
    }

    switch (step) {
      case NcrExecutionStep.awaitingExecutor:
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: 'Dorada je pokrenuta.',
          whatToDoBs: 'Menadžer proizvodnje treba odrediti izvršioca dorade '
              'i proizvodni rok.',
          responsibleBs: person(owner, ownerRole.isEmpty
              ? 'Menadžer proizvodnje'
              : ownerRole),
          dueBs: null,
          nextActionBs: 'Dodijeli izvršioca dorade',
          primaryAction: NcrExecutionPrimaryAction.assignExecutor,
          primaryActionLabelBs: 'Dodijeli izvršioca dorade',
          userMayAct: isManager,
          waitingForBs: 'Čeka se menadžer proizvodnje.',
        );

      case NcrExecutionStep.executorAssigned:
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: 'Dorada je dodijeljena.',
          whatToDoBs:
              'Izvršilac dorade treba izvršiti doradu komada prema zadatku.',
          responsibleBs: person(executor, executorRole),
          dueBs: dueBs,
          nextActionBs: 'Potvrdi da je dorada urađena',
          primaryAction: NcrExecutionPrimaryAction.confirmRework,
          primaryActionLabelBs: 'Potvrdi završetak dorade',
          userMayAct: isAssignedExecutor,
          waitingForBs: executor.isEmpty
              ? 'Čeka se izvršilac dorade.'
              : 'Čeka se da $executor potvrdi završetak dorade.',
        );

      case NcrExecutionStep.reworkDone:
      case NcrExecutionStep.awaitingRecheck:
        final reworkDone = step == NcrExecutionStep.reworkDone;
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: reworkDone
              ? 'Dorada je izvršena.'
              : 'Dorada je izvršena — komadi čekaju ponovnu kontrolu.',
          whatToDoBs: 'Kontrola kvaliteta treba izvršiti ponovnu kontrolu '
              'komada i evidentirati ishod.',
          responsibleBs: 'Kontrola kvaliteta',
          dueBs: dueBs,
          nextActionBs: 'Evidentiraj ponovnu kontrolu',
          primaryAction: NcrExecutionPrimaryAction.runRecheck,
          primaryActionLabelBs: 'Izvrši ponovnu kontrolu',
          userMayAct: isQualityRecheck,
          waitingForBs: 'Čeka se kontrola kvaliteta.',
        );

      case NcrExecutionStep.recheckOk:
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: 'Ponovna kontrola je odobrena.',
          whatToDoBs: 'Kontrola kvaliteta može zatvoriti neusaglašenost '
              'uz obavezan prilog (foto ili dokument).',
          responsibleBs: 'Kontrola kvaliteta',
          dueBs: null,
          nextActionBs: 'Zatvori neusaglašenost',
          primaryAction: NcrExecutionPrimaryAction.closeNcr,
          primaryActionLabelBs: 'Zatvori neusaglašenost',
          userMayAct: isQualityRecheck,
          waitingForBs: 'Čeka se kontrola kvaliteta.',
        );

      case NcrExecutionStep.recheckNok:
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: 'Ponovna kontrola nije odobrena.',
          whatToDoBs: 'Za odbijene komade potrebna je nova odluka — nova '
              'dorada ili zaustavljanje proizvodnje. Neusaglašenost ostaje '
              'otvorena dok se to ne riješi.',
          responsibleBs: 'Kontrola kvaliteta',
          dueBs: null,
          nextActionBs: 'Donesi novu odluku',
          primaryAction: NcrExecutionPrimaryAction.newDecision,
          primaryActionLabelBs: 'Nova odluka',
          userMayAct: isQualityRecheck,
          waitingForBs: 'Čeka se kontrola kvaliteta.',
        );

      case NcrExecutionStep.stopPending:
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: 'Zaustavljanje proizvodnje je pokrenuto.',
          whatToDoBs: 'Menadžer proizvodnje treba evidentirati zaustavljanje: '
              'mašinu, razlog, odvojene komade i uslov za ponovno pokretanje.',
          responsibleBs: person(owner, ownerRole.isEmpty
              ? 'Menadžer proizvodnje'
              : ownerRole),
          dueBs: dueBs,
          nextActionBs: 'Evidentiraj zaustavljanje',
          primaryAction: NcrExecutionPrimaryAction.recordStop,
          primaryActionLabelBs: 'Evidentiraj zaustavljanje',
          userMayAct: isManager,
          waitingForBs: 'Čeka se menadžer proizvodnje.',
        );

      case NcrExecutionStep.stopped:
        final stop = ncr?['executionStop'];
        final approver =
            stop is Map ? _s(stop['releaseApproverName']) : '';
        final condition = stop is Map ? _s(stop['restartCondition']) : '';
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: 'Proizvodnja je zaustavljena.',
          whatToDoBs: condition.isEmpty
              ? 'Nastavak proizvodnje mora biti odobren.'
              : 'Uslov za nastavak: $condition',
          responsibleBs:
              approver.isEmpty ? 'Menadžer proizvodnje' : approver,
          dueBs: null,
          nextActionBs: 'Odobri nastavak proizvodnje',
          primaryAction: NcrExecutionPrimaryAction.releaseStop,
          primaryActionLabelBs: 'Odobri nastavak proizvodnje',
          userMayAct: isManager,
          waitingForBs: approver.isEmpty
              ? 'Čeka se odobrenje nastavka.'
              : 'Čeka se da $approver odobri nastavak.',
        );

      case NcrExecutionStep.stopReleased:
        return NcrExecutionPanelState(
          step: step,
          currentStepBs: 'Nastavak proizvodnje je odobren.',
          whatToDoBs: 'Kontrola kvaliteta zatvara neusaglašenost ili '
              'pokreće novu akciju ako problem nije riješen.',
          responsibleBs: 'Kontrola kvaliteta',
          dueBs: null,
          nextActionBs: 'Zatvori neusaglašenost',
          primaryAction: NcrExecutionPrimaryAction.closeNcr,
          primaryActionLabelBs: 'Zatvori neusaglašenost',
          userMayAct: isQualityRecheck,
          waitingForBs: 'Čeka se kontrola kvaliteta.',
        );

      case NcrExecutionStep.closed:
        return const NcrExecutionPanelState(
          step: NcrExecutionStep.closed,
          currentStepBs: 'Neusaglašenost je zatvorena.',
          whatToDoBs: 'Tok je zatvoren. Nisu potrebne dodatne akcije.',
          responsibleBs: '—',
          dueBs: null,
          nextActionBs: 'Tok je zatvoren.',
          primaryAction: NcrExecutionPrimaryAction.none,
          primaryActionLabelBs: '',
          userMayAct: false,
          waitingForBs: 'Tok je zatvoren. Nisu potrebne dodatne akcije.',
        );

      case NcrExecutionStep.none:
        return null;
    }
  }
}

/// Akcioni panel koraka „Sljedeća akcija” — vodi korisnika kroz izvršenje.
class NcrActionExecutionPanel extends StatelessWidget {
  const NcrActionExecutionPanel({
    super.key,
    required this.state,
    required this.busy,
    required this.onPrimaryAction,
  });

  final NcrExecutionPanelState state;
  final bool busy;
  final void Function(NcrExecutionPrimaryAction action) onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.primaryContainer.withValues(alpha: 0.30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Šta sada treba uraditi',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const QmsIatfInfoIcon(
                  title: 'Izvršenje akcije',
                  message:
                      'Dodjela akcije nije izvršenje akcije. Sistem vodi tok '
                      'korak po korak: dorada se potvrđuje kad je urađena, '
                      'zatim ide ponovna kontrola, pa zatvaranje '
                      'neusaglašenosti ili nova odluka.',
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _row(context, 'Trenutni korak', state.currentStepBs),
            _row(context, 'Šta sada treba', state.whatToDoBs),
            _row(context, 'Odgovoran', state.responsibleBs),
            if (state.dueBs != null) _row(context, 'Rok', state.dueBs!),
            _row(context, 'Sljedeća akcija', state.nextActionBs),
            const SizedBox(height: 12),
            if (state.step == NcrExecutionStep.closed ||
                state.primaryAction == NcrExecutionPrimaryAction.none)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.waitingForBs,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              )
            else if (state.userMayAct)
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => onPrimaryAction(state.primaryAction),
                icon: Icon(_iconFor(state.primaryAction)),
                label: Text(state.primaryActionLabelBs),
              )
            else
              Row(
                children: [
                  Icon(Icons.hourglass_top_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.waitingForBs,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(NcrExecutionPrimaryAction a) {
    switch (a) {
      case NcrExecutionPrimaryAction.assignExecutor:
        return Icons.person_add_alt_1_outlined;
      case NcrExecutionPrimaryAction.confirmRework:
        return Icons.check_circle_outline;
      case NcrExecutionPrimaryAction.runRecheck:
        return Icons.fact_check_outlined;
      case NcrExecutionPrimaryAction.closeNcr:
        return Icons.task_alt_outlined;
      case NcrExecutionPrimaryAction.newDecision:
        return Icons.alt_route_outlined;
      case NcrExecutionPrimaryAction.recordStop:
        return Icons.block_outlined;
      case NcrExecutionPrimaryAction.releaseStop:
        return Icons.play_circle_outline;
      case NcrExecutionPrimaryAction.none:
        return Icons.info_outline;
    }
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
