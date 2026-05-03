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
}

enum ProductionAccessLevel { hidden, view, manage }

/// Pristup samo hubu Razvoj / NPI (sve ostale kartice skrivene).
Map<ProductionDashboardCard, ProductionAccessLevel> _accessDevelopmentHubOnly(
  ProductionAccessLevel developmentLevel,
) {
  return {
    for (final c in ProductionDashboardCard.values)
      c: c == ProductionDashboardCard.developmentGovernance
          ? developmentLevel
          : ProductionAccessLevel.hidden,
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

  /// Kontrola kvaliteta / reviewer u NPI toku — u bazi može i `quality_engineer` (mapira se u [normalizeRole]).
  static const String roleQualityControl = 'quality_control';

  /// Vlasnik projekta (SaaS) — izvan scopea pojedine kompanije u smislu `admin`.
  static const String roleSuperAdmin = 'super_admin';

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
      case roleLogisticsManager:
        return 'Menadžer logistike';
      case roleProductionOperator:
        return 'Operater proizvodnje';
      case roleQualityOperator:
        return 'Operater kvaliteta';
      case roleQualityControl:
        return 'Kontrola kvaliteta';
      case roleMaintenanceManager:
        return 'Menadžer održavanja';
      case roleProjectManager:
        return 'Voditelj projekta';
      case roleDevelopmentEngineer:
        return 'Inženjer razvoja';
      case roleManagementViewer:
        return 'Menadžment (pregled)';
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
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.view,
    },
    roleProjectManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.view,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.view,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.ooe: ProductionAccessLevel.manage,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.view,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.manage,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.view,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
    },
    roleDevelopmentEngineer: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.view,
      ProductionDashboardCard.productionProcesses: ProductionAccessLevel.view,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.ooe: ProductionAccessLevel.manage,
      ProductionDashboardCard.operonixAnalytics: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.view,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.view,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.view,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
    },
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
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.view,
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
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.manage,
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
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.view,
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
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.view,
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
      ProductionDashboardCard.developmentGovernance: ProductionAccessLevel.view,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
      ProductionDashboardCard.personalWorkTime: ProductionAccessLevel.hidden,
    },
    roleQualityControl:
        _accessDevelopmentHubOnly(ProductionAccessLevel.view),
  };

  /// Uloge koje imaju zapis u [_roleMatrix], stabilnim redom (referentni ekrani).
  static List<String> allMatrixRolesSorted() {
    const priority = <String>[
      roleSuperAdmin,
      roleAdmin,
      roleProjectManager,
      roleProductionManager,
      roleDevelopmentEngineer,
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
}
