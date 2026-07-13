import '../saas/production_module_keys.dart';

enum ProductionDashboardCard {
  products,
  productionOrders,
  productionTracking,
  stationPages,
  workCenters,
  /// MES šifrarnik standardnih procesa (odvojeno od routingu).
  productionProcesses,
  shifts,
  downtime,
  /// OOE / OEE — live stanje, gubici, agregati smjene (dogasci + summary).
  ooe,
  /// Operonix Analytics (MES BI) — rukovodstvena analitika; odvojeno od [ooe] da operater ne vidi isti ekran.
  operonixAnalytics,
  problemReporting,
  processExecution,
  reports,
  registrations,
  carbonFootprint,

  /// SaaS modul `development`: NPI / Stage-Gate / portfolio (tenant + pogon + poslovna godina).
  developmentGovernance,

  /// SaaS modul `quality`: QMS (kontrolni plan, kontrole, NCR, CAPA).
  qualityManagement,

  /// SaaS modul [ProductionModuleKeys.aiAssistant]: OperonixAI (chat + operativni asistent).
  aiAssistant,

  /// Personal: obračun radnog vremena (LAN/gateway → events → daily → monthly) — ne miješati s MES/OOE.
  personalWorkTime,

  /// SaaS modul Finance & Controlling (`finance_controlling` / `finance_integrations`): troškovi, KPI, ERP sync.
  financeControlling,

  /// Operonix APS — Napredno planiranje (scenariji, Gantt, optimizacija).
  advancedPlanning,
}

enum ProductionAccessLevel { hidden, view, manage }

/// Hub bez serijske proizvodnje: Razvoj/NPI, Finance (pregled), AI Asistent.
///
/// [developmentLevel]: [ProductionAccessLevel.manage] za voditelja projekta (portfelj, FAB);
/// [ProductionAccessLevel.view] za inženjera razvoja (`development_engineer`).
Map<ProductionDashboardCard, ProductionAccessLevel> _accessNpiEngineeringHub(
  ProductionAccessLevel developmentLevel,
) {
  return {
    for (final c in ProductionDashboardCard.values)
      c: c == ProductionDashboardCard.developmentGovernance
          ? developmentLevel
          : c == ProductionDashboardCard.financeControlling ||
                  c == ProductionDashboardCard.aiAssistant
              ? ProductionAccessLevel.view
              : ProductionAccessLevel.hidden,
  };
}

/// Quality manager (`quality_control`): uvid u proizvodnju, analitiku/energiju (održavanje), Razvoj, Finance i pun QMS hub.
Map<ProductionDashboardCard, ProductionAccessLevel> _accessQualityManagerHub() {
  return {
    ProductionDashboardCard.products: ProductionAccessLevel.view,
    ProductionDashboardCard.productionOrders: ProductionAccessLevel.view,
    ProductionDashboardCard.productionTracking: ProductionAccessLevel.view,
    ProductionDashboardCard.stationPages: ProductionAccessLevel.view,
    ProductionDashboardCard.workCenters: ProductionAccessLevel.view,
    ProductionDashboardCard.productionProcesses: ProductionAccessLevel.view,
    ProductionDashboardCard.shifts: ProductionAccessLevel.view,
    ProductionDashboardCard.downtime: ProductionAccessLevel.view,
    ProductionDashboardCard.ooe: ProductionAccessLevel.view,
    ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.view,
    ProductionDashboardCard.problemReporting: ProductionAccessLevel.view,
    ProductionDashboardCard.processExecution: ProductionAccessLevel.view,
    ProductionDashboardCard.reports: ProductionAccessLevel.view,
    ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
    ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.view,
    ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.view,
    ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
    ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
    ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
    ProductionDashboardCard.financeControlling: ProductionAccessLevel.view,
    ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
  };
}

/// Pristup ekranima u Production appu.
///
/// **Uloga** = vrijednost `users.role` (string) u Firestoreu. Ispod su **kanonske** uloge koje ovaj helper
/// eksplicitno poznaje. Uključuju i NPI uloge za modul **development** (`project_manager`, …) —
/// dodjela u Firestoreu mora ići kroz tenant / Super admin (vidi kanonski MD Development modula).
/// U [displayRoleLabel] su fiksni prikazi gdje je dogovoreno; inače sirovi kôd.
class ProductionAccessHelper {
  const ProductionAccessHelper._();

