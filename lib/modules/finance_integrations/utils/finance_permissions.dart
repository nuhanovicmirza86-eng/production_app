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

  /// Globalni ili profil bez pogona: u hubu se može odabrati jedan pogon ili „svi pogoni“.
  static bool shouldUseHubPlantScopeSelector({
    required String role,
    required String profilePlantKey,
  }) {
    final r = ProductionAccessHelper.normalizeRole(role);
    final pk = profilePlantKey.trim();
    if (ProductionAccessHelper.isAdminRole(r) ||
        ProductionAccessHelper.isSuperAdminRole(r)) {
      return true;
    }
    if (pk.isNotEmpty) return false;
    const scope = <String>{
      ProductionAccessHelper.roleAccountingManager,
      ProductionAccessHelper.roleAccountingClerk,
      ProductionAccessHelper.roleProjectManager,
      ProductionAccessHelper.roleDevelopmentEngineer,
      ProductionAccessHelper.roleManagementViewer,
    };
    return scope.contains(r);
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

  /// Operativni Cash Flow (računi, kategorije, transakcije) — modul [finance_controlling].
  static bool canAccessCashFlowOperative({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    return canViewControllingAnalytics(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    );
  }

  static bool _cashFlowOperativeUnlocked({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    return canAccessCashFlowOperative(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    );
  }

  static bool _isCashFlowManagerRole(String role) {
    final r = ProductionAccessHelper.normalizeRole(role);
    return ProductionAccessHelper.isSuperAdminRole(r) ||
        ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleAccountingManager;
  }

  static String _currentUserId(Map<String, dynamic> companyData) {
    return (companyData['userId'] ?? companyData['uid'] ?? '').toString().trim();
  }

  /// Pregled transakcija i realizovanog Cash Flow izvještaja.
  static bool canViewRealizedCashFlow({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    return _cashFlowOperativeUnlocked(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    );
  }

  /// Kreiranje draft transakcije.
  static bool canCreateCashTransactionDraft({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    return _cashFlowOperativeUnlocked(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    );
  }

  /// Uređivanje drafta; referent samo vlastiti nacrt.
  static bool canEditCashTransactionDraft({
    required Map<String, dynamic> companyData,
    required String role,
    required String transactionCreatedBy,
    bool debugUnlockModule = false,
  }) {
    if (!_cashFlowOperativeUnlocked(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return false;
    }
    if (_isCashFlowManagerRole(role)) return true;
    final r = ProductionAccessHelper.normalizeRole(role);
    if (r == ProductionAccessHelper.roleAccountingClerk) {
      final uid = _currentUserId(companyData);
      return uid.isNotEmpty && uid == transactionCreatedBy.trim();
    }
    return false;
  }

  /// Knjiženje drafta — ne referent.
  static bool canPostCashTransaction({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    if (!_cashFlowOperativeUnlocked(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return false;
    }
    return _isCashFlowManagerRole(role);
  }

  /// Usklađivanje knjižene transakcije (bez promjene salda).
  static bool canReconcileCashTransaction({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    return _cashFlowOperativeUnlocked(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    );
  }

  /// Storno knjižene transakcije (reversal) — ne referent.
  static bool canReverseCashTransaction({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    if (!_cashFlowOperativeUnlocked(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return false;
    }
    return _isCashFlowManagerRole(role);
  }

  /// Otkaz drafta — ista logika kao uređivanje drafta.
  static bool canCancelCashTransactionDraft({
    required Map<String, dynamic> companyData,
    required String role,
    required String transactionCreatedBy,
    bool debugUnlockModule = false,
  }) {
    return canEditCashTransactionDraft(
      companyData: companyData,
      role: role,
      transactionCreatedBy: transactionCreatedBy,
      debugUnlockModule: debugUnlockModule,
    );
  }

  /// Kreiranje / izmjena računa i Cash Flow kategorija — ne [accounting_clerk].
  static bool canManageCashFlowMasterData({
    required Map<String, dynamic> companyData,
    required String role,
    bool debugUnlockModule = false,
  }) {
    if (!canAccessCashFlowOperative(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return false;
    }
    final r = ProductionAccessHelper.normalizeRole(role);
    return ProductionAccessHelper.isSuperAdminRole(r) ||
        ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleAccountingManager;
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
