import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/logged_in_performer.dart';

void main() {
  test('HOTFIX-24 auto-fills Izvršio only for production operator', () {
    expect(
      shouldAutofillPerformedByFromLoggedInOperator(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleProductionOperator,
      ),
      isTrue,
    );
    expect(
      shouldAutofillPerformedByFromLoggedInOperator(
        profileKey: 'workspace_5s_cleaning',
        userRole: ProductionAccessHelper.roleProductionOperator,
      ),
      isTrue,
    );
    expect(
      shouldAutofillPerformedByFromLoggedInOperator(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleQualityOperator,
      ),
      isFalse,
    );
    expect(
      shouldAutofillPerformedByFromLoggedInOperator(
        profileKey: 'packaging_control',
        userRole: ProductionAccessHelper.roleProductionOperator,
      ),
      isFalse,
    );
  });

  test('HOTFIX-24 locks Izvršio for autofill and verifier handoff', () {
    expect(
      shouldLockPerformedByField(
        autofillFromLoggedInOperator: true,
        verifierHandoff: false,
      ),
      isTrue,
    );
    expect(
      shouldLockPerformedByField(
        autofillFromLoggedInOperator: false,
        verifierHandoff: true,
      ),
      isTrue,
    );
    expect(
      shouldLockPerformedByField(
        autofillFromLoggedInOperator: false,
        verifierHandoff: false,
      ),
      isFalse,
    );
  });

  test('HOTFIX-24 display name never uses email, UID or dash', () {
    expect(
      loggedInPerformerDisplayName({
        'displayName': 'Test korisnik',
        'userEmail': 'test@example.com',
      }),
      'Test korisnik',
    );
    expect(
      loggedInPerformerDisplayName({
        'userEmail': 'test@example.com',
      }),
      '',
    );
    expect(
      loggedInPerformerDisplayName({
        'displayName': '—',
      }),
      '',
    );
    expect(
      loggedInPerformerDisplayName({
        'firstName': 'Mirza',
        'lastName': 'Nuhan',
      }),
      'Mirza Nuhan',
    );
  });

  test('HOTFIX-30 auto-fills Operater kvaliteta only for quality_operator on final_control', () {
    expect(
      shouldAutofillFinalControlQualityOperator(
        profileKey: 'final_control',
        userRole: ProductionAccessHelper.roleQualityOperator,
      ),
      isTrue,
    );
    expect(
      shouldAutofillFinalControlQualityOperator(
        profileKey: 'final_control',
        userRole: ProductionAccessHelper.roleProductionManager,
      ),
      isFalse,
    );
    expect(
      shouldAutofillFinalControlQualityOperator(
        profileKey: 'packaging_control',
        userRole: ProductionAccessHelper.roleQualityOperator,
      ),
      isFalse,
    );
  });

  test('HOTFIX-30 copy has no email, UID, EN or raw field key', () {
    expect(loggedInFinalControlQualityOperatorHelper.contains('@'), isFalse);
    expect(
      loggedInFinalControlQualityOperatorHelper.contains('controllerEmployeeId'),
      isFalse,
    );
    expect(loggedInFinalControlQualityOperatorHelper.contains('permission'), isFalse);
    expect(finalControlQualityOperatorFinishDeniedMessage.contains('@'), isFalse);
    expect(
      finalControlQualityOperatorFinishDeniedMessage.contains('quality_operator'),
      isFalse,
    );
    expect(loggedInPerformerDisplayName({'userEmail': 'mirza@firma.ba'}), '');
  });
}
