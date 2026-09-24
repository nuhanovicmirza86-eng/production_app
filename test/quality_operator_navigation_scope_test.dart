import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/production/station_pages/models/production_evidence_config.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_config.dart';

void main() {
  const role = ProductionAccessHelper.roleQualityOperator;

  test('quality_operator can open control evidence hub', () {
    expect(ProductionAccessHelper.canAccessQualityControlEvidenceHub(role), isTrue);
    expect(
      ProductionAccessHelper.isQualityControlEvidenceProfile('packaging_control'),
      isTrue,
    );
    expect(
      ProductionAccessHelper.isQualityControlEvidenceProfile('first_piece_approval'),
      isTrue,
    );
    expect(
      ProductionAccessHelper.isQualityControlEvidenceProfile('line_clearance'),
      isTrue,
    );
    expect(
      ProductionAccessHelper.isQualityControlEvidenceProfile(
        'workspace_5s_cleaning',
      ),
      isTrue,
    );
    expect(
      ProductionAccessHelper.isQualityControlEvidenceProfile('chemical_dosing'),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canQualityOperatorWorkControlEvidence(
        role: role,
        profileKey: 'packaging_control',
      ),
      isTrue,
    );
    expect(
      ProductionAccessHelper.canQualityOperatorWorkControlEvidence(
        role: role,
        profileKey: 'chemical_dosing',
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canViewProfileDrivenEvidence(role),
      isFalse,
    );
  });

  test('quality_operator does not see production planning or OOE cards', () {
    expect(
      ProductionAccessHelper.canView(
        role: role,
        card: ProductionDashboardCard.productionOrders,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canView(
        role: role,
        card: ProductionDashboardCard.productionProcesses,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canView(
        role: role,
        card: ProductionDashboardCard.ooe,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canView(
        role: role,
        card: ProductionDashboardCard.workCenters,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canView(
        role: role,
        card: ProductionDashboardCard.qualityManagement,
      ),
      isTrue,
    );
  });

  test('line_clearance is registered for catalog company evidence runtime', () {
    expect(
      ProductionEvidenceConfig.isH3OperatorRuntimeProfile('line_clearance'),
      isTrue,
    );
    expect(
      ProductionStationConfig.isCatalogEvidenceRuntimeProfile('line_clearance'),
      isTrue,
    );
    expect(
      ProductionEvidenceConfig.isH3OperatorRuntimeProfile(
        'workspace_5s_cleaning',
      ),
      isTrue,
    );
    expect(
      ProductionStationConfig.isCatalogEvidenceRuntimeProfile(
        'workspace_5s_cleaning',
      ),
      isTrue,
    );
  });
}