  static const String roleProductionOperator = 'production_operator';
  static const String roleProductionManager = 'production_manager';

  /// Vođa smjene / linije — operativni nadzor (ispod menadžera proizvodnje). Kanonski `users.role`: `shift_lead`.
  static const String roleShiftLead = 'shift_lead';

  /// Voditelj projekta (NPI / Stage-Gate) — **nije** isto što i menadžer proizvodnje.
  static const String roleProjectManager = 'project_manager';

  /// Razvoj / inženjering u NPI toku (operativni sloj bez kreiranja projekta na portfelju).
  static const String roleDevelopmentEngineer = 'development_engineer';

  /// Read-only menadžmentski pregled (KPI / AI u Razvoju, bez operativnih mutacija u UI).
  static const String roleManagementViewer = 'management_viewer';
  static const String roleLogisticsManager = 'logistics_manager';
  static const String roleMaintenanceManager = 'maintenance_manager';
  static const String roleAdmin = 'admin';

  /// [quality_operator] — QMS ekrani.
  static const String roleQualityOperator = 'quality_operator';

  /// Quality manager (NPI / reviewer) — kanonski string u bazi: `quality_control`; legacy `quality_engineer` → [normalizeRole].
  static const String roleQualityControl = 'quality_control';

  /// Vlasnik projekta (SaaS) — izvan scopea pojedine kompanije u smislu `admin`.
  static const String roleSuperAdmin = 'super_admin';

  /// Modul Finance & Controlling (`finance_controlling` / `finance_integrations`).
  static const String roleAccountingManager = 'accounting_manager';

  /// Referent računovodstva — unos/provjera (Finance & Controlling).
  static const String roleAccountingClerk = 'accounting_clerk';

  /// Laboratorij / procesne evidencije — menadžer pogona (Production app).
  static const String roleLaboratoryManager = 'laboratory_manager';

  /// Laboratorij / procesne evidencije — tehničar (Production app).
  static const String roleLaboratoryTechnician = 'laboratory_technician';

  /// Uloge koje Admin može dodijeliti operativnoj evidenciji (runtimeAllowedRoles).
  static const List<String> profileStationRuntimeAssignableRoles = [
    roleProductionOperator,
    roleShiftLead,
    roleQualityControl,
    roleProductionManager,
    'logistics_operator',
    roleLogisticsManager,
    roleMaintenanceManager,
    roleLaboratoryManager,
    roleLaboratoryTechnician,
  ];

  /// Kanonski kod uloge; legacy aliasi se mapiraju na jednu ulogu (npr. `administrator` → [roleAdmin]).
  static String normalizeRole(dynamic role) {
    var r = (role ?? '').toString().trim().toLowerCase();
    if (r == 'superadmin' ||
        r == 'super-admin' ||
        r == 'super admin') {
      r = roleSuperAdmin;
    }
    if (r == 'manager') {
      r = roleMaintenanceManager;
    }
    if (r == 'administrator' ||
        r == 'company_admin' ||
        r == 'company-admin') {
      r = roleAdmin;
    }
    if (r == 'quality_engineer') {
      r = roleQualityControl;
    }
    // Povijesni string u `users.role` (zastarjelo) — kanonski kod je [roleProductionManager].
    if (r == 'supervisor') {
      r = roleProductionManager;
    }
    if (r == 'shift-lead' || r == 'shift lead') {
      r = roleShiftLead;
    }
    return r;
  }

