enum ProductionDashboardCard {
  products,
  productionOrders,
  productionTracking,
  stationPages,
  workCenters,
  shifts,
  downtime,
  problemReporting,
  processExecution,
  reports,
  registrations,
  carbonFootprint,

  /// SaaS modul `quality`: QMS (kontrolni plan, inspekcije, NCR, CAPA).
  qualityManagement,

  /// SaaS modul [ProductionModuleKeys.aiAssistant]: OperonixAI (chat + operativni asistent).
  aiAssistant,
}

enum ProductionAccessLevel { hidden, view, manage }

class ProductionAccessHelper {
  const ProductionAccessHelper._();

  static const String roleProductionOperator = 'production_operator';
  static const String roleSupervisor = 'supervisor';
  static const String roleProductionManager = 'production_manager';
  static const String roleLogisticsManager = 'logistics_manager';
  static const String roleMaintenanceManager = 'maintenance_manager';
  static const String roleAdmin = 'admin';

  /// Operater / kontrolor kvaliteta (QMS ekrani).
  static const String roleQualityOperator = 'quality_operator';

  /// Vlasnik projekta (SaaS) — izvan scopea pojedine kompanije u smislu `admin`.
  static const String roleSuperAdmin = 'super_admin';

  /// Kanonski kod uloge; legacy aliasi se mapiraju na jednu ulogu (npr. `administrator` → [roleAdmin]).
  static String normalizeRole(dynamic role) {
    var r = (role ?? '').toString().trim().toLowerCase();
    if (r == 'manager') {
      r = roleMaintenanceManager;
    }
    if (r == 'administrator' ||
        r == 'company_admin' ||
        r == 'company-admin') {
      r = roleAdmin;
    }
    return r;
  }

  /// Tekst za prikaz u UI (npr. „Uloga: …”). Za tenant admin uvijek tačno **„Admin”**
  /// (nikad „Administrator” ili sirovi kod iz baze).
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
      case roleSupervisor:
        return 'Supervizor';
      case roleProductionOperator:
        return 'Operater proizvodnje';
      case roleQualityOperator:
        return 'Operater kvaliteta';
      case roleMaintenanceManager:
        return 'Menadžer održavanja';
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

  static const Map<String, Map<ProductionDashboardCard, ProductionAccessLevel>>
  _roleMatrix = {
    roleProductionOperator: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.view,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      /// MVP: zasebni dashboard ekran za zastoje još nije isporučen — operater koristi praćenje / nalog.
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      /// MVP: „Evidencija procesa“ kao zaseban tab još nije isporučen — operater koristi detalj naloga → execution.
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      /// Operater na podu: praćenje i nalozi; analitički hub (Izvještaji) ostaje menadžeru / supervizoru.
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
    },
    roleSupervisor: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.view,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.view,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.view,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
    },
    roleProductionManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.manage,
    },
    roleLogisticsManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.view,
      /// OperonixAI (narudžbe, rokovi) — usklađeno s Callable [productionTrackingAssistant].
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
    },
    roleAdmin: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.manage,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.manage,
    },
    roleSuperAdmin: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.manage,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.manage,
    },
    roleMaintenanceManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.hidden,
      /// Kontekst proizvodnje (bez RN kvarova — oni su u Maintenance app).
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
    },
    roleQualityOperator: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.view,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.stationPages: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.view,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
      ProductionDashboardCard.qualityManagement: ProductionAccessLevel.manage,
      ProductionDashboardCard.aiAssistant: ProductionAccessLevel.view,
    },
  };

  static bool isAdminRole(String role) {
    return normalizeRole(role) == roleAdmin;
  }

  static bool isSuperAdminRole(String role) {
    return normalizeRole(role) == roleSuperAdmin;
  }

  static bool isMaintenanceManagerRole(String role) {
    return normalizeRole(role) == roleMaintenanceManager;
  }

  /// Ručne boje ekrana stanica (praćenje) — samo [roleAdmin] ili [roleSuperAdmin].
  static bool canEditStationScreenCustomColors(String role) {
    final r = normalizeRole(role);
    return r == roleAdmin || r == roleSuperAdmin;
  }
}
