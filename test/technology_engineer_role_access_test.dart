import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/access/production_access_helper.dart';

void main() {
  const role = ProductionAccessHelper.roleTechnologyEngineer;

  test('technology_engineer is a known canonical role with its own label', () {
    expect(role, 'technology_engineer');
    expect(ProductionAccessHelper.normalizeRole(role), role);
    expect(
      ProductionAccessHelper.displayRoleLabel(role),
      'Inženjer tehnologije',
    );
  });

  test('technology_engineer is not development_engineer', () {
    expect(
      ProductionAccessHelper.normalizeRole(role),
      isNot(ProductionAccessHelper.roleDevelopmentEngineer),
    );
    expect(
      ProductionAccessHelper.displayRoleLabel(
        ProductionAccessHelper.roleDevelopmentEngineer,
      ),
      'Inženjer razvoja',
    );
    expect(
      ProductionAccessHelper.normalizeRole('development_engineer'),
      ProductionAccessHelper.roleDevelopmentEngineer,
    );
  });

  test('technology_engineer is company-wide and not an operational assistant', () {
    expect(ProductionAccessHelper.isCompanyWideContextRole(role), isTrue);
    expect(
      ProductionAccessHelper.canUseOperationalProductionAssistant(role),
      isFalse,
    );
    expect(
      ProductionAccessHelper.isCompanyWideContextRole('quality_control'),
      isTrue,
    );
    expect(
      ProductionAccessHelper.canUseOperationalProductionAssistant(
        'quality_control',
      ),
      isTrue,
    );
  });

  test('technology_engineer has no admin, manager, or quality privileges', () {
    expect(ProductionAccessHelper.isAdminRole(role), isFalse);
    expect(ProductionAccessHelper.isSuperAdminRole(role), isFalse);
    expect(
      ProductionAccessHelper.canManage(
        role: role,
        card: ProductionDashboardCard.products,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canManage(
        role: ProductionAccessHelper.roleAdmin,
        card: ProductionDashboardCard.products,
      ),
      isTrue,
    );
    expect(
      ProductionAccessHelper.canManage(
        role: ProductionAccessHelper.roleProductionManager,
        card: ProductionDashboardCard.productionOrders,
      ),
      isTrue,
    );
    expect(
      ProductionAccessHelper.canManage(
        role: role,
        card: ProductionDashboardCard.productionOrders,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canView(
        role: role,
        card: ProductionDashboardCard.qualityManagement,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canManage(
        role: ProductionAccessHelper.roleQualityControl,
        card: ProductionDashboardCard.qualityManagement,
      ),
      isTrue,
    );
    expect(
      ProductionAccessHelper.canUseProfileStationRuntime(role),
      isFalse,
    );
  });

  test('technology_engineer sees Products and no other dashboard card', () {
    expect(
      ProductionAccessHelper.canView(
        role: role,
        card: ProductionDashboardCard.products,
      ),
      isTrue,
    );
    for (final card in ProductionDashboardCard.values) {
      if (card == ProductionDashboardCard.products) continue;
      expect(
        ProductionAccessHelper.canView(role: role, card: card),
        isFalse,
        reason: card.name,
      );
    }
  });

  test('PMA draft preparers are the locked M2 roles', () {
    expect(
      ProductionAccessHelper.canPrepareProductMachineApprovalDraft(role),
      isTrue,
    );
    for (final allowed in [
      ProductionAccessHelper.roleAdmin,
      ProductionAccessHelper.roleProductionManager,
      ProductionAccessHelper.roleQualityControl,
    ]) {
      expect(
        ProductionAccessHelper.canPrepareProductMachineApprovalDraft(allowed),
        isTrue,
        reason: allowed,
      );
    }
    for (final denied in [
      ProductionAccessHelper.roleSuperAdmin,
      ProductionAccessHelper.roleDevelopmentEngineer,
      ProductionAccessHelper.roleProductionOperator,
      ProductionAccessHelper.roleShiftLead,
    ]) {
      expect(
        ProductionAccessHelper.canPrepareProductMachineApprovalDraft(denied),
        isFalse,
        reason: denied,
      );
    }
  });

  test('development_engineer still does not see Products', () {
    expect(
      ProductionAccessHelper.canView(
        role: ProductionAccessHelper.roleDevelopmentEngineer,
        card: ProductionDashboardCard.products,
      ),
      isFalse,
    );
    expect(
      ProductionAccessHelper.canView(
        role: ProductionAccessHelper.roleDevelopmentEngineer,
        card: ProductionDashboardCard.developmentGovernance,
      ),
      isTrue,
    );
  });
}
