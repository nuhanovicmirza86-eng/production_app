import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/quality/widgets/ncr_action_hodogram_model.dart';

void main() {
  group('NcrActionHodogramLogic action tone', () {
    test('idle when no action', () {
      expect(
        NcrActionHodogramLogic.resolveActionTone(
          actionKey: null,
          dueAt: null,
          ncrStatus: 'OPEN',
        ),
        NcrHodogramActionTone.idle,
      );
    });

    test('assigned when action set and due far', () {
      expect(
        NcrActionHodogramLogic.resolveActionTone(
          actionKey: 'send_to_rework',
          dueAt: '2099-12-31',
          ncrStatus: 'OPEN',
          now: DateTime(2026, 8, 28),
        ),
        NcrHodogramActionTone.assigned,
      );
    });

    test('watch when due within 3 days', () {
      expect(
        NcrActionHodogramLogic.resolveActionTone(
          actionKey: 'schedule_recheck',
          dueAt: '2026-08-30',
          ncrStatus: 'OPEN',
          now: DateTime(2026, 8, 28),
        ),
        NcrHodogramActionTone.watch,
      );
    });

    test('critical when overdue', () {
      expect(
        NcrActionHodogramLogic.resolveActionTone(
          actionKey: 'send_to_rework',
          dueAt: '2026-08-20',
          ncrStatus: 'OPEN',
          now: DateTime(2026, 8, 28),
        ),
        NcrHodogramActionTone.critical,
      );
    });

    test('critical when stop production', () {
      expect(
        NcrActionHodogramLogic.resolveActionTone(
          actionKey: 'stop_production',
          dueAt: '2099-01-01',
          ncrStatus: 'OPEN',
        ),
        NcrHodogramActionTone.critical,
      );
    });

    test('complete when NCR closed', () {
      expect(
        NcrActionHodogramLogic.resolveActionTone(
          actionKey: 'send_to_rework',
          dueAt: '2026-08-20',
          ncrStatus: 'CLOSED',
        ),
        NcrHodogramActionTone.complete,
      );
    });
  });

  test('build snapshot — evidence path current at next action', () {
    final snap = NcrActionHodogramLogic.build(
      const NcrHodogramInput(
        outcomeLabel: 'Odbijeno',
        containmentAction: 'Zadrži lot do odluke',
        ncrCode: 'NCR-2026-001',
        hasNcr: true,
        fromEvidenceSession: true,
        ncrStatus: 'OPEN',
      ),
    );
    expect(snap.currentStepId, NcrHodogramStepId.nextAction);
    expect(snap.steps[4].actionTone, NcrHodogramActionTone.idle);
    expect(snap.steps[4].detailRows.any((r) => r.label == 'Status akcije'), isTrue);
    expect(
      snap.steps.every((s) => !s.summary.contains(RegExp(r'^[A-Za-z0-9]{20}$'))),
      isTrue,
    );
  });

  test('BS step titles', () {
    expect(NcrHodogramStepId.nextAction.titleBs, 'Sljedeća akcija');
    expect(NcrHodogramStepId.notificationSent.titleBs, 'Obavijest poslana');
    expect(NcrHodogramStepId.resolution.titleBs, 'Status rješavanja');
  });

  test('formatDueBs includes time when present', () {
    expect(
      NcrActionHodogramLogic.formatDueBs('2026-08-29T16:00'),
      '29.08.2026. 16:00',
    );
  });
}
