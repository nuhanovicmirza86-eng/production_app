import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:production_app/core/branding/operonix_ai_branding.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';
import 'package:production_app/screens/about_screen.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../../../auth/screens/station_device_mode_screen.dart';
import '../../../../core/access/production_maintenance_bridge.dart';
import '../../../../core/company_logo_resolver.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../auth/shared/services/auth_service.dart';
import '../../../auth/register/screens/pending_users_screen.dart';
import '../../../commercial/partners/screens/partners_screen.dart';
import '../../../commercial/orders/screens/document_pdf_settings_screen.dart';
import '../../../commercial/orders/screens/orders_list_screen.dart';
import '../../products/screens/products_list_screen.dart';
import '../../../logistics/receipt/screens/station1_packed_boxes_logistics_screen.dart';
import '../../../logistics/screens/logistics_hub_entry_screen.dart';
import '../../../sustainability/screens/carbon_footprint_screen.dart';
import '../../production_orders/screens/production_orders_list_screen.dart';
import '../../planning/screens/production_planning_hub_screen.dart';
import '../../tracking/models/production_operator_tracking_entry.dart';
import '../../tracking/screens/production_operator_tracking_screen.dart';
import '../../tracking/screens/production_operator_tracking_station_screen.dart';
import '../../station_pages/screens/production_station_pages_admin_screen.dart';
import '../../station_pages/widgets/station_page_active_gate.dart';
import '../../tracking/screens/production_preparation_station_screen.dart';
import '../../ai/screens/production_ai_hub_screen.dart';
import '../../tracking/screens/production_reports_hub_screen.dart';
import '../../issues/screens/production_problem_reporting_screen.dart';
import '../../ooe/screens/ooe_dashboard_screen.dart';
import '../../ooe/screens/teep_analysis_screen.dart';
import '../../qr/production_qr_scan_flow.dart';
import '../../../quality/screens/execute_inspection_screen.dart';
import '../../../quality/screens/quality_hub_screen.dart';

class _ProdNavItem {
  final WidgetBuilder builder;
  final NavigationDestination destination;

  const _ProdNavItem({required this.builder, required this.destination});
}

class ProductionDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionDashboardScreen({super.key, required this.companyData});

  @override
  State<ProductionDashboardScreen> createState() =>
      _ProductionDashboardScreenState();
}

class _ProductionDashboardScreenState extends State<ProductionDashboardScreen> {
  int _index = 0;

  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic> get companyData => widget.companyData;

