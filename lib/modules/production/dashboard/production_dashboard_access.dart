import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../core/access/production_access_helper.dart';
import '../../../core/saas/production_module_keys.dart';
import '../../finance_integrations/utils/finance_permissions.dart';
import '../../../core/access/production_maintenance_bridge.dart';

/// RBAC, pretplata i tenant provjere za katalog modula na početnom zaslonu.
class ProductionDashboardAccess {
  final Map<String, dynamic> companyData;
  final String role;
  final String companyId;
  final String plantKey;
  final List<String> enabledModules;

  ProductionDashboardAccess({
    required this.companyData,
    required this.role,
    required this.companyId,
    required this.plantKey,
    required this.enabledModules,
  });

  factory ProductionDashboardAccess.fromCompanyData(
    Map<String, dynamic> companyData,
  ) {
    final modulesRaw = companyData['enabledModules'];
    final modules = modulesRaw is List
        ? modulesRaw.map((e) => e.toString().trim().toLowerCase()).toList()
        : const <String>[];

    return ProductionDashboardAccess(
      companyData: companyData,
      role: ProductionAccessHelper.normalizeRole(companyData['role']),
      companyId: (companyData['companyId'] ?? '').toString().trim(),
      plantKey: (companyData['plantKey'] ?? '').toString().trim(),
      enabledModules: modules,
    );
  }

  bool hasModule(String moduleKey) {
    final normalized = moduleKey.trim().toLowerCase();
    if (enabledModules.isEmpty) {
      return normalized == 'production';
    }
    return enabledModules.contains(normalized);
  }

  bool hasAiProductionAiHubAccess() {
    return ProductionModuleKeys.hasAnyProductionAiHubAccess(companyData);
  }

  bool canAccessMaintenanceFaultBridge() {
    return maintenanceFaultBridgeEnabled(companyData);
  }

  bool canViewCard(ProductionDashboardCard card) {
    return ProductionAccessHelper.canView(role: role, card: card);
  }

  bool canAccessPersonalWorkTime() {
    if (!canViewCard(ProductionDashboardCard.personalWorkTime)) {
      return false;
    }
    if (kDebugMode) return true;
    return ProductionModuleKeys.hasModule(companyData, ProductionModuleKeys.personal);
  }

  bool canAccessFinanceIntegrations() {
    return FinancePermissions.canAccessModule(
      companyData: companyData,
      role: role,
      debugUnlockModule: kDebugMode,
    );
  }

  bool canShowReportsCard() {
    return canViewCard(ProductionDashboardCard.reports);
  }

  bool canAccessOrders() {
    return role == 'admin' ||
        role == 'production_manager' ||
        role == 'sales' ||
        role == 'purchasing' ||
        role == 'logistics_manager';
  }

  bool canAccessPartners() {
    return role == 'admin' ||
        role == 'production_manager' ||
        role == 'sales' ||
        role == 'purchasing' ||
        role == 'logistics_manager';
  }

  bool canAccessCentralWarehouse() {
    return role == 'admin' ||
        role == 'production_manager' ||
        role == 'purchasing' ||
        role == 'logistics_operator' ||
        role == 'logistics_manager';
  }

  bool canConfigureStationDevice() {
    return ProductionAccessHelper.isAdminRole(role);
  }

  String logisticsSectionSubtitle() {
    if (hasModule('logistics')) {
      return 'Pretplata uključuje modul „logistics“. Centralni hub, skladište, prijem kutija (ovisno o ulozi).';
    }
    return 'Centralni magacin / Hub nije dostupan bez modula „logistics“ u pretplati. Ostale kartice ovise o ulozi.';
  }

  String packedBoxesPendingNotice(int count) {
    if (count == 1) return '1 nova kutija čeka prijem';
    if (count >= 2 && count <= 4) return '$count nove kutije čekaju prijem';
    return '$count novih kutija čeka prijem';
  }

  bool get showProductionModuleSections {
    return hasModule('production') || hasModule('quality');
  }
}
