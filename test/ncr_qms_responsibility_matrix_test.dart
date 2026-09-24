import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/quality/utils/ncr_next_disposition_catalog.dart';
import 'package:production_app/modules/quality/utils/ncr_qms_responsibility_matrix.dart';
import 'package:production_app/modules/quality/widgets/ncr_action_hodogram_model.dart';

void main() {
  group('NcrQmsResponsibilityMatrix two-phase rework', () {
    test('phase 1 owner is only production manager', () {
      final roles = NcrQmsResponsibilityMatrix.reworkOwnerRoles();
      expect(roles, hasLength(1));
      expect(roles.first.id, ProductionAccessHelper.roleProductionManager);
      expect(roles.first.labelBs, 'Menadžer proizvodnje');
    });

    test('phase 2 executors are only existing production roles', () {
      final roles = NcrQmsResponsibilityMatrix.reworkExecutorRoles();
      expect(
        roles.map((r) => r.id).toList(),
        [
          ProductionAccessHelper.roleProductionOperator,
          ProductionAccessHelper.roleShiftLead,
        ],
      );
      expect(
        roles.map((r) => r.labelBs),
        [
          'Operater proizvodnje',
          'Vođa smjene / linije',
        ],
      );
      expect(
        roles.any((r) => r.labelBs.toLowerCase().contains('tehnolog')),
        isFalse,
      );
      expect(roles.every((r) => !r.labelBs.contains('_')), isTrue);
    });

    test('resolveFlowPhase: fresh rework → initiate owner', () {
      expect(
        NcrQmsResponsibilityMatrix.resolveFlowPhase(
          actionKey: 'send_to_rework',
          existingActionKey: null,
          existingOwner: null,
          existingExecutor: null,
        ),
        NcrDispositionFlowPhase.initiateReworkOwner,
      );
    });

    test('resolveFlowPhase: owner set, no executor → assign executor', () {
      expect(
        NcrQmsResponsibilityMatrix.resolveFlowPhase(
          actionKey: 'send_to_rework',
          existingActionKey: 'send_to_rework',
          existingOwner: 'Ana',
          existingExecutor: null,
        ),
        NcrDispositionFlowPhase.assignReworkExecutor,
      );
    });

    test('business label is Potrebna dorada', () {
      expect(
        NcrNextDispositionAction.sendToRework.businessLabelBs,
        'Potrebna dorada',
      );
      expect(
        NcrNextDispositionAction.sendToRework.labelHr,
        'Pošalji na doradu',
      );
    });

    test('hodogram tone watch while awaiting executor', () {
      expect(
        NcrActionHodogramLogic.resolveActionTone(
          actionKey: 'send_to_rework',
          dueAt: null,
          ncrStatus: 'OPEN',
          phase: 'awaiting_executor',
        ),
        NcrHodogramActionTone.watch,
      );
    });

    test('matrix not from evidence visibility quality roles for rework owner', () {
      final ids = NcrQmsResponsibilityMatrix.reworkOwnerRoles()
          .map((e) => e.id)
          .toSet();
      expect(ids.contains(ProductionAccessHelper.roleQualityControl), isFalse);
      expect(ids.contains(ProductionAccessHelper.roleQualityOperator), isFalse);
    });
  });
}