  String get _companyId => (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey => (companyData['plantKey'] ?? '').toString().trim();

  String get _companyDisplayName {
    final n = (companyData['name'] ?? companyData['companyName'] ?? '')
        .toString()
        .trim();
    if (n.isNotEmpty) return n;
    return _companyId;
  }

  String get _role => ProductionAccessHelper.normalizeRole(companyData['role']);

  List<String> get _enabledModules {
    final raw = companyData['enabledModules'];

    if (raw is List) {
      return raw.map((e) => e.toString().trim().toLowerCase()).toList();
    }

    return const [];
  }

  bool _hasModule(String moduleKey) {
    final normalized = moduleKey.trim().toLowerCase();

    if (_enabledModules.isEmpty) {
      return normalized == 'production';
    }

    return _enabledModules.contains(normalized);
  }

  bool _hasAiProductionAiHubAccess() {
    return ProductionModuleKeys.hasAnyProductionAiHubAccess(companyData);
  }

  bool _canAccessMaintenanceFaultBridge() {
    return maintenanceFaultBridgeEnabled(companyData);
  }

  bool _canViewCard(ProductionDashboardCard card) {
    return ProductionAccessHelper.canView(role: _role, card: card);
  }

  /// Izvještaji praćenja proizvodnje dostupni su ulozi koja ima pristup izvještajima
  /// (ne ovisi o SaaS listi enabledReports — hub sadrži profesionalne kategorije).
  bool _canShowReportsCard() {
    return _canViewCard(ProductionDashboardCard.reports);
  }

  bool _canAccessOrders() {
    return _role == 'admin' ||
        _role == 'production_manager' ||
        _role == 'sales' ||
        _role == 'purchasing' ||
        _role == 'logistics_manager';
  }

  bool _canAccessPartners() {
    return _role == 'admin' ||
        _role == 'production_manager' ||
        _role == 'sales' ||
        _role == 'purchasing' ||
        _role == 'logistics_manager';
  }

  bool _canAccessCentralWarehouse() {
    return _role == 'admin' ||
        _role == 'production_manager' ||
        _role == 'purchasing' ||
        _role == 'logistics_operator' ||
        _role == 'logistics_manager';
  }

  /// Postavka lokalnog uređaja (stanica nakon prijave) — samo uloga Admin (tenant),
  /// ne Super admin niti druge uloge.
  bool _canConfigureStationDevice() {
    return ProductionAccessHelper.isAdminRole(_role);
  }

  static const double _tileGap = 10;

  String _logisticsSectionSubtitle() {
    if (_hasModule('logistics')) {
      return 'Pretplata uključuje modul „logistics“. Centralni hub, skladište, prijem kutija (ovisno o ulozi).';
    }
    return 'Centralni magacin / Hub nije dostupan bez modula „logistics“ u pretplati. Ostale kartice ovise o ulozi.';
  }

  List<Widget> _buildProductionActions(BuildContext context) {
    if (!_hasModule('production') && !_hasModule('quality')) return [];

    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    void openTrackingStation(String phase) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => StationPageActiveGate(
            companyData: companyData,
            phase: phase,
            stationBuilder: (_) =>
                phase == ProductionOperatorTrackingEntry.phasePreparation
                ? ProductionPreparationStationScreen(companyData: companyData)
                : ProductionOperatorTrackingStationScreen(
                    companyData: companyData,
                    phase: phase,
                  ),
          ),
        ),
      );
    }

    /// U QMS pretplati prva/završna kontrola vodi na izvršenje kontrole (IATF); inače stanica praćenja.
    void openQmsInspectionForStationPhase(String phase) {
      final pref = phase == ProductionOperatorTrackingEntry.phaseFirstControl
          ? 'IN_PROCESS'
          : 'FINAL';
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ExecuteInspectionScreen(
            companyData: companyData,
            preferredInspectionType: pref,
          ),
        ),
      );
    }

    final productionTiles = <Widget>[
      if (_hasModule('production')) ...[
      if (_canConfigureStationDevice())
        _DashboardActionTile(
          icon: Icons.display_settings_outlined,
          title: 'Način rada na ovom uređaju',
          subtitle:
              'Cijela aplikacija ili jedna stanica nakon prijave (samo uloga Admin).',
          onTap: () => open(const StationDeviceModeScreen()),
        ),
      if (_canViewCard(ProductionDashboardCard.productionOrders) ||
          _canAccessCentralWarehouse())
        _DashboardActionTile(
          icon: Icons.qr_code_scanner,
          title: 'Skeniraj QR',
          subtitle: 'Nalog ili naljepnica s proizvodnog poda.',
          onTap: () => _openProductionQrScan(context),
        ),
      if (_canViewCard(ProductionDashboardCard.products))
        _DashboardActionTile(
          icon: Icons.inventory_2_outlined,
          title: 'Proizvodi',
          subtitle: 'Pregled i upravljanje proizvodima.',
          onTap: () => open(ProductsListScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.productionOrders))
        _DashboardActionTile(
          icon: Icons.assignment,
          title: 'Proizvodni nalozi',
          subtitle: 'Lista naloga, detalji i statusi.',
          onTap: () =>
              open(ProductionOrdersListScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.productionOrders))
        _DashboardActionTile(
          icon: Icons.view_timeline_outlined,
          title: 'Planiranje (FCS)',
          subtitle:
              'Komandna traka, pool, Gantt, KPI; donji tabovi (Plan, provedba, varijanca…).',
          onTap: () =>
              open(ProductionPlanningHubScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.productionTracking)) ...[
        _DashboardActionTile(
          icon: Icons.play_circle_outline,
          title: 'Praćenje proizvodnje (tabovi)',
          subtitle:
              'Pregled KPI i trendova, zatim tri faze unosa u jednom ekranu.',
          onTap: () =>
              open(ProductionOperatorTrackingScreen(companyData: companyData)),
        ),
        _DashboardActionTile(
          icon: Icons.fullscreen_outlined,
          title: 'Stanica: pripremna',
          subtitle:
              'Puni zaslon — pripremna + traka prijave (QR uskoro). Jedan monitor.',
          onTap: () => openTrackingStation(
            ProductionOperatorTrackingEntry.phasePreparation,
          ),
        ),
        _DashboardActionTile(
          icon: Icons.fact_check_outlined,
          title: 'Stanica: prva kontrola',
          subtitle: _hasModule('quality')
              ? 'QMS: izvršenje kontrole (plan IN_PROCESS). Za tab praćenja koristi „Praćenje proizvodnje“.'
              : 'Puni zaslon — faza u izradi (placeholder do punog unosa).',
          onTap: () => _hasModule('quality')
              ? openQmsInspectionForStationPhase(
                  ProductionOperatorTrackingEntry.phaseFirstControl,
                )
              : openTrackingStation(
                  ProductionOperatorTrackingEntry.phaseFirstControl,
                ),
        ),
        _DashboardActionTile(
          icon: Icons.verified_outlined,
          title: 'Stanica: završna kontrola',
          subtitle: _hasModule('quality')
              ? 'QMS: izvršenje kontrole (plan FINAL). Za tab praćenja koristi „Praćenje proizvodnje“.'
              : 'Puni zaslon — faza u izradi (placeholder do punog unosa).',
          onTap: () => _hasModule('quality')
              ? openQmsInspectionForStationPhase(
                  ProductionOperatorTrackingEntry.phaseFinalControl,
                )
              : openTrackingStation(
                  ProductionOperatorTrackingEntry.phaseFinalControl,
                ),
        ),
      ],
      if (_canViewCard(ProductionDashboardCard.stationPages))
        _DashboardActionTile(
          icon: Icons.touch_app_outlined,
          title: 'Stranice stanica',
          subtitle: 'Definicija stanica 1–3 za terminal (tenant + pogon).',
          onTap: () =>
              open(ProductionStationPagesAdminScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.workCenters))
        _DashboardActionTile(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Radni centri',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canViewCard(ProductionDashboardCard.shifts))
        _DashboardActionTile(
          icon: Icons.schedule,
          title: 'Smjene',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canViewCard(ProductionDashboardCard.downtime))
        _DashboardActionTile(
          icon: Icons.warning_amber_outlined,
          title: 'Zastoji',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canViewCard(ProductionDashboardCard.ooe))
        _DashboardActionTile(
          icon: Icons.speed_outlined,
          title: 'OOE / OEE',
          subtitle: 'Live stanje, gubici i sažeci smjene (iz događaja).',
          onTap: () => open(OoeDashboardScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.ooe))
        _DashboardActionTile(
          icon: Icons.percent_outlined,
          title: 'TEEP i kapacitet',
          subtitle:
              'Kalendar, iskorištenje, TEEP (dan / tjedan / mjesec, pogon ili stroj).',
          onTap: () => open(TeepAnalysisScreen(companyData: companyData)),
        ),
      if (_canAccessMaintenanceFaultBridge() &&
          _canViewCard(ProductionDashboardCard.problemReporting))
        _DashboardActionTile(
          icon: Icons.report_problem_outlined,
          title: 'Prijava problema',
          subtitle: 'Prijava kvara + pregled mojih prijava.',
          onTap: () =>
              open(ProductionProblemReportingScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.processExecution))
        _DashboardActionTile(
          icon: Icons.science_outlined,
          title: 'Evidencija procesa',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canShowReportsCard())
        _DashboardActionTile(
          icon: Icons.assessment_outlined,
          title: 'Izvještaji',
          subtitle: 'Otpad, dnevna proizvodnja, IATF / CAPA.',
          onTap: () =>
              open(ProductionReportsHubScreen(companyData: companyData)),
        ),
      ],
    ];

    final qualityTiles = <Widget>[
      if (_hasModule('quality') &&
          _canViewCard(ProductionDashboardCard.qualityManagement))
        _DashboardActionTile(
          icon: Icons.assignment_turned_in_outlined,
          title: 'QMS — Hub kvaliteta',
          subtitle:
              'Kontrolni planovi, kontrole (sken), NCR, CAPA (IATF).',
          onTap: () => open(QualityHubScreen(companyData: companyData)),
        ),
    ];

    final commercialTiles = <Widget>[
      if (_canAccessOrders())
        _DashboardActionTile(
          icon: Icons.receipt_long_outlined,
          title: 'Narudžbe',
          subtitle: 'Pregled i rad s narudžbama.',
          onTap: () => open(OrdersListScreen(companyData: companyData)),
        ),
      if (_canAccessOrders())
        _DashboardActionTile(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Podaci za ispis PDF',
          subtitle: 'Zaglavlje, logo i podaci kompanije na dokumentima.',
          onTap: () =>
              open(DocumentPdfSettingsScreen(companyData: companyData)),
        ),
      if (_canAccessPartners())
        _DashboardActionTile(
          icon: Icons.groups_outlined,
          title: 'Kupci / dobavljači',
          subtitle: 'Partneri i poslovne veze.',
          onTap: () => open(PartnersScreen(companyData: companyData)),
        ),
    ];

    final logisticsTiles = <Widget>[
      if (_canAccessCentralWarehouse() && _hasModule('logistics'))
        _DashboardActionTile(
          icon: Icons.hub_outlined,
          title: 'Centralni magacin / Hub',
          subtitle:
              'Pregled zona, master MAG_*, WMS (prijem, kvaliteta, putaway, FIFO, otpremna), evidencija, QR.',
          onTap: () =>
              open(LogisticsHubEntryScreen(companyData: companyData)),
        ),
      if (_canAccessCentralWarehouse())
        _DashboardActionTile(
          icon: Icons.move_to_inbox_outlined,
          title: 'Upakovane kutije Stanica 1',
          subtitle:
              'Lista zatvorenih kutija i prijem u magacin skeniranjem QR-a.',
          onTap: () => open(
            Station1PackedBoxesLogisticsScreen(companyData: companyData),
          ),
        ),
    ];

    final sustainabilityTiles = <Widget>[
      if (_canViewCard(ProductionDashboardCard.carbonFootprint))
        _DashboardActionTile(
          icon: Icons.eco_outlined,
          title: 'Karbonski otisak',
          subtitle: 'Praćenje i evidencija utjecaja.',
          onTap: () => open(CarbonFootprintScreen(companyData: companyData)),
        ),
    ];

    final aiTiles = <Widget>[
      if (_hasAiProductionAiHubAccess() &&
          _canViewCard(ProductionDashboardCard.aiAssistant))
        _DashboardActionTile(
          icon: Icons.smart_toy_outlined,
          title: kOperonixAiAssistantTitle,
          subtitle: 'Chat, analitika i izvještaji (SaaS AI paketi).',
          onTap: () => open(ProductionAiHubScreen(companyData: companyData)),
        ),
    ];

    const sectionGap = 18.0;
    const afterHeader = 8.0;

    final out = <Widget>[];

    void addModuleSection({
      required String title,
      required String subtitle,
      required IconData icon,
      required List<Widget> tiles,
    }) {
      if (tiles.isEmpty) return;
      if (out.isNotEmpty) out.add(const SizedBox(height: sectionGap));
      out.add(
        _ModuleGroupHeader(title: title, subtitle: subtitle, icon: icon),
      );
      out.add(const SizedBox(height: afterHeader));
      out.addAll(_withTileGaps(tiles));
    }

    addModuleSection(
      title: 'Proizvodnja',
      subtitle:
          'SaaS modul „production“: proizvodi, proizvodni nalozi, praćenje, stanice, izvještaji.',
      icon: Icons.precision_manufacturing_outlined,
      tiles: productionTiles,
    );
    addModuleSection(
      title: 'Kvalitet (QMS)',
      subtitle:
          'SaaS modul „quality“: IATF-friendly kontrola — plan, izvršenje, neskladi, CAPA.',
      icon: Icons.fact_check_outlined,
      tiles: qualityTiles,
    );
    addModuleSection(
      title: 'Komercijalno',
      subtitle:
          'Narudžbe i partneri u ovoj aplikaciji — dio iste „production“ pretplate (nije zaseban modul).',
      icon: Icons.storefront_outlined,
      tiles: commercialTiles,
    );
    addModuleSection(
      title: 'Logistika i magacin',
      subtitle: _logisticsSectionSubtitle(),
      icon: Icons.local_shipping_outlined,
      tiles: logisticsTiles,
    );
    addModuleSection(
      title: 'Održivost',
      subtitle:
          'Karbonski otisak uz proizvodnju (isti tenant; ovisi o uključenim izvještajima).',
      icon: Icons.eco_outlined,
      tiles: sustainabilityTiles,
    );
    addModuleSection(
      title: kOperonixAiShortLabel,
      subtitle:
          'Dodatni SaaS paketi (npr. ai_assistant_production, ai_reports) uz osnovnu pretplatu.',
      icon: Icons.smart_toy_outlined,
      tiles: aiTiles,
    );

    return out;
  }

  List<Widget> _withTileGaps(List<Widget> tiles) {
    if (tiles.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) out.add(const SizedBox(height: _tileGap));
      out.add(tiles[i]);
    }
    return out;
  }

  /// Ista logika širine kao maintenance `HomeScreen` (web / Windows / ≥900 px).
  bool _isWideLayout(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isWin = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return isWin || w >= 900;
  }

  List<Widget> _buildHomeQuickActions(BuildContext context) {
    const sectionGap = 18.0;
    const afterHeader = 8.0;
    final tiles = <Widget>[];

    if (_canViewCard(ProductionDashboardCard.registrations)) {
      tiles.add(
        const _ModuleGroupHeader(
          title: 'Korisnici',
          subtitle: 'Administracija tenant računa (odobravanje novih prijava).',
          icon: Icons.manage_accounts_outlined,
        ),
      );
      tiles.add(const SizedBox(height: afterHeader));
      tiles.add(
        _DashboardActionTile(
          icon: Icons.person_add_alt_1,
          title: 'Registracije',
          subtitle: 'Odobri nove korisnike (pending).',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PendingUsersScreen(),
              ),
            );
          },
        ),
      );
      tiles.add(const SizedBox(height: sectionGap));
    }

    tiles.addAll(_buildProductionActions(context));

    if (_hasModule('quality') &&
        _canViewCard(ProductionDashboardCard.qualityManagement)) {
      if (tiles.isNotEmpty) {
        tiles.add(const SizedBox(height: sectionGap));
      }
      tiles.add(
        const _ModuleGroupHeader(
          title: 'Kvalitet (QMS)',
          subtitle:
              'Pretplata uključuje modul „quality“: kontrolni plan, kontrole, NCR, CAPA.',
          icon: Icons.assignment_turned_in_outlined,
        ),
      );
      tiles.add(const SizedBox(height: afterHeader));
      tiles.add(
        _DashboardActionTile(
          icon: Icons.dashboard_customize_outlined,
          title: 'QMS — Hub kvaliteta',
          subtitle:
              'Dashboard, planovi, izvršenje kontrole (sken), NCR, CAPA.',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => QualityHubScreen(companyData: companyData),
              ),
            );
          },
        ),
      );
    }

    if (tiles.isNotEmpty) {
      tiles.add(const SizedBox(height: sectionGap));
    }
    tiles.add(
      const _ModuleGroupHeader(
        title: 'Općenito',
        subtitle: 'Informacije o aplikaciji.',
        icon: Icons.info_outline,
      ),
    );
    tiles.add(const SizedBox(height: afterHeader));
    tiles.add(
      _DashboardActionTile(
        icon: Icons.article_outlined,
        title: 'O aplikaciji',
        subtitle: 'Verzija, autor, informacije.',
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
          );
        },
      ),
    );
    return tiles;
  }

  List<_ProdNavItem> _buildFullNav(BuildContext context) {
    final cd = companyData;

    final items = <_ProdNavItem>[
      _ProdNavItem(
        builder: (ctx) => _ProductionHomePage(
          companyData: cd,
          roleLabel:
              ProductionAccessHelper.displayRoleLabel(companyData['role']),
          companyId: _companyId,
          plantKey: _plantKey,
          companyLine: _companyDisplayName,
          quickActionChildren: _withTileGaps(_buildHomeQuickActions(ctx)),
        ),
        destination: const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Početna',
        ),
      ),
    ];

    if (_hasModule('production') &&
        _hasAiProductionAiHubAccess() &&
        _canViewCard(ProductionDashboardCard.aiAssistant)) {
      items.add(
        _ProdNavItem(
          builder: (_) => ProductionAiHubScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: kOperonixAiShortLabel,
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.products)) {
      items.add(
        _ProdNavItem(
          builder: (_) => ProductsListScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Proizvodi',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.productionOrders)) {
      items.add(
        _ProdNavItem(
          builder: (_) => ProductionOrdersListScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Nalozi',
          ),
        ),
      );
    }

    if (_hasModule('production') && _canAccessOrders()) {
      items.add(
        _ProdNavItem(
          builder: (_) => OrdersListScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Narudžbe',
          ),
        ),
      );
    }

    if (_hasModule('quality') &&
        _canViewCard(ProductionDashboardCard.qualityManagement)) {
      items.add(
        _ProdNavItem(
          builder: (_) => QualityHubScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'Kvalitet',
          ),
        ),
      );
    }

    if (_hasModule('production') && _canAccessPartners()) {
      items.add(
        _ProdNavItem(
          builder: (_) => PartnersScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Partneri',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.carbonFootprint)) {
      items.add(
        _ProdNavItem(
          builder: (_) => CarbonFootprintScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'Karbon',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.productionTracking)) {
      items.addAll([
        _ProdNavItem(
          builder: (_) => ProductionOperatorTrackingScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Praćenje',
          ),
        ),
        _ProdNavItem(
          builder: (_) => StationPageActiveGate(
            companyData: cd,
            phase: ProductionOperatorTrackingEntry.phasePreparation,
            stationBuilder: (_) =>
                ProductionPreparationStationScreen(companyData: cd),
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.fullscreen_outlined),
            selectedIcon: Icon(Icons.fullscreen),
            label: 'Stanica 1',
          ),
        ),
        _ProdNavItem(
          builder: (_) => StationPageActiveGate(
            companyData: cd,
            phase: ProductionOperatorTrackingEntry.phaseFirstControl,
            stationBuilder: (_) => ProductionOperatorTrackingStationScreen(
              companyData: cd,
              phase: ProductionOperatorTrackingEntry.phaseFirstControl,
            ),
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Stanica 2',
          ),
        ),
        _ProdNavItem(
          builder: (_) => StationPageActiveGate(
            companyData: cd,
            phase: ProductionOperatorTrackingEntry.phaseFinalControl,
            stationBuilder: (_) => ProductionOperatorTrackingStationScreen(
              companyData: cd,
              phase: ProductionOperatorTrackingEntry.phaseFinalControl,
            ),
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Stanica 3',
          ),
        ),
      ]);
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.workCenters)) {
      items.add(
        _ProdNavItem(
          builder: (ctx) => _PlaceholderProductionTab(
            title: 'Radni centri',
            onNotImplemented: () => _notImplemented(ctx),
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.precision_manufacturing_outlined),
            selectedIcon: Icon(Icons.precision_manufacturing),
            label: 'Centri',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.shifts)) {
      items.add(
        _ProdNavItem(
          builder: (ctx) => _PlaceholderProductionTab(
            title: 'Smjene',
            onNotImplemented: () => _notImplemented(ctx),
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Smjene',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.downtime)) {
      items.add(
        _ProdNavItem(
          builder: (ctx) => _PlaceholderProductionTab(
            title: 'Zastoji',
            onNotImplemented: () => _notImplemented(ctx),
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Zastoji',
          ),
        ),
      );
    }

    if (_hasModule('production') && _canViewCard(ProductionDashboardCard.ooe)) {
      items.add(
        _ProdNavItem(
          builder: (_) => OoeDashboardScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'OOE',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canAccessMaintenanceFaultBridge() &&
        _canViewCard(ProductionDashboardCard.problemReporting)) {
      items.add(
        _ProdNavItem(
          builder: (_) => ProductionProblemReportingScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.report_problem_outlined),
            selectedIcon: Icon(Icons.report_problem),
            label: 'Problemi',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.processExecution)) {
      items.add(
        _ProdNavItem(
          builder: (ctx) => _PlaceholderProductionTab(
            title: 'Evidencija procesa',
            onNotImplemented: () => _notImplemented(ctx),
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Procesi',
          ),
        ),
      );
    }

    if (_hasModule('production') && _canShowReportsCard()) {
      items.add(
        _ProdNavItem(
          builder: (_) => ProductionReportsHubScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Izvještaji',
          ),
        ),
      );
    }

    if (_canViewCard(ProductionDashboardCard.registrations)) {
      items.add(
        _ProdNavItem(
          builder: (_) => const PendingUsersScreen(),
          destination: const NavigationDestination(
            icon: Icon(Icons.person_add_alt_1_outlined),
            selectedIcon: Icon(Icons.person_add_alt_1),
            label: 'Registracije',
          ),
        ),
      );
    }

    return items;
  }

  List<_ProdNavItem> _buildMobileNav(List<_ProdNavItem> full) {
    if (full.length <= 5) return full;
    const primaryCount = 4;
    final primary = full.take(primaryCount).toList(growable: false);
    final extras = full.skip(primaryCount).toList(growable: false);
    return [
      ...primary,
      _ProdNavItem(
        builder: (_) => _ProductionMoreMenuScreen(items: extras),
        destination: const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'Više',
        ),
      ),
    ];
  }

  List<NavigationRailDestination> _toRailDestinations(List<_ProdNavItem> nav) {
    return nav
        .map(
          (e) => NavigationRailDestination(
            icon: e.destination.icon,
            selectedIcon: e.destination.selectedIcon,
            label: Text(e.destination.label),
          ),
        )
        .toList(growable: false);
  }

  /// Web: hamburger otvara izbornik (kao maintenance) — brzi ulazi kad rail ima puno stavki.
  Widget _webProductionDrawer(BuildContext context) {
    final cd = companyData;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Web meni',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Brzi pristup iz bočnog izbornika. Glavna navigacija ostaje u lijevom railu.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_canViewCard(ProductionDashboardCard.productionOrders) ||
                      _canAccessCentralWarehouse())
                    _DashboardActionTile(
                      icon: Icons.qr_code_scanner,
                      title: 'Skeniraj QR',
                      subtitle: 'Nalog ili naljepnica sa linije',
                      onTap: () {
                        _shellScaffoldKey.currentState?.closeDrawer();
                        _openProductionQrScan(context);
                      },
                    ),
                  if (_hasModule('production')) ...[
                    if (_canAccessOrders()) ...[
                      const SizedBox(height: 10),
                      _DashboardActionTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Narudžbe',
                        subtitle: 'Pregled i rad s narudžbama',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => OrdersListScreen(companyData: cd),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _DashboardActionTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Podaci za ispis PDF',
                        subtitle:
                            'Zaglavlje, logo i podaci kompanije na dokumentima',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  DocumentPdfSettingsScreen(companyData: cd),
                            ),
                          );
                        },
                      ),
                    ],
                    if (_canAccessPartners()) ...[
                      const SizedBox(height: 10),
                      _DashboardActionTile(
                        icon: Icons.groups_outlined,
                        title: 'Kupci / dobavljači',
                        subtitle: 'Partneri i poslovne veze',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PartnersScreen(companyData: cd),
                            ),
                          );
                        },
                      ),
                    ],
                    if (_canAccessCentralWarehouse() &&
                        _hasModule('logistics')) ...[
                      const SizedBox(height: 10),
                      _DashboardActionTile(
                        icon: Icons.hub_outlined,
                        title: 'Centralni magacin / Hub',
                        subtitle: 'Pregled, master, WMS, QR',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => LogisticsHubEntryScreen(
                                companyData: cd,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (_hasModule('quality') &&
                        _canViewCard(
                          ProductionDashboardCard.qualityManagement,
                        )) ...[
                      const SizedBox(height: 10),
                      _DashboardActionTile(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'QMS — Hub kvaliteta',
                        subtitle: 'Kontrolni plan, kontrole, NCR, CAPA',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  QualityHubScreen(companyData: cd),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),
                  _DashboardActionTile(
                    icon: Icons.article_outlined,
                    title: 'O aplikaciji',
                    subtitle: 'Verzija, autor, informacije',
                    onTap: () {
                      _shellScaffoldKey.currentState?.closeDrawer();
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Odjava',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                _shellScaffoldKey.currentState?.closeDrawer();
                await AuthService().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proizvodnja')),
        body: const Center(
          child: Text('Nedostaje podatak o kompaniji. Ponovo se prijavi.'),
        ),
      );
    }

    final fullNav = _buildFullNav(context);
    final isWide = _isWideLayout(context);
    final nav = isWide ? fullNav : _buildMobileNav(fullNav);
    final safeIndex = (_index >= 0 && _index < nav.length) ? _index : 0;
    final current = nav[safeIndex].builder(context);

    if (isWide) {
      return Scaffold(
        key: _shellScaffoldKey,
        drawer: kIsWeb ? _webProductionDrawer(context) : null,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                leading: kIsWeb
                    ? IconButton(
                        tooltip: 'Web meni',
                        icon: const Icon(Icons.menu),
                        onPressed: () =>
                            _shellScaffoldKey.currentState?.openDrawer(),
                      )
                    : null,
                selectedIndex: safeIndex,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                destinations: _toRailDestinations(nav),
                scrollable: true,
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey<String>('prod_rail_$safeIndex'),
                  child: current,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final showBottomNav = nav.length >= 2;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: safeIndex,
          children: nav.map((e) => e.builder(context)).toList(),
        ),
      ),
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: nav.map((e) => e.destination).toList(),
            )
          : null,
    );
  }

  void _notImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ovaj ekran još nije implementiran.')),
    );
  }

  Future<void> _openProductionQrScan(BuildContext context) async {
    await runProductionQrScanFlow(context: context, companyData: companyData);
  }
}

