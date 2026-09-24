import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/production/station_pages/models/production_evidence_config.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_profile_catalog_entry.dart';

void main() {
  test('5S catalog verification requires production_manager signature', () {
    final profile = ProductionStationProfileCatalogEntry.fromMap(const {
      'profileKey': 'workspace_5s_cleaning',
      'displayName': '5S čišćenje radnog prostora',
      'verification': {
        'signedByLoggedInUser': true,
        'verifierRoleKeys': ['production_manager'],
        'verifierFieldKey': 'verifiedByEmployeeId',
      },
      'fields': [
        {
          'key': 'verifiedByEmployeeId',
          'label': 'Verifikovao neposredni rukovodilac',
          'type': 'entity_search_select',
          'signedByLoggedInUser': true,
        },
      ],
    });
    expect(profile.hasSignedLoggedInVerifier, isTrue);
    expect(profile.verifierRoleKeys, [ProductionAccessHelper.roleProductionManager]);
    expect(
      profile.signedVerifierDeniedMessage,
      'Verifikacija nije dostupna za vašu ulogu.',
    );
    expect(profile.signedVerifierDeniedMessage, isNot(contains('quality_operator')));
  });

  test('HOTFIX-16 verifier roles stay on the opened evidence config', () {
    const fiveS = {
      'evidenceConfigId': 'plamingo__ev_13',
      'companyId': 'plamingo',
      'evidenceSlot': 13,
      'plantKey': 'PLANT_2',
      'processKey': '5s',
      'phaseKey': 'ostalo',
      'displayName': '5S čišćenje radnog prostora',
      'profileKey': 'workspace_5s_cleaning',
      'profileNameSnapshot': '5S čišćenje radnog prostora',
      'active': true,
      'runtimeVisible': true,
      'runtimeAllowedRoles': ['production_operator'],
      'verifierRoleKeys': ['production_manager'],
    };
    const lineClearance = {
      'evidenceConfigId': 'plamingo__ev_12',
      'companyId': 'plamingo',
      'evidenceSlot': 12,
      'plantKey': 'PLANT_2',
      'processKey': '5s',
      'phaseKey': 'ostalo',
      'displayName': 'Čišćenje mašine / linije',
      'profileKey': 'line_clearance',
      'profileNameSnapshot': 'Čišćenje mašine / linije',
      'active': true,
      'runtimeVisible': true,
      'runtimeAllowedRoles': ['quality_operator'],
      'verifierRoleKeys': [
        'quality_control',
        'quality_operator',
        'production_manager',
      ],
    };
    final fiveSConfig = ProductionEvidenceConfig.fromMap(fiveS);
    final lineConfig = ProductionEvidenceConfig.fromMap(lineClearance);
    expect(fiveSConfig.processKey, lineConfig.processKey);
    expect(fiveSConfig.plantKey, lineConfig.plantKey);
    expect(fiveSConfig.evidenceConfigId, isNot(lineConfig.evidenceConfigId));
    expect(fiveSConfig.effectiveVerifierRoleKeys(), ['production_manager']);
    expect(
      lineConfig.effectiveVerifierRoleKeys(),
      [
        ProductionAccessHelper.roleQualityControl,
        ProductionAccessHelper.roleQualityOperator,
        ProductionAccessHelper.roleProductionManager,
      ],
    );
    expect(
      fiveSConfig.effectiveVerifierRoleKeys(),
      isNot(lineConfig.effectiveVerifierRoleKeys()),
    );
  });
}
