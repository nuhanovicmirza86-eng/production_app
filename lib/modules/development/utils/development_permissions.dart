import '../../../core/access/production_access_helper.dart';
import '../../../core/saas/production_module_keys.dart';
import '../models/development_project_model.dart';

/// RBAC i SaaS capability za modul **development** (portfelj + pojedinačni projekat).
///
/// AI / Stage-Gate add-oni: [ProductionModuleKeys.hasDevelopmentCapability].
class DevelopmentPermissions {
  DevelopmentPermissions._();

  static String _norm(dynamic role) => ProductionAccessHelper.normalizeRole(role);

  /// Je li korisnik na projektnom timu (`team[]`, PM ili agregat `teamMemberIds`).
  static bool isUserOnProjectTeam(DevelopmentProjectModel project, String? userId) {
    final uid = (userId ?? '').trim();
    if (uid.isEmpty) return false;
    if (project.projectManagerId == uid) return true;
    return project.teamMemberIds.contains(uid);
  }

  /// FAB „Novi projekat“ — usklađeno s Callable [createDevelopmentProject] (admin / super_admin / PM).
  static bool canCreateDevelopmentProject({
    required String? role,
    required Map<String, dynamic> companyData,
  }) {
    if (!ProductionModuleKeys.hasModule(companyData, ProductionModuleKeys.development)) {
      return false;
    }
    final r = _norm(role);
    if (r == ProductionAccessHelper.roleSuperAdmin ||
        r == ProductionAccessHelper.roleAdmin) {
      return true;
    }
    return ProductionAccessHelper.canManage(
      role: r,
      card: ProductionDashboardCard.developmentGovernance,
    );
  }

  /// Osnovni podaci projekta — Callable [updateDevelopmentProject] (isti skup uloga kao kreiranje).
  static bool canEditDevelopmentProjectCore({
    required String? role,
    required Map<String, dynamic> companyData,
  }) {
    return canCreateDevelopmentProject(role: role, companyData: companyData);
  }

  /// Zadaci (`tasks` podprojekat) — Callables [createDevelopmentProjectTask] / [updateDevelopmentProjectTask].
  static bool canMutateDevelopmentTasks({
    required String? role,
    required Map<String, dynamic> companyData,
  }) {
    if (!ProductionModuleKeys.hasModule(companyData, ProductionModuleKeys.development)) {
      return false;
    }
    final r = _norm(role);
    if (ProductionAccessHelper.isSuperAdminRole(r) ||
        ProductionAccessHelper.isAdminRole(r)) {
      return true;
    }
    return r == ProductionAccessHelper.roleProjectManager ||
        r == ProductionAccessHelper.roleDevelopmentEngineer ||
        r == ProductionAccessHelper.roleQualityOperator ||
        r == ProductionAccessHelper.roleQualityControl ||
        r == ProductionAccessHelper.roleProductionManager ||
        r == ProductionAccessHelper.roleSupervisor;
  }

  /// Rizici (`risks`) — Callables [createDevelopmentProjectRisk] / [updateDevelopmentProjectRisk]; ista matrica kao zadaci.
  static bool canMutateDevelopmentRisks({
    required String? role,
    required Map<String, dynamic> companyData,
  }) {
    return canMutateDevelopmentTasks(role: role, companyData: companyData);
  }

  /// AI sažetak projekta — Callable [runDevelopmentProjectAiAnalysis]; pretplata + uloga.
  static bool canRunDevelopmentProjectAi({
    required String? role,
    required Map<String, dynamic> companyData,
  }) {
    if (!ProductionModuleKeys.canUseDevelopmentProjectAi(companyData)) {
      return false;
    }
    final r = _norm(role);
    if (ProductionAccessHelper.isSuperAdminRole(r) ||
        ProductionAccessHelper.isAdminRole(r)) {
      return true;
    }
    return r == ProductionAccessHelper.roleProjectManager ||
        r == ProductionAccessHelper.roleDevelopmentEngineer ||
        r == ProductionAccessHelper.roleQualityOperator ||
        r == ProductionAccessHelper.roleQualityControl ||
        r == ProductionAccessHelper.roleProductionManager ||
        r == ProductionAccessHelper.roleSupervisor ||
        r == ProductionAccessHelper.roleProductionOperator ||
        r == ProductionAccessHelper.roleManagementViewer ||
        r == ProductionAccessHelper.roleMaintenanceManager ||
        r == ProductionAccessHelper.roleLogisticsManager;
  }

  /// Tim projekta — Callable [replaceDevelopmentProjectTeam]: admin/super_admin ili trenutni PM.
  static bool canEditDevelopmentProjectTeam({
    required String? role,
    required Map<String, dynamic> companyData,
    required DevelopmentProjectModel project,
    required String? currentUserId,
  }) {
    if (!ProductionModuleKeys.hasModule(companyData, ProductionModuleKeys.development)) {
      return false;
    }
    final r = _norm(role);
    final uid = (currentUserId ?? '').trim();
    if (r == ProductionAccessHelper.roleSuperAdmin ||
        r == ProductionAccessHelper.roleAdmin) {
      return true;
    }
    return r == ProductionAccessHelper.roleProjectManager &&
        uid.isNotEmpty &&
        uid == project.projectManagerId;
  }

  /// Agregirani KPI portfelja na listi — development engineer vidi samo ako je na projektu (kad je [project] zadan).
  static bool canViewDevelopmentPortfolioKpi({
    required String? role,
    DevelopmentProjectModel? project,
    String? userId,
  }) {
    final r = _norm(role);
    final uid = (userId ?? '').trim();

    if (project == null || uid.isEmpty) {
      if (r == ProductionAccessHelper.roleDevelopmentEngineer) return false;
      return ProductionAccessHelper.canView(
        role: r,
        card: ProductionDashboardCard.developmentGovernance,
      );
    }

    if (r == ProductionAccessHelper.roleManagementViewer) return true;
    if (r == ProductionAccessHelper.roleDevelopmentEngineer) {
      return isUserOnProjectTeam(project, uid);
    }
    return ProductionAccessHelper.canView(
      role: r,
      card: ProductionDashboardCard.developmentGovernance,
    );
  }

  /// Mutacije unutar projekta (Task, Gate dokumentacija, …) — kasnije Callable; UI gate.
  static bool canEditProjectOperationalData({
    required String? role,
    required DevelopmentProjectModel project,
    String? userId,
  }) {
    final r = _norm(role);
    if (r == ProductionAccessHelper.roleSuperAdmin ||
        r == ProductionAccessHelper.roleAdmin) {
      return true;
    }
    if (ProductionAccessHelper.canManage(
          role: r,
          card: ProductionDashboardCard.developmentGovernance,
        )) {
      return true;
    }
    final uid = (userId ?? '').trim();
    if (uid.isEmpty) return false;
    for (final m in project.team) {
      if (m.userId == uid && m.canEditTasks) return true;
    }
    return project.projectManagerId == uid;
  }

  /// Gate odobrenja — Callable autoritativan; UI pomaže s [DevelopmentProjectTeamMember.canApproveGate].
  static bool canApproveGateUiHint({
    required String? role,
    required DevelopmentProjectModel project,
    String? userId,
  }) {
    final r = _norm(role);
    if (r == ProductionAccessHelper.roleSuperAdmin ||
        r == ProductionAccessHelper.roleAdmin) {
      return true;
    }
    final uid = (userId ?? '').trim();
    if (uid.isEmpty) return false;
    if (project.projectManagerId == uid) return true;
    for (final m in project.team) {
      if (m.userId == uid && m.canApproveGate) return true;
    }
    return false;
  }
}
