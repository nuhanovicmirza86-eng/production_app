import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/features/catalog_evidence_runtime/utils/catalog_evidence_start_access.dart';
import 'package:production_app/modules/production/station_pages/models/production_evidence_config.dart';

void main() {
  ProductionEvidenceConfig lineConfig({
    List<String> runtimeAllowedRoles = const ['production_operator'],
    List<String> verifierRoleKeys = const [
      'production_manager',
      'quality_control',
      'quality_operator',
    ],
  }) {
    return ProductionEvidenceConfig(
      evidenceConfigId: 'co__ev_12',
      companyId: 'co',
      evidenceSlot: 12,
      plantKey: 'PLANT_2',
      processKey: 'cleaning',
      phaseKey: 'ostalo',
      displayName: 'Čišćenje mašine / linije',
      profileKey: 'line_clearance',
      profileNameSnapshot: 'Čišćenje mašine / linije',
      active: true,
      runtimeVisible: true,
      runtimeAllowedRoles: runtimeAllowedRoles,
      verifierRoleKeys: verifierRoleKeys,
    );
  }

  test('HOTFIX-28 operator starts line_clearance, manager does not', () {
    const runtime = ['production_operator'];
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleProductionOperator,
        runtimeAllowedRoles: runtime,
      ),
      isTrue,
    );
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleProductionManager,
        runtimeAllowedRoles: runtime,
      ),
      isFalse,
    );
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleQualityControl,
        runtimeAllowedRoles: runtime,
      ),
      isFalse,
    );
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleQualityOperator,
        runtimeAllowedRoles: runtime,
      ),
      isFalse,
    );
  });

  test('HOTFIX-28 manager in runtime roles still cannot start', () {
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleProductionManager,
        runtimeAllowedRoles: const [
          'production_operator',
          'production_manager',
        ],
      ),
      isFalse,
    );
  });

  test('HOTFIX-28 operator cannot start if not in start/runtime roles', () {
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleProductionOperator,
        runtimeAllowedRoles: const [],
      ),
      isFalse,
    );
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'line_clearance',
        userRole: ProductionAccessHelper.roleProductionOperator,
        runtimeAllowedRoles: const ['production_manager'],
      ),
      isFalse,
    );
  });

  test('HOTFIX-28 manager still sees line_clearance to verify', () {
    final config = lineConfig();
    expect(
      config.isRuntimeVisibleToRole(ProductionAccessHelper.roleProductionManager),
      isTrue,
    );
    expect(
      config.isRuntimeVisibleToRole(
        ProductionAccessHelper.roleProductionOperator,
      ),
      isTrue,
    );
    expect(
      canStartCatalogEvidenceSession(
        profileKey: config.profileKey,
        userRole: ProductionAccessHelper.roleProductionManager,
        runtimeAllowedRoles: config.runtimeAllowedRoles,
      ),
      isFalse,
    );
  });

  test('HOTFIX-28 5S start UX stays unchanged for manager', () {
    expect(
      canStartCatalogEvidenceSession(
        profileKey: 'workspace_5s_cleaning',
        userRole: ProductionAccessHelper.roleProductionManager,
      ),
      isTrue,
    );
  });

  test('HOTFIX-28 idle copy is BCS without ids', () {
    expect(lineClearanceVerifierIdleTitle.contains('@'), isFalse);
    expect(lineClearanceVerifierIdleHint.contains('line_clearance'), isFalse);
    expect(catalogEvidenceStartDeniedMessage.contains('permission'), isFalse);
  });
}
