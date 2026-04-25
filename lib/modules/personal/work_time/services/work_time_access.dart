import 'package:production_app/core/access/production_access_helper.dart';

/// Pristup ekranima modula *Personal / Obračun radnog vremena* (vidi arhivu i matricu uloga).
class WorkTimeAccess {
  const WorkTimeAccess._();

  static bool canOpenHub(String role) {
    final r = ProductionAccessHelper.normalizeRole(role);
    return ProductionAccessHelper.canView(
      role: r,
      card: ProductionDashboardCard.personalWorkTime,
    );
  }

  /// Pravila, uređaji, dodjela managerima, payroll export, audit (IATF) — [matrica: samo Admin].
  static bool canOpenTenantAdminScreens(String role) {
    return ProductionAccessHelper.isAdminRole(role);
  }
}
