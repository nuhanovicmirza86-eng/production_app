enum ProductionDashboardCard {
  products,
  productionOrders,
  productionTracking,
  workCenters,
  shifts,
  downtime,
  problemReporting,
  processExecution,
  reports,
  registrations,
  carbonFootprint,
}

enum ProductionAccessLevel { hidden, view, manage }

class ProductionAccessHelper {
  const ProductionAccessHelper._();

  static const String roleProductionOperator = 'production_operator';
  static const String roleSupervisor = 'supervisor';
  static const String roleProductionManager = 'production_manager';
  static const String roleMaintenanceManager = 'maintenance_manager';
  static const String roleAdmin = 'admin';

  static String normalizeRole(dynamic role) {
    return (role ?? '').toString().trim().toLowerCase();
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
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.view,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
    },
    roleSupervisor: {
      ProductionDashboardCard.products: ProductionAccessLevel.view,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.view,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.view,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.hidden,
    },
    roleProductionManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
    },
    roleAdmin: {
      ProductionDashboardCard.products: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.manage,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.manage,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.manage,
      ProductionDashboardCard.shifts: ProductionAccessLevel.manage,
      ProductionDashboardCard.downtime: ProductionAccessLevel.manage,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.manage,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.manage,
      ProductionDashboardCard.reports: ProductionAccessLevel.manage,
      ProductionDashboardCard.registrations: ProductionAccessLevel.manage,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
    },
    roleMaintenanceManager: {
      ProductionDashboardCard.products: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionOrders: ProductionAccessLevel.hidden,
      ProductionDashboardCard.productionTracking: ProductionAccessLevel.hidden,
      ProductionDashboardCard.workCenters: ProductionAccessLevel.hidden,
      ProductionDashboardCard.shifts: ProductionAccessLevel.hidden,
      ProductionDashboardCard.downtime: ProductionAccessLevel.hidden,
      ProductionDashboardCard.problemReporting: ProductionAccessLevel.hidden,
      ProductionDashboardCard.processExecution: ProductionAccessLevel.hidden,
      ProductionDashboardCard.reports: ProductionAccessLevel.hidden,
      ProductionDashboardCard.registrations: ProductionAccessLevel.hidden,
      ProductionDashboardCard.carbonFootprint: ProductionAccessLevel.manage,
    },
  };

  static bool isAdminRole(String role) {
    return normalizeRole(role) == roleAdmin;
  }

  static bool isMaintenanceManagerRole(String role) {
    return normalizeRole(role) == roleMaintenanceManager;
  }
}
