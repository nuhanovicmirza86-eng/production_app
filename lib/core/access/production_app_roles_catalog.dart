import 'production_access_helper.dart';

/// Jedna kartica iz matrice Production aplikacije (referentni prikaz za super admina).
class ProductionAppRoleCapabilityRow {
  const ProductionAppRoleCapabilityRow({
    required this.area,
    required this.level,
  });

  final String area;
  final ProductionAccessLevel level;
}

/// Ljudski čitljivi naslovi kartica (usklađeno s hubovima / modulima).
abstract final class ProductionAppRolesCatalog {
  static const List<ProductionDashboardCard> _orderedCards = [
    ProductionDashboardCard.products,
    ProductionDashboardCard.productionOrders,
    ProductionDashboardCard.productionTracking,
    ProductionDashboardCard.stationPages,
    ProductionDashboardCard.workCenters,
    ProductionDashboardCard.productionProcesses,
    ProductionDashboardCard.shifts,
    ProductionDashboardCard.personalWorkTime,
    ProductionDashboardCard.downtime,
    ProductionDashboardCard.ooe,
    ProductionDashboardCard.operonixAnalytics,
    ProductionDashboardCard.problemReporting,
    ProductionDashboardCard.processExecution,
    ProductionDashboardCard.reports,
    ProductionDashboardCard.registrations,
    ProductionDashboardCard.carbonFootprint,
    ProductionDashboardCard.developmentGovernance,
    ProductionDashboardCard.qualityManagement,
    ProductionDashboardCard.aiAssistant,
  ];

  static String cardTitle(ProductionDashboardCard c) {
    switch (c) {
      case ProductionDashboardCard.products:
        return 'Proizvodi';
      case ProductionDashboardCard.productionOrders:
        return 'Proizvodni nalozi';
      case ProductionDashboardCard.productionTracking:
        return 'Praćenje proizvodnje';
      case ProductionDashboardCard.stationPages:
        return 'Stranice stanica';
      case ProductionDashboardCard.workCenters:
        return 'Radni centri';
      case ProductionDashboardCard.productionProcesses:
        return 'Procesi';
      case ProductionDashboardCard.shifts:
        return 'Radna snaga (Workforce hub)';
      case ProductionDashboardCard.personalWorkTime:
        return 'Obračun radnog vremena';
      case ProductionDashboardCard.downtime:
        return 'Zastoji';
      case ProductionDashboardCard.ooe:
        return 'Učinak pogona (OOE/OEE hub)';
      case ProductionDashboardCard.operonixAnalytics:
        return 'Operonix Analytics';
      case ProductionDashboardCard.problemReporting:
        return 'Prijava problema (kvar)';
      case ProductionDashboardCard.processExecution:
        return 'Evidencija procesa';
      case ProductionDashboardCard.reports:
        return 'Izvještaji';
      case ProductionDashboardCard.registrations:
        return 'Registracije korisnika (pending)';
      case ProductionDashboardCard.carbonFootprint:
        return 'Karbonski otisak';
      case ProductionDashboardCard.developmentGovernance:
        return 'Razvoj / NPI / projekti';
      case ProductionDashboardCard.qualityManagement:
        return 'Kvalitet (QMS hub)';
      case ProductionDashboardCard.aiAssistant:
        return 'OperonixAI';
    }
  }

  static String levelDescription(ProductionAccessLevel level) {
    switch (level) {
      case ProductionAccessLevel.hidden:
        return 'Nema pristupa — kartica se u UI ne nudi';
      case ProductionAccessLevel.view:
        return 'Pregled';
      case ProductionAccessLevel.manage:
        return 'Upravljanje';
    }
  }

  /// Kratki opis uloge za „karakteristiku” na ExpansionTile.
  static String briefForRole(String roleCode) {
    final r = ProductionAccessHelper.normalizeRole(roleCode);
    switch (r) {
      case ProductionAccessHelper.roleSuperAdmin:
        return 'SaaS super admin: puna matrica u ovoj aplikaciji, uključujući registracije; '
            'opseg izvan jednog tenant administratora po kompaniji.';
      case ProductionAccessHelper.roleAdmin:
        return 'Administrator kompanije: upravljanje svim modulima unutar tenanta prema pretplati; '
            'ne vidi druge kompanije.';
      case ProductionAccessHelper.roleProjectManager:
        return 'Voditelj NPI: upravljanje portfeljem razvoja; široka MES/QMS operativa u matrici; '
            'nije tenant admin.';
      case ProductionAccessHelper.roleProductionManager:
        return 'Menadžer proizvodnje: puna operativa proizvodnje, učinka, planiranja, kvaliteta, karbona.';
      case ProductionAccessHelper.roleDevelopmentEngineer:
        return 'Inženjer razvoja: operativa na podu i pregled NPI; bez najšireg konfiguracijskog sloja gdje je skriven.';
      case ProductionAccessHelper.roleSupervisor:
        return 'Supervizor: MES operativa, planovi, učinak, QMS pregled; ograničene adminske kartice (npr. stanice).';
      case ProductionAccessHelper.roleProductionOperator:
        return 'Operater: praćenje, unos na podu, osnovni OOE pregled; menadžerski hubovi i QMS upravljanje skriveni.';
      case ProductionAccessHelper.roleQualityOperator:
        return 'Operater kvaliteta: QMS izvršenje i povezani pregledi; bez proizvodnog planiranja.';
      case ProductionAccessHelper.roleQualityControl:
        return 'Kontrola kvaliteta: isti domet QMS-a kao operater kvaliteta uz kontrolne aktivnosti u matrici.';
      case ProductionAccessHelper.roleManagementViewer:
        return 'Menadžment (sam pregled): Analytics, Razvoj, AI — bez operativnih naloga i bez izmjena u QMS-u.';
      case ProductionAccessHelper.roleLogisticsManager:
        return 'Menadžer logistike: analitika i pretpregled razvoja/kvaliteta; radno vrijeme; bez MES jezgra.';
      case ProductionAccessHelper.roleMaintenanceManager:
        return 'Menadžer održavanja: karbon, analitika, pregled razvoja; proizvodni nalozi u ovoj app su izvan domet.';
      default:
        return 'Uloga nije u kanonskoj matrici — UI tretira kao bez pristupa osim ako postoji druga logika.';
    }
  }

  static List<ProductionAppRoleCapabilityRow> capabilitiesForRole(String roleCode) {
    final r = ProductionAccessHelper.normalizeRole(roleCode);
    final out = <ProductionAppRoleCapabilityRow>[];
    for (final card in _orderedCards) {
      final level = ProductionAccessHelper.getAccess(role: r, card: card);
      out.add(
        ProductionAppRoleCapabilityRow(
          area: cardTitle(card),
          level: level,
        ),
      );
    }
    return out;
  }
}