/// Početna s karticom sesije i listom „Brze akcije“ (isti obrazac kao maintenance).
class _ProductionHomePage extends StatelessWidget {
  final Map<String, dynamic> companyData;
  final String roleLabel;
  final String companyId;
  final String plantKey;
  final String companyLine;
  final List<Widget> quickActionChildren;

  const _ProductionHomePage({
    required this.companyData,
    required this.roleLabel,
    required this.companyId,
    required this.plantKey,
    required this.companyLine,
    required this.quickActionChildren,
  });

  @override
  Widget build(BuildContext context) {
    final gap = kIsWeb ? 12.0 : 16.0;
    final pad = kIsWeb ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Početna'),
        actions: [
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: () async => AuthService().signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          _SessionHeaderCard(
            logoCandidates: CompanyLogoResolver.resolveLogoImageCandidates(
              companyData,
            ),
            roleLabel: roleLabel,
            companyId: companyId,
            plantKey: plantKey,
            companyLine: companyLine,
          ),
          SizedBox(height: gap),
          const _SectionTitle(title: 'Brze akcije'),
          SizedBox(height: gap * 0.35),
          Text(
            'Grupirano po modulima pretplate i funkciji. Pojedina kartica ovisi o ulozi.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: gap * 0.75),
          ...quickActionChildren,
        ],
      ),
    );
  }
}

