import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/controlled_evidence_person_role_keys.dart';
import 'package:production_app/features/profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import 'package:production_app/features/profile_driven_structured_runtime/utils/structured_entity_search_result_appearance.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_profile_field.dart';

void main() {
  test('5S verifier catalog defaults are manager and shift lead', () {
    expect(
      controlledEvidenceRoleKeysForPersonField(
        'verifiedByEmployeeId',
        profileKey: 'workspace_5s_cleaning',
      ),
      [
        ProductionAccessHelper.roleProductionManager,
        ProductionAccessHelper.roleShiftLead,
      ],
    );
    expect(
      controlledEvidenceRoleKeysForPersonField(
        'verifiedByEmployeeId',
        profileKey: 'line_clearance',
      ),
      [
        ProductionAccessHelper.roleQualityControl,
        ProductionAccessHelper.roleQualityOperator,
        ProductionAccessHelper.roleProductionManager,
      ],
    );
    expect(
      controlledEvidenceRoleKeysForPersonField('performedByEmployeeId',
          profileKey: 'workspace_5s_cleaning'),
      [ProductionAccessHelper.roleProductionOperator],
    );
  });

  test('5S verifier helper and label are signed supervisor copy', () {
    expect(
      controlledEvidencePersonHelperText(
        'verifiedByEmployeeId',
        profileKey: 'workspace_5s_cleaning',
      ),
      workspace5sVerifierHelperText,
    );
    expect(workspace5sVerifierHelperText, contains('potpis prijavljenog'));
    expect(workspace5sVerifierDeniedMessage, contains('Verifikacija nije dostupna'));
    expect(
      controlledEvidencePersonHelperText(
        'verifiedByEmployeeId',
        profileKey: 'line_clearance',
      ),
      contains('potpis prijavljenog'),
    );
    expect(workspace5sVerifierFieldLabel, 'Verifikovao neposredni rukovodilac');
    expect(workspace5sPerformedByFieldLabel, 'Izvršio');
    expect(
      workspace5sPerformedByHandoffHelper,
      contains('Verifikator ne mijenja'),
    );
    expect(workspace5sPerformedByHandoffHelper, isNot(contains('UID')));
  });

  test('5S verifier picker badge is Menadžer proizvodnje', () {
    final field = ProductionStationProfileField.fromMap(const {
      'key': 'verifiedByEmployeeId',
      'label': 'Verifikovao neposredni rukovodilac',
      'type': 'entity_search_select',
    });
    final item = StructuredEntitySearchResult.fromMap({
      'id': 'uid1',
      'displayName': 'Ana Horvat',
      'role': 'production_manager',
    });
    expect(
      StructuredEntitySearchResultAppearance.badgeLabel(
        field: field,
        item: item,
      ),
      'Menadžer proizvodnje',
    );
  });
}