  /// Tekst za prikaz u UI (npr. „Uloga: …”). Za tenant admin uvijek tačno **„Admin”**
  /// (nikad „Administrator” ili sirovi kod iz baze).
  /// [roleQualityOperator] = **Operater kvaliteta** (fiksno).
  static String displayRoleLabel(dynamic role) {
    final s = (role ?? '').toString().trim().toLowerCase();
    if (s == 'admin' ||
        s == 'administrator' ||
        s == 'company_admin' ||
        s == 'company-admin') {
      return 'Admin';
    }
    if (isAdminRole(s)) {
      return 'Admin';
    }
    final r = normalizeRole(role);
    if (r == roleAdmin) {
      return 'Admin';
    }
    switch (r) {
      case roleSuperAdmin:
        return 'Super admin';
      case roleProductionManager:
        return 'Menadžer proizvodnje';
      case roleShiftLead:
        return 'Vođa smjene / linije';
      case roleLogisticsManager:
        return 'Menadžer logistike';
      case roleProductionOperator:
        return 'Operater proizvodnje';
      case roleQualityOperator:
        return 'Operater kvaliteta';
      case roleQualityControl:
        return 'Quality manager';
      case roleMaintenanceManager:
        return 'Menadžer održavanja';
      case roleProjectManager:
        return 'Voditelj projekta';
      case roleDevelopmentEngineer:
        return 'Inženjer razvoja';
      case roleManagementViewer:
        return 'Menadžment (pregled)';
      case roleAccountingManager:
        return 'Šef računovodstva';
      case roleAccountingClerk:
        return 'Referent računovodstva';
      case roleLaboratoryManager:
        return 'Laboratorijski menadžer';
      case roleLaboratoryTechnician:
        return 'Laboratorijski tehničar';
      default:
        return r.isEmpty ? '-' : r;
    }
  }

  static ProductionAccessLevel getAccess({
    required String role,
    required ProductionDashboardCard card,
  }) {
    final normalizedRole = normalizeRole(role);

    final roleMap = _roleMatrix[normalizedRole];
    if (roleMap == null) {
      return ProductionAccessLevel.hidden;
    }

    return roleMap[card] ?? ProductionAccessLevel.hidden;
  }

  static bool canView({
    required String role,
    required ProductionDashboardCard card,
  }) {
    final access = getAccess(role: role, card: card);
    return access == ProductionAccessLevel.view ||
        access == ProductionAccessLevel.manage;
  }

  static bool canManage({
    required String role,
    required ProductionDashboardCard card,
  }) {
    return getAccess(role: role, card: card) == ProductionAccessLevel.manage;
  }