/// Mobilni „Više“ meni kad je više od pet stavki u donjoj navigaciji.
class _ProductionMoreMenuScreen extends StatefulWidget {
  final List<_ProdNavItem> items;

  const _ProductionMoreMenuScreen({required this.items});

  @override
  State<_ProductionMoreMenuScreen> createState() =>
      _ProductionMoreMenuScreenState();
}

class _ProductionMoreMenuScreenState extends State<_ProductionMoreMenuScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = widget.items
        .where((it) {
          final label = it.destination.label.toLowerCase();
          return q.isEmpty || label.contains(q);
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Više'),
        actions: [
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: () async => AuthService().signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Pretraži meni…',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Nema rezultata.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final it = filtered[i];
                      return Card(
                        child: ListTile(
                          leading: it.destination.icon,
                          title: Text(
                            it.destination.label,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(builder: it.builder),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderProductionTab extends StatelessWidget {
  final String title;
  final VoidCallback onNotImplemented;

  const _PlaceholderProductionTab({
    required this.title,
    required this.onNotImplemented,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: () async => AuthService().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Uskoro u aplikaciji.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onNotImplemented,
                child: const Text('Obavijest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gornji blok: logo (iz `companies.websiteUrl` → favicon, ili izravni `logoUrl`), uloga, pogon, kompanija.
class _SessionHeaderCard extends StatelessWidget {
  final List<String> logoCandidates;
  final String roleLabel;
  final String companyId;
  final String plantKey;
  final String companyLine;

  const _SessionHeaderCard({
    required this.logoCandidates,
    required this.roleLabel,
    required this.companyId,
    required this.plantKey,
    required this.companyLine,
  });

  Widget _plantLine() {
    if (plantKey.trim().isEmpty) {
      return const Text('Pogon: -', style: TextStyle(color: Colors.black87));
    }
    if (companyId.trim().isEmpty) {
      return Text(
        'Pogon: $plantKey',
        style: const TextStyle(color: Colors.black87),
      );
    }
    return FutureBuilder<String>(
      key: ValueKey('plant|$companyId|$plantKey'),
      future: CompanyPlantDisplayName.resolve(
        companyId: companyId,
        plantKey: plantKey,
      ),
      builder: (context, snap) {
        final label = snap.connectionState == ConnectionState.waiting
            ? '…'
            : (snap.data ?? plantKey);
        return Text(
          'Pogon: $label',
          style: const TextStyle(color: Colors.black87),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: kOperonixProductionBrandGreen,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompanyHeaderLogo(candidates: logoCandidates),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uloga: $roleLabel',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _plantLine(),
                  const SizedBox(height: 2),
                  Text(
                    'Kompanija: $companyLine',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyHeaderLogo extends StatefulWidget {
  final List<String> candidates;
  static const double size = 56;

  const _CompanyHeaderLogo({required this.candidates});

  @override
  State<_CompanyHeaderLogo> createState() => _CompanyHeaderLogoState();
}

class _CompanyHeaderLogoState extends State<_CompanyHeaderLogo> {
  int _candidateIndex = 0;

  @override
  void didUpdateWidget(covariant _CompanyHeaderLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidates != widget.candidates) {
      _candidateIndex = 0;
    }
  }

  void _tryNextCandidate() {
    if (!mounted) return;
    if (_candidateIndex + 1 < widget.candidates.length) {
      setState(() => _candidateIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Border.all(
      color: kOperonixProductionBrandGreen.withValues(alpha: 0.5),
      width: 1.5,
    );
    final radius = BorderRadius.circular(12);

    Widget placeholder() {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.apartment_outlined,
            size: 30,
            color: kOperonixProductionBrandGreen.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    final urls = widget.candidates;
    if (urls.isEmpty) {
      return SizedBox(
        width: _CompanyHeaderLogo.size,
        height: _CompanyHeaderLogo.size,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, border: border),
          child: ClipRRect(borderRadius: radius, child: placeholder()),
        ),
      );
    }

    final safeIndex = _candidateIndex.clamp(0, urls.length - 1);
    final u = urls[safeIndex].trim();

    return SizedBox(
      width: _CompanyHeaderLogo.size,
      height: _CompanyHeaderLogo.size,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, border: border),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.network(
            u,
            key: ValueKey<String>(u),
            fit: BoxFit.cover,
            // Web: canvas/fetch traži CORS; <img> u HTML-u tipično prikaže iste favicon/logo URL-ove kao Android.
            webHtmlElementStrategy: kIsWeb
                ? WebHtmlElementStrategy.prefer
                : WebHtmlElementStrategy.never,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              if (_candidateIndex < widget.candidates.length - 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _tryNextCandidate();
                });
              }
              return placeholder();
            },
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

/// Naslov bloka na početnoj: koji SaaS / poslovni modul pokriva kartice ispod.
class _ModuleGroupHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ModuleGroupHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: kOperonixProductionBrandGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartica prečice kao maintenance [_HomeDashboardScreenState._actionButton].
class _DashboardActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: kOperonixProductionBrandGreen,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kOperonixProductionBrandGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kOperonixProductionBrandGreen.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
                child: Icon(icon, color: kOperonixProductionBrandGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: kOperonixProductionBrandGreen.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
