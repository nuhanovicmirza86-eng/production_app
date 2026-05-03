import '../../../core/access/production_access_helper.dart';
import '../../../core/saas/production_module_keys.dart';
import '../models/development_project_model.dart';
import '../models/development_project_team_member.dart';
import 'development_permissions.dart';

/// Jedna redak u referentnom pregledu dozvola (super admin).
class DevelopmentModulePermissionRow {
  const DevelopmentModulePermissionRow({
    required this.capability,
    required this.where,
    required this.allowed,
  });

  final String capability;
  final String where;
  final bool allowed;
}

/// Izračun dozvola modula Razvoj po ulozi — isti izvori kao [DevelopmentPermissions].
abstract final class DevelopmentModulePermissionsCatalog {
  static const String _probePm = '__dev_probe_pm__';
  static const String _probeDe = '__dev_probe_de__';
  static const String _probeQc = '__dev_probe_qc__';
  static const String _probePeer = '__dev_probe_peer__';

  static DevelopmentProjectModel _probeProject() {
    final team = <DevelopmentProjectTeamMember>[
      const DevelopmentProjectTeamMember(
        userId: _probeDe,
        displayName: '',
        projectRole: '',
        systemRole: 'development_engineer',
        canEditTasks: true,
        canUploadDocuments: false,
        canApproveGate: false,
      ),
      const DevelopmentProjectTeamMember(
        userId: _probeQc,
        displayName: '',
        projectRole: '',
        systemRole: 'quality_control',
        canEditTasks: false,
        canUploadDocuments: false,
        canApproveGate: true,
      ),
    ];
    final ids = <String>{_probePm, _probeDe, _probeQc};
    return DevelopmentProjectModel(
      id: '_probe',
      companyId: 'c',
      plantKey: 'p',
      businessYearId: '',
      businessYearLabel: '',
      businessQuarter: '',
      businessMonth: '',
      projectCode: '',
      projectName: '',
      projectType: '',
      projectManagerId: _probePm,
      projectManagerName: '',
      team: team,
      teamMemberIds: ids.toList(),
      status: '',
      currentGate: '',
      currentStage: '',
      priority: '',
      riskLevel: '',
      currency: 'EUR',
      strategicImportance: '',
      progressPercent: 0,
      kpi: DevelopmentProjectKpi.empty(),
      ai: DevelopmentProjectAi.empty(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      createdBy: '',
      createdByName: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedBy: '',
    );
  }

  /// Redovi za jednu ulogu i entitlemente trenutne kompanije ([companyData]).
  static List<DevelopmentModulePermissionRow> rowsForRole({
    required String roleCode,
    required Map<String, dynamic> companyData,
  }) {
    final r = ProductionAccessHelper.normalizeRole(roleCode);
    final cd = companyData;
    final probe = _probeProject();
    final hasDevMod =
        ProductionModuleKeys.hasModule(cd, ProductionModuleKeys.development);
    final viewCard = ProductionAccessHelper.canView(
      role: r,
      card: ProductionDashboardCard.developmentGovernance,
    );
    final manageCard = ProductionAccessHelper.canManage(
      role: r,
      card: ProductionDashboardCard.developmentGovernance,
    );

    bool b(bool Function() fn) => hasDevMod && fn();

    return [
      DevelopmentModulePermissionRow(
        capability: 'Pretplata: modul „development” u ovoj kompaniji',
        where: 'Firestore entitlements (ovaj tenant)',
        allowed: hasDevMod,
      ),
      DevelopmentModulePermissionRow(
        capability: 'Ulaz u modul (navigacija, lista projekata)',
        where: 'Donja traka / izbornik „Razvoj”',
        allowed: hasDevMod && viewCard,
      ),
      DevelopmentModulePermissionRow(
        capability: 'Upravljanje portfeljem (MVP struktura kartice)',
        where: 'Matrica pristupa — developmentGovernance',
        allowed: hasDevMod && manageCard,
      ),
      DevelopmentModulePermissionRow(
        capability: 'Novi projekat (Callable createDevelopmentProject)',
        where: 'Lista projekata — FAB',
        allowed: b(() => DevelopmentPermissions.canCreateDevelopmentProject(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Jezgra projekta (Callable updateDevelopmentProject)',
        where: 'Detalj projekta — uređivanje',
        allowed: b(() => DevelopmentPermissions.canEditDevelopmentProjectCore(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Zadaci (tasks)',
        where: 'Detalj projekta — zadaci',
        allowed: b(() => DevelopmentPermissions.canMutateDevelopmentTasks(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Rizici (risks)',
        where: 'Detalj projekta — rizici',
        allowed: b(() => DevelopmentPermissions.canMutateDevelopmentRisks(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Zahtjevi za odobrenje — predlaganje / uređivanje',
        where: 'Detalj projekta — odobrenja',
        allowed: b(() => DevelopmentPermissions.canMutateDevelopmentApprovals(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Odluka na zahtjevu (odobri / odbij)',
        where: 'Detalj projekta — odobrenja',
        allowed: b(() => DevelopmentPermissions.canDecideDevelopmentApproval(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Povlačenje tuđeg pending zahtjeva',
        where: 'Detalj projekta — odobrenja',
        allowed: b(() => DevelopmentPermissions.canWithdrawDevelopmentApproval(
              role: r,
              companyData: cd,
              createdByUid: _probePeer,
              currentUserId: _probePm,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Inženjerske izmjene (changes)',
        where: 'Detalj projekta — izmjene',
        allowed: b(() => DevelopmentPermissions.canMutateDevelopmentChanges(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Faze Stage-Gate (stages)',
        where: 'Detalj projekta — faze',
        allowed: b(() => DevelopmentPermissions.canMutateDevelopmentStages(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Dokumenti projekta (documents)',
        where: 'Detalj projekta — dokumenti',
        allowed: b(() => DevelopmentPermissions.canMutateDevelopmentDocuments(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Inicijalizacija faza ako prazno (Callable seed…)',
        where: 'Detalj projekta — faze',
        allowed: b(() => DevelopmentPermissions.canSeedDevelopmentStages(
              role: r,
              companyData: cd,
              project: probe,
              currentUserId: _probePm,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'AI sažetak projekta (Callable runDevelopmentProjectAiAnalysis)',
        where: 'Detalj projekta — AI',
        allowed: b(() => DevelopmentPermissions.canRunDevelopmentProjectAi(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Provjera spremnosti za release',
        where: 'Detalj projekta — spremnost',
        allowed: b(() => DevelopmentPermissions.canCheckDevelopmentReleaseReadiness(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Launch Intelligence (Callable getDevelopmentProjectLaunchIntelligence)',
        where: 'Detalj projekta — tab Launch Intelligence',
        allowed: b(() => DevelopmentPermissions.canCheckDevelopmentReleaseReadiness(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Zapis release u proizvodnju',
        where: 'Detalj projekta — spremnost (Callable recordDevelopmentProjectReleaseToProduction)',
        allowed: b(() => DevelopmentPermissions.canRecordDevelopmentReleaseToProduction(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Formalno zatvaranje projekta (status closed)',
        where: 'Detalj projekta — Callable closeDevelopmentProject',
        allowed: b(() => DevelopmentPermissions.canCloseDevelopmentProject(
              role: r,
              companyData: cd,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Zamjena tima (admin / SaaS ili voditelj)',
        where: 'Detalj / Tim — Callable replaceDevelopmentProjectTeam',
        allowed: b(() =>
            DevelopmentPermissions.canEditDevelopmentProjectTeam(
              role: r,
              companyData: cd,
              project: probe,
              currentUserId: _probePm,
            ) ||
            DevelopmentPermissions.canEditDevelopmentProjectTeam(
              role: r,
              companyData: cd,
              project: probe,
              currentUserId: _probePeer,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'Operativni podaci (član tima s canEditTasks / PM)',
        where: 'Detalj projekta — pomoćna matrica',
        allowed: b(() => DevelopmentPermissions.canEditProjectOperationalData(
              role: r,
              project: probe,
              userId: _probeDe,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'UI nagovještaj: tko može „odobriti gate” na timu',
        where: 'Detalj projekta — faze / odobrenja',
        allowed: b(() => DevelopmentPermissions.canApproveGateUiHint(
              role: r,
              project: probe,
              userId: _probeQc,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'KPI na kartici projekta (lista — bez članstva)',
        where: 'Lista projekata',
        allowed: b(() => DevelopmentPermissions.canViewDevelopmentPortfolioKpi(
              role: r,
              project: null,
              userId: _probeDe,
            )),
      ),
      DevelopmentModulePermissionRow(
        capability: 'KPI za inženjera razvoja (samo ako je na timu)',
        where: 'Lista projekata — simulacija člana tima',
        allowed: b(() => DevelopmentPermissions.canViewDevelopmentPortfolioKpi(
              role: r,
              project: probe,
              userId: _probeDe,
            )),
      ),
    ];
  }
}
