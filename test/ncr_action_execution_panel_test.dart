import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/quality/widgets/ncr_action_execution_panel.dart';

void main() {
  group('M1-I12-D — vođeni tok izvršenja akcije', () {
    Map<String, dynamic> ncr({
      required String executionStatus,
      String executorUserKey = '',
      String executor = '',
      String owner = 'Mirza Nuhanović',
    }) {
      return <String, dynamic>{
        'nextDispositionActionKey': 'send_to_rework',
        'nextDispositionOwner': owner,
        'nextDispositionRoleLabel': 'Menadžer proizvodnje',
        'nextDispositionExecutor': executor,
        'nextDispositionExecutorUserKey': executorUserKey,
        'nextDispositionExecutorRoleLabel': 'Operater proizvodnje',
        'nextDispositionDueAt': '2026-09-02T16:00',
        'executionStatus': executionStatus,
      };
    }

    test('bez pokrenute akcije nema panela', () {
      final state = NcrExecutionLogic.resolve(
        ncr: const <String, dynamic>{},
        currentUid: 'u1',
        normalizedRole: 'quality_control',
      );
      expect(state, isNull);
    });

    test('čeka izvršioca: menadžer proizvodnje dodjeljuje', () {
      final state = NcrExecutionLogic.resolve(
        ncr: ncr(executionStatus: 'awaiting_executor'),
        currentUid: 'mgr',
        normalizedRole: 'production_manager',
      )!;
      expect(state.primaryAction, NcrExecutionPrimaryAction.assignExecutor);
      expect(state.userMayAct, isTrue);
      expect(state.dueBs, isNull);
    });

    test('dodijeljeno: samo dodijeljeni izvršilac potvrđuje doradu', () {
      final data = ncr(
        executionStatus: 'executor_assigned',
        executorUserKey: 'exec-1',
        executor: 'Test korisnik',
      );
      final asExecutor = NcrExecutionLogic.resolve(
        ncr: data,
        currentUid: 'exec-1',
        normalizedRole: 'production_operator',
      )!;
      expect(asExecutor.primaryAction, NcrExecutionPrimaryAction.confirmRework);
      expect(asExecutor.userMayAct, isTrue);
      expect(asExecutor.dueBs, '02.09.2026. 16:00');

      final asManager = NcrExecutionLogic.resolve(
        ncr: data,
        currentUid: 'mgr',
        normalizedRole: 'production_manager',
      )!;
      expect(asManager.userMayAct, isFalse);
      expect(asManager.waitingForBs, contains('Test korisnik'));
    });

    test('dorada izvršena: ponovna kontrola je na kvalitetu', () {
      final state = NcrExecutionLogic.resolve(
        ncr: ncr(executionStatus: 'awaiting_recheck'),
        currentUid: 'q1',
        normalizedRole: 'quality_control',
      )!;
      expect(state.primaryAction, NcrExecutionPrimaryAction.runRecheck);
      expect(state.userMayAct, isTrue);

      final asOperator = NcrExecutionLogic.resolve(
        ncr: ncr(executionStatus: 'awaiting_recheck'),
        currentUid: 'op',
        normalizedRole: 'production_operator',
      )!;
      expect(asOperator.userMayAct, isFalse);

      final asManager = NcrExecutionLogic.resolve(
        ncr: ncr(executionStatus: 'awaiting_recheck'),
        currentUid: 'mgr',
        normalizedRole: 'production_manager',
      )!;
      expect(asManager.userMayAct, isFalse);
      expect(asManager.primaryAction, NcrExecutionPrimaryAction.runRecheck);
      expect(asManager.currentStepBs, contains('ponovnu kontrolu'));
    });

    test('zatvorena neusaglašenost — nema akcija za zatvaranje', () {
      final closed = NcrExecutionLogic.resolve(
        ncr: <String, dynamic>{
          ...ncr(executionStatus: 'recheck_ok'),
          'status': 'CLOSED',
        },
        currentUid: 'q1',
        normalizedRole: 'quality_control',
      )!;
      expect(closed.step, NcrExecutionStep.closed);
      expect(closed.primaryAction, NcrExecutionPrimaryAction.none);
      expect(closed.userMayAct, isFalse);
      expect(closed.whatToDoBs, contains('Tok je zatvoren'));
    });

    test('kontrola odobrena → zatvaranje; nije odobrena → nova odluka', () {
      final ok = NcrExecutionLogic.resolve(
        ncr: ncr(executionStatus: 'recheck_ok'),
        currentUid: 'q1',
        normalizedRole: 'quality_control',
      )!;
      expect(ok.primaryAction, NcrExecutionPrimaryAction.closeNcr);

      final nok = NcrExecutionLogic.resolve(
        ncr: ncr(executionStatus: 'recheck_nok'),
        currentUid: 'q1',
        normalizedRole: 'quality_control',
      )!;
      expect(nok.primaryAction, NcrExecutionPrimaryAction.newDecision);
      expect(nok.whatToDoBs, contains('nova'));
    });

    test('zaustavljanje: evidencija pa odobrenje nastavka', () {
      final pending = NcrExecutionLogic.resolve(
        ncr: ncr(executionStatus: 'stop_pending'),
        currentUid: 'mgr',
        normalizedRole: 'production_manager',
      )!;
      expect(pending.primaryAction, NcrExecutionPrimaryAction.recordStop);

      final stopped = NcrExecutionLogic.resolve(
        ncr: <String, dynamic>{
          ...ncr(executionStatus: 'stopped'),
          'executionStop': <String, dynamic>{
            'restartCondition': 'Zamijeniti alat i potvrditi prvi komad',
            'releaseApproverName': 'Mirza Nuhanović',
          },
        },
        currentUid: 'mgr',
        normalizedRole: 'production_manager',
      )!;
      expect(stopped.primaryAction, NcrExecutionPrimaryAction.releaseStop);
      expect(stopped.whatToDoBs, contains('Zamijeniti alat'));
    });

    test('poruke su na BS jeziku i bez tehničkih ključeva', () {
      final state = NcrExecutionLogic.resolve(
        ncr: ncr(
          executionStatus: 'executor_assigned',
          executorUserKey: 'exec-1',
          executor: 'Test korisnik',
        ),
        currentUid: 'exec-1',
        normalizedRole: 'production_operator',
      )!;
      final all = [
        state.currentStepBs,
        state.whatToDoBs,
        state.responsibleBs,
        state.nextActionBs,
        state.primaryActionLabelBs,
      ].join(' ');
      expect(all.contains('exec-1'), isFalse);
      expect(all.contains('_'), isFalse);
    });
  });
}