  static bool hasAnyReports(Map<String, dynamic> companyData) {
    final enabledReports = _readStringList(companyData['enabledReports']);
    final addonReports = _readStringList(companyData['addonReports']);
    final disabledReports = _readStringList(companyData['disabledReports']);

    final effective = <String>{...enabledReports, ...addonReports}
      ..removeAll(disabledReports);

    return effective.isNotEmpty;
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static final Map<String, Map<ProductionDashboardCard, ProductionAccessLevel>>
  _roleMatrix = {
    roleProductionOperator: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.view,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      /// Zastoji: prijava na podu; IATF verifikacija zatvaranja: admin / menadžer proizvodnje / super admin.
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      /// Live OOE pregled (bez uređivanja kataloga razloga).
      ProductionDashboardCard.ooe: ProductionAccessLevel.view,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      /// Hub „Evidencija procesa“ je za menadžment; operater i dalje ulazi u izvršenje iz detalja naloga.
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      /// Izvještaji: operater na podu ih ne vidi; menadžer proizvodnje u svojoj matrici.
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.hidden,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleShiftLead: {
      /// Pregled linije/smjene: bez QMS/Personal modula u Productionu (to ostaje PM, kvaliteta).
      /// AI: osnovni sloj; bez Operonix Analytics / izvještaja.
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.view,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.view,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.view,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.view,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.view,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.ooe: ProductionAccessLevel.view,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.view,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.hidden,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleProductionManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.ooe: ProductionAccessLevel.manage,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.view,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.manage,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.manage,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.view,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.manage,
    },
    roleProjectManager:
        _accessNpiEngineeringHub(ProductionAccessLevel.manage),
    roleDevelopmentEngineer:
        _accessNpiEngineeringHub(ProductionAccessLevel.view),
    roleManagementViewer: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.hidden,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.view,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.view,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.view,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleLogisticsManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.hidden,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.view,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.view,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.view,
      /// OperonixAI (narudžbe, rokovi) — usklađeno s Callable [productionTrackingAssistant].
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.view,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleAdmin: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.ooe: ProductionAccessLevel.manage,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.manage,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.manage,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.manage,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.manage,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.manage,
    },
    roleSuperAdmin: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.ooe: ProductionAccessLevel.manage,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.manage,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.manage,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.manage,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.manage,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.manage,
    },
    roleMaintenanceManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.hidden,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.view,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.view,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      /// Kontekst proizvodnje (bez RN kvarova — oni su u Maintenance app).
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.view,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleQualityOperator: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.view,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.view,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.view,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.view,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.hidden,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleAccountingManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.hidden,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.hidden,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.manage,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleAccountingClerk: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.hidden,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.hidden,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.view,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleQualityControl: _accessQualityManagerHub(),
    roleLaboratoryManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.view,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.view,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.hidden,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
    roleLaboratoryTechnician: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.view,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.ooe: ProductionAccessLevel.hidden,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.financeControlling: ProductionAccessLevel.hidden,
      ProductionDashboardCard.advancedPlanning: ProductionAccessLevel.hidden,
    },
  };

  /// Uloge koje imaju zapis u [_roleMatrix], stabilnim redom (referentni ekrani).
  static List<String> allMatrixRolesSorted() {
    const priority = <String>[
      roleSuperAdmin,
      roleAdmin,
      roleAccountingManager,
      roleAccountingClerk,
      roleProjectManager,
      roleDevelopmentEngineer,
      roleManagementViewer,
      roleProductionManager,
      roleShiftLead,
      roleLaboratoryManager,
      roleLaboratoryTechnician,
      roleProductionOperator,
      roleQualityOperator,
      roleQualityControl,
      roleManagementViewer,
      roleLogisticsManager,
      roleMaintenanceManager,
    ];
    final remaining = _roleMatrix.keys.toSet();
    final out = <String>[];
    for (final r in priority) {
      if (remaining.remove(r)) out.add(r);
    }
    final tail = remaining.toList()..sort();
    out.addAll(tail);
    return out;
  }

  static bool isAdminRole(String role) {
    return normalizeRole(role) == roleAdmin;
  }

  static bool isSuperAdminRole(String role) {
    return normalizeRole(role) == roleSuperAdmin;
  }

  /// Tenant / modul uloge koje po defaultu rade na nivou **kompanije** (admin, financije, NPI/razvoj,
  /// voditelj kvaliteta/QMS),
  /// ne na jednom pogonu: [plantKey] u profilu i u Callable payloadu **nije obavezan** osim kad je
  /// eksplicitno potreban pogon (npr. ORV fokus). Ako se [plantKey] pošalje, kontekst se filtrira na pogon.
  ///
  /// Kanonski kodovi: [roleAdmin] (uključujući legacy `company_admin` → normalizacija), [roleSuperAdmin],
  /// [roleAccountingManager], [roleAccountingClerk], [roleProjectManager], [roleDevelopmentEngineer],
  /// [roleQualityControl].
  ///
  /// Usklađeno s backend [isCompanyWideContextRole] (`production_callable_helpers.js`).
  static bool isCompanyWideContextRole(dynamic roleRaw) {
    final r = normalizeRole(roleRaw);
    if (r == roleSuperAdmin) return true;
    if (isAdminRole(r)) return true;
    return r == roleAccountingManager ||
        r == roleAccountingClerk ||
        r == roleProjectManager ||
        r == roleDevelopmentEngineer ||
        r == roleQualityControl;
  }

  /// Usklađeno s backend [canUseProductionAssistant] (`production_callable_helpers.js`).
  ///
  /// Vođa smjene nema Callable operativnog asistenta nad podacima praćenja; u hubu ostaje
  /// samo osnovni AI razgovor (kad je pretplata dopušta).
  static bool canUseOperationalProductionAssistant(dynamic roleRaw) {
    final r = normalizeRole(roleRaw);
    return isCompanyWideContextRole(r) ||
        r == roleProductionManager ||
        r == 'supervisor' ||
        r == roleProductionOperator ||
        r == roleLogisticsManager ||
        r == roleMaintenanceManager;
  }

  /// [companyData] kao u Production sesiji: `role` na korijenu; inače `userAppAccess.role`.
  static String rawRoleFromCompanySession(Map<String, dynamic> companyData) {
    final root = (companyData['role'] ?? '').toString().trim();
    if (root.isNotEmpty) return root;
    final aa = companyData['userAppAccess'];
    if (aa is Map) {
      final ar = (aa['role'] ?? '').toString().trim();
      if (ar.isNotEmpty) return ar;
    }
    return '';
  }

  static bool isSuperAdminFromCompanySession(Map<String, dynamic> companyData) {
    return isSuperAdminRole(rawRoleFromCompanySession(companyData));
  }

  static bool canUseProfileStationRuntime(String role) {
    final r = normalizeRole(role);
    if (r == roleSuperAdmin || isAdminRole(r)) return true;
    return profileStationRuntimeAssignableRoles.contains(r);
  }

  static bool isMaintenanceManagerRole(String role) {
    return normalizeRole(role) == roleMaintenanceManager;
  }

  /// IATF: potvrda zatvaranja zastoja — ne samo „klik“ od strane operatera.
  /// Ne uključuje operativne uloge bez menadžerske ovlasti (npr. [roleQualityOperator]).
  static bool canVerifyDowntime(String role) {
    final r = normalizeRole(role);
    return r == roleProductionManager ||
        r == roleAdmin ||
        r == roleSuperAdmin;
  }

  /// Ručne boje ekrana stanica (praćenje) — samo [roleAdmin] ili [roleSuperAdmin].
  static bool canEditStationScreenCustomColors(String role) {
    final r = normalizeRole(role);
    return r == roleAdmin || r == roleSuperAdmin;
  }

  /// M2-C — read-only pregled zatvorenih profile-driven evidencija (supervizija).
  static bool canViewProfileDrivenEvidence(String role) {
    final r = normalizeRole(role);
    return r == roleSuperAdmin ||
        isAdminRole(r) ||
        r == roleProductionManager ||
        r == roleLaboratoryManager ||
        r == roleLaboratoryTechnician ||
        r == roleQualityControl;
  }

  /// Filter pogona na listi evidencija — samo [roleAdmin] / [roleSuperAdmin].
  static bool canPickPlantFilterForProfileDrivenEvidence(String role) {
    final r = normalizeRole(role);
    return r == roleSuperAdmin || isAdminRole(r);
  }

  /// APS P0+ — pregled (samo uloga; modul kompanije provjeri zasebno).
  /// Kanonske uloge: [roleAdmin], [roleSuperAdmin], [roleProductionManager].
  static bool canViewAps(String role) {
    final r = normalizeRole(role);
    return r == roleSuperAdmin ||
        r == roleAdmin ||
        r == roleProductionManager;
  }

  /// APS P0 — create/update master data (**samo uloga**).
  /// Modul `advanced_planning` na kompaniji provjeri s [canAccessApsP0Callable].
  static bool canManageApsMasterData(String role) {
    final r = normalizeRole(role);
    return r == roleSuperAdmin || r == roleAdmin || r == roleProductionManager;
  }

  /// APS P0 Callable pristup = **oba** uslova: modul kompanije + uloga.
  /// `advanced_planning` je entitlement, **ne** `users.role`.
  static bool canAccessApsP0Callable({
    required String role,
    required Map<String, dynamic> companyData,
  }) {
    return ProductionModuleKeys.hasAdvancedPlanningModule(companyData) &&
        canManageApsMasterData(role);
  }

  /// APS P1 Callable pristup = modul + uloga (P0 gate + `aps_scenario_planning`).
  static bool canAccessApsP1Callable({
    required String role,
    required Map<String, dynamic> companyData,
  }) {
    return ProductionModuleKeys.hasApsScenarioPlanningModule(companyData) &&
        canManageApsMasterData(role);
  }

  /// APS P6 Callable pristup = P1 gate + add-on `aps_ai_assistant`.
  static bool canAccessApsP6Callable({
    required String role,
    required Map<String, dynamic> companyData,
  }) {
    return ProductionModuleKeys.hasApsAiAssistantModule(companyData) &&
        canAccessApsP1Callable(role: role, companyData: companyData);
  }

  /// APS P4+ — odobrenje scenarija i release u MES (uloga; modul kao gore).
  static bool canApproveApsRelease(String role) {
    final r = normalizeRole(role);
    return r == roleSuperAdmin || r == roleAdmin || r == roleProductionManager;
  }
}
