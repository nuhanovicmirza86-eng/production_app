import '../access/production_access_helper.dart';
import '../saas/production_module_keys.dart';

/// Dopuštene domena OperonixAI (Production) — usklađeno s backendom
/// [getProductionContextAllowlist] + [ai/ai_production_rbac.json].
/// Kad mijenjaš [ProductionAccessHelper._roleMatrix], ažuriraj i JSON na functions.
class ProductionAiContextScope {
  ProductionAiContextScope._();

  static const Map<ProductionDashboardCard, String> _cardToKey = {
    ProductionDashboardCard.products: 'products',
    ProductionDashboardCard.productionOrders: 'production_orders',
    ProductionDashboardCard.productionTracking: 'production_tracking',
    ProductionDashboardCard.stationPages: 'station_pages',
    ProductionDashboardCard.workCenters: 'work_centers',
    ProductionDashboardCard.productionProcesses: 'production_processes',
    ProductionDashboardCard.shifts: 'workforce_shifts',
    ProductionDashboardCard.downtime: 'downtime',
    ProductionDashboardCard.ooe: 'oee_ooe',
    ProductionDashboardCard.problemReporting: 'problem_reporting',
    ProductionDashboardCard.processExecution: 'process_execution',
    ProductionDashboardCard.reports: 'reports',
    ProductionDashboardCard.registrations: 'registrations',
    ProductionDashboardCard.carbonFootprint: 'carbon_footprint',
    ProductionDashboardCard.qualityManagement: 'quality_qms',
  };

  static const Map<ProductionDashboardCard, String> _labelHr = {
    ProductionDashboardCard.products: 'artikli / proizvodi',
    ProductionDashboardCard.productionOrders: 'proizvodni nalozi',
    ProductionDashboardCard.productionTracking: 'praćenje proizvodnje',
    ProductionDashboardCard.stationPages: 'stanične stranice (HMI)',
    ProductionDashboardCard.workCenters: 'radna mjesta / resursi',
    ProductionDashboardCard.productionProcesses: 'MES procesi (master-data)',
    ProductionDashboardCard.shifts: 'raspored, smjene, radnici (Workforce)',
    ProductionDashboardCard.downtime: 'zastoji / downtime',
    ProductionDashboardCard.ooe: 'OEE / OOE',
    ProductionDashboardCard.problemReporting: 'prijava problema (MES)',
    ProductionDashboardCard.processExecution: 'izvršenje procesa',
    ProductionDashboardCard.reports: 'Izvještaji (hub)',
    ProductionDashboardCard.registrations: 'registracije / upisi',
    ProductionDashboardCard.carbonFootprint: 'ugljični otisak',
    ProductionDashboardCard.qualityManagement: 'QMS (kvaliteta)',
  };

  static String _matrixRole(String raw) {
    final n = ProductionAccessHelper.normalizeRole(raw);
    if (n == 'quality' ||
        n == 'quality_control' ||
        n == 'quality_manager') {
      return ProductionAccessHelper.roleQualityOperator;
    }
    if (n == 'super_admin') {
      return ProductionAccessHelper.roleSuperAdmin;
    }
    return n;
  }

  static bool _moduleOk(
    Map<String, dynamic> companyData,
    ProductionDashboardCard card,
  ) {
    if (card == ProductionDashboardCard.qualityManagement) {
      return ProductionModuleKeys.hasModule(
        companyData,
        ProductionModuleKeys.quality,
      );
    }
    return ProductionModuleKeys.hasModule(
      companyData,
      ProductionModuleKeys.production,
    );
  }

  /// Stabilan red kao na backendu (za prikaz / test).
  static List<ProductionDashboardCard> get cardsInOrder =>
      const [
        ProductionDashboardCard.products,
        ProductionDashboardCard.productionOrders,
        ProductionDashboardCard.productionTracking,
        ProductionDashboardCard.stationPages,
        ProductionDashboardCard.workCenters,
        ProductionDashboardCard.productionProcesses,
        ProductionDashboardCard.shifts,
        ProductionDashboardCard.downtime,
        ProductionDashboardCard.ooe,
        ProductionDashboardCard.problemReporting,
        ProductionDashboardCard.processExecution,
        ProductionDashboardCard.reports,
        ProductionDashboardCard.registrations,
        ProductionDashboardCard.carbonFootprint,
        ProductionDashboardCard.qualityManagement,
      ];

  /// Kanonski ključevi (iste oznake kao u Callable promptu).
  static List<String> allowedContextKeys(Map<String, dynamic> companyData) {
    final role = _matrixRole(companyData['role']);
    final out = <String>[];
    for (final card in cardsInOrder) {
      if (!ProductionAccessHelper.canView(role: role, card: card)) {
        continue;
      }
      if (!_moduleOk(companyData, card)) {
        continue;
      }
      final k = _cardToKey[card];
      if (k != null) {
        out.add(k);
      }
    }
    return out;
  }

  /// Jedan red za prazan ekran chata.
  static String hintForEmptyChat(Map<String, dynamic> companyData) {
    final keys = allowedContextKeys(companyData);
    if (keys.isEmpty) {
      return 'Odgovori prate tvoju ulogu i uključene module; bez konkretnih brojke iz baze osim u dodatcima s poslužitelja.';
    }
    return 'Domena pomoći u skladu s ulogom: ${allowedLabels(companyData).join(', ')}.';
  }

  static List<String> allowedLabels(Map<String, dynamic> companyData) {
    final role = _matrixRole(companyData['role']);
    final out = <String>[];
    for (final card in cardsInOrder) {
      if (!ProductionAccessHelper.canView(role: role, card: card)) {
        continue;
      }
      if (!_moduleOk(companyData, card)) {
        continue;
      }
      final lb = _labelHr[card];
      if (lb != null) {
        out.add(lb);
      }
    }
    return out;
  }

  /// Usklađeno s backendom [assertStructuredAnalysisDomainAllowed].
  static bool allowsStructuredAnalysisApiDomain(
    String domain,
    Map<String, dynamic> companyData,
  ) {
    final keys = allowedContextKeys(companyData);
    if (keys.isEmpty) {
      return false;
    }
    final s = keys.toSet();
    final d = domain.trim().toLowerCase();
    if (d == 'oee') {
      return s.contains('oee_ooe');
    }
    if (d == 'scada') {
      return s.contains('station_pages') ||
          s.contains('work_centers') ||
          s.contains('production_processes') ||
          s.contains('oee_ooe') ||
          s.contains('production_tracking');
    }
    if (d == 'production_flow') {
      return s.contains('production_tracking') ||
          s.contains('production_orders') ||
          s.contains('process_execution') ||
          s.contains('production_processes') ||
          s.contains('products');
    }
    if (d == 'generic') {
      return true;
    }
    return false;
  }

  /// Usklađeno s [assertProductionAiReportContextAllowed] na backendu.
  static bool allowsProductionAiReport(Map<String, dynamic> companyData) {
    final keys = allowedContextKeys(companyData);
    return keys.contains('production_tracking') || keys.contains('production_orders');
  }
}
