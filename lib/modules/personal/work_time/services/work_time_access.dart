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

  /// Pravila po pogonu, uređaji, dodjela managerima, izvoz za plaće, audit — u matrici samo
  /// [ProductionDashboardCard.personalWorkTime] s [ProductionAccessLevel.manage] (menadžer proizvodnje).
  static bool canOpenTenantAdminScreens(String role) {
    return ProductionAccessHelper.canManage(
      role: ProductionAccessHelper.normalizeRole(role),
      card: ProductionDashboardCard.personalWorkTime,
    );
  }
}
