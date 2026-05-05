import '../../../core/access/production_access_helper.dart';
import '../../../core/saas/production_module_keys.dart';

/// RBAC + SaaS entitlements za **Finance & Controlling** (kartica [financeControlling]).
class FinancePermissions {
  FinancePermissions._();

  static bool canAccessModule({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    final r = ProductionAccessHelper.normalizeRole(role);
    if (!ProductionAccessHelper.canView(
      role: r,
      card: ProductionDashboardCard.financeControlling,
    )) {
      return false;
    }
    if (debugUnlockModule) return true;
    // Tenant admini vide ulaz u hub (konfiguracija / uvodenje modula); ostale
    // uloge samo uz aktivnu pretplatu u companies.*Modules.
    if (ProductionAccessHelper.isAdminRole(r) ||
        ProductionAccessHelper.isSuperAdminRole(r)) {
      return true;
    }
    return ProductionModuleKeys.hasFinanceSuite(companyData);
  }

  static bool canViewControllingAnalytics({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    if (!canAccessModule(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return false;
    }
    if (debugUnlockModule) return true;
    return ProductionModuleKeys.hasFinanceControllingCore(companyData);
  }

  /// ERP veze / sync — pretplata [financeIntegrations] ili [financeControlling].
  static bool canViewErpIntegrationLayer({
    required Map<String, dynamic> companyData,
    bool debugUnlockModule = false,
  }) {
    if (debugUnlockModule) return true;
    return ProductionModuleKeys.hasFinanceSuite(companyData);
  }

  /// Upravljanje ERP vezama (Callable [upsertFinanceConnection]).
  static bool canManageConnections({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    if (!canAccessModule(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return false;
    }
    final r = ProductionAccessHelper.normalizeRole(role);
    return ProductionAccessHelper.canManage(
      role: r,
      card: ProductionDashboardCard.financeControlling,
    );
  }

  /// Izmjena `companies.financeControllingDefaults` preko Callabla [updateCompanyOperationalConfig].
  static bool canEditFinanceControllingDefaults(String role) {
    final r = ProductionAccessHelper.normalizeRole(role);
    if (ProductionAccessHelper.isSuperAdminRole(r)) return true;
    if (ProductionAccessHelper.isAdminRole(r)) return true;
    return r == ProductionAccessHelper.roleAccountingManager;
  }

  /// Memorija za Finance AI ([upsertFinanceAiCompanyMemory]) — isti krug kao kontroling postavke.
  static bool canEditFinanceAiCompanyMemory(String role) {
    return canEditFinanceControllingDefaults(role);
  }

  /// Budžeti / zaključavanje FY — šef računovodstva, referent, admin, PM (čitanje budžeta projekta).
  static bool canViewBudgetWorkspace({
    required String role,
  }) {
    final r = ProductionAccessHelper.normalizeRole(role);
    if (ProductionAccessHelper.isSuperAdminRole(r) ||
        ProductionAccessHelper.isAdminRole(r)) {
      return true;
    }
    return r == ProductionAccessHelper.roleAccountingManager ||
        r == ProductionAccessHelper.roleAccountingClerk ||
        r == ProductionAccessHelper.roleProjectManager;
  }

  /// Finance AI (Callable [runFinanceControllingAiInsight]) — isti skup uloga kao preračun KPI na backendu.
  static bool canRunFinanceControllingAiInsight({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    if (!canViewControllingAnalytics(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return false;
    }
    if (debugUnlockModule) return true;
    if (!ProductionModuleKeys.hasAiProductionMarkdownReportModule(companyData)) {
      return false;
    }
    final r = ProductionAccessHelper.normalizeRole(role);
    const allowed = <String>{
      ProductionAccessHelper.roleSuperAdmin,
      ProductionAccessHelper.roleAdmin,
      ProductionAccessHelper.roleAccountingManager,
      ProductionAccessHelper.roleAccountingClerk,
      ProductionAccessHelper.roleProductionManager,
      ProductionAccessHelper.roleLogisticsManager,
      ProductionAccessHelper.roleQualityControl,
      ProductionAccessHelper.roleQualityOperator,
      ProductionAccessHelper.roleMaintenanceManager,
      ProductionAccessHelper.roleProjectManager,
      ProductionAccessHelper.roleDevelopmentEngineer,
      ProductionAccessHelper.roleManagementViewer,
    };
    return allowed.contains(r);
  }
}
