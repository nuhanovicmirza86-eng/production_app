import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:production_app/core/branding/operonix_ai_branding.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';
import 'package:production_app/screens/about_screen.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../../../../core/company_logo_resolver.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/access/production_maintenance_bridge.dart';
import '../../../auth/shared/services/auth_service.dart';
import '../../../auth/register/screens/pending_users_screen.dart';
import '../../../commercial/orders/screens/document_pdf_settings_screen.dart';
import '../../../personal/work_time/screens/work_time_hub_screen.dart';
import '../../../workforce/screens/workforce_dashboard_screen.dart';
import '../../downtime/screens/downtimes_screen.dart';
import '../../execution/screens/process_execution_hub_screen.dart';
import '../../issues/screens/production_problem_reporting_screen.dart';
import '../../processes/screens/production_processes_list_screen.dart';
import '../../tracking/screens/production_reports_hub_screen.dart';
import '../../work_centers/screens/work_centers_list_screen.dart';
import '../../../commercial/partners/screens/partners_screen.dart';
import '../../../commercial/orders/screens/orders_list_screen.dart';
import '../../../development/screens/development_projects_list_screen.dart';
import '../../../finance_integrations/screens/finance_controlling_hub_screen.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../../logistics/screens/logistics_hub_entry_screen.dart';
import '../../../sustainability/screens/carbon_footprint_screen.dart';
import '../../ai/screens/production_ai_hub_screen.dart';
import '../../notifications/mes_inbox_screen.dart';
import '../../ooe/screens/ooe_dashboard_screen.dart';
import '../../products/screens/products_list_screen.dart';
import '../../production_orders/screens/production_orders_list_screen.dart';
import '../../planning/screens/production_planning_home_screen.dart';
import '../../tracking/models/production_operator_tracking_entry.dart';
import '../../tracking/screens/production_operator_tracking_screen.dart';
import '../../tracking/screens/production_operator_tracking_station_screen.dart';
import '../../tracking/screens/production_preparation_station_screen.dart';
import '../../station_pages/widgets/station_page_active_gate.dart';
import '../../qr/production_qr_scan_flow.dart';
import '../../../quality/screens/quality_hub_screen.dart';
import '../models/production_dashboard_layout.dart';
import '../models/production_dashboard_module.dart';
import '../production_dashboard_access.dart';
import '../production_dashboard_module_catalog.dart';
import '../services/production_dashboard_layout_preference.dart';
import '../widgets/production_dashboard_action_tile.dart';
import '../widgets/production_dashboard_home_modules_view.dart';
import '../widgets/production_dashboard_layout_selector.dart';

class _ProdNavItem {
  final WidgetBuilder builder;
  final NavigationDestination destination;

  const _ProdNavItem({required this.builder, required this.destination});
}

class ProductionDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionDashboardScreen({
    super.key,
    required this.companyData,
  });

  @override
  State<ProductionDashboardScreen> createState() =>
      _ProductionDashboardScreenState();
}

class _ProductionDashboardScreenState extends State<ProductionDashboardScreen> {
  int _index = 0;

  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();

  ProductionDashboardLayout _dashboardLayout =
      ProductionDashboardLayout.standard;
  StreamSubscription<ProductionDashboardLayout>? _dashboardLayoutSub;

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

  ProductionDashboardAccess get _dashboardAccess =>
      ProductionDashboardAccess.fromCompanyData(companyData);

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _dashboardLayoutSub =
          ProductionDashboardLayoutPreference.watch(uid).listen((layout) {
        if (!mounted) return;
        setState(() => _dashboardLayout = layout);
      });
    }
  }

  @override
  void dispose() {
    _dashboardLayoutSub?.cancel();
    super.dispose();
  }

  Future<void> _setDashboardLayout(ProductionDashboardLayout layout) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _dashboardLayout = layout);
    await ProductionDashboardLayoutPreference.save(uid: uid, layout: layout);
  }

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

  /// Modul [ProductionModuleKeys.personal]; u [kDebugMode] vidljivo i bez SaaS unosa (demo/razvoj).
  bool _canAccessPersonalWorkTime() {
    if (!ProductionAccessHelper.canView(
      role: _role,
      card: ProductionDashboardCard.personalWorkTime,
    )) {
      return false;
    }
    if (kDebugMode) return true;
    return ProductionModuleKeys.hasModule(companyData, ProductionModuleKeys.personal);
  }

  /// Finance & Controlling — pretplata [ProductionModuleKeys.hasFinanceSuite];
  /// tenant [admin]/[super_admin] uvijek vide ulaz; u [kDebugMode] kao i ostali hub putovi.
  bool _canAccessFinanceIntegrations() {
    return FinancePermissions.canAccessModule(
      companyData: companyData,
      role: _role,
      debugUnlockModule: kDebugMode,
    );
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

  /// Ista logika širine kao maintenance `HomeScreen` (web / Windows / ≥900 px).
  bool _isWideLayout(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isWin = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return isWin || w >= 900;
  }

  List<_ProdNavItem> _buildFullNav(BuildContext context) {
    final cd = companyData;

    final items = <_ProdNavItem>[
      _ProdNavItem(
        builder: (ctx) {
          final access = _dashboardAccess;
          final sections = ProductionDashboardModuleCatalog(
            access: access,
            companyData: cd,
            debugUnlockFinanceModule: kDebugMode,
          ).buildSections(ctx);
          return _ProductionHomePage(
            companyData: cd,
            roleLabel: ProductionAccessHelper.displayRoleLabel(
              companyData['role'],
            ),
            companyId: _companyId,
            plantKey: _plantKey,
            companyLine: _companyDisplayName,
            showQrScanAction:
                _hasModule('production') &&
                (_canViewCard(ProductionDashboardCard.productionOrders) ||
                    _canAccessCentralWarehouse()),
            onOpenQrScan: _openProductionQrScan,
            dashboardLayout: _dashboardLayout,
            onDashboardLayoutChanged: _setDashboardLayout,
            moduleSections: sections,
            dashboardAccess: access,
          );
        },
        destination: const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Početna',
        ),
      ),
    ];

    items.add(
      _ProdNavItem(
        builder: (_) => MesInboxScreen(companyData: cd),
        destination: const NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Obavijesti',
        ),
      ),
    );

    if (_canAccessFinanceIntegrations()) {
      items.add(
        _ProdNavItem(
          builder: (_) => FinanceControllingHubScreen(
            companyData: cd,
            debugUnlockModule: kDebugMode,
          ),
          destination: const NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Financije',
          ),
        ),
      );
    }

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

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.productionOrders)) {
      items.add(
        _ProdNavItem(
          builder: (_) => ProductionPlanningHomeScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.view_timeline_outlined),
            selectedIcon: Icon(Icons.view_timeline),
            label: 'Planiranje proizvodnje',
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

    if (ProductionModuleKeys.hasModule(cd, ProductionModuleKeys.development) &&
        _canViewCard(ProductionDashboardCard.developmentGovernance)) {
      items.add(
        _ProdNavItem(
          builder: (_) => DevelopmentProjectsListScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Razvoj',
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
          builder: (_) => WorkCentersListScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.precision_manufacturing_outlined),
            selectedIcon: Icon(Icons.precision_manufacturing),
            label: 'Centri',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.productionProcesses)) {
      items.add(
        _ProdNavItem(
          builder: (_) => ProductionProcessesListScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Procesi',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.shifts)) {
      items.add(
        _ProdNavItem(
          builder: (_) => WorkforceDashboardScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2),
            label: 'Radna snaga',
          ),
        ),
      );
    }

    if (_hasModule('production') && _canAccessPersonalWorkTime()) {
      items.add(
        _ProdNavItem(
          builder: (_) => WorkTimeHubScreen(companyData: cd),
          destination: const NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'Radno vrijeme',
          ),
        ),
      );
    }

    if (_hasModule('production') &&
        _canViewCard(ProductionDashboardCard.downtime)) {
      items.add(
        _ProdNavItem(
          builder: (_) => DowntimesScreen(companyData: cd),
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
            label: 'OOE uživo',
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
          builder: (_) => ProcessExecutionHubScreen(companyData: cd),
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
                  if (_hasModule('production')) ...[
                    if (_canAccessOrders()) ...[
                      const SizedBox(height: 10),
                      ProductionDashboardActionTile(
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
                      ProductionDashboardActionTile(
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
                      ProductionDashboardActionTile(
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
                      ProductionDashboardActionTile(
                        icon: Icons.hub_outlined,
                        title: 'Centralni magacin / Hub',
                        subtitle: 'Pregled, master, WMS, QR',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  LogisticsHubEntryScreen(companyData: cd),
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
                      ProductionDashboardActionTile(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'Kvalitet — središnji izbornik',
                        subtitle: 'Kontrolni plan, kontrole, NCR, CAPA',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => QualityHubScreen(companyData: cd),
                            ),
                          );
                        },
                      ),
                    ],
                    if (ProductionModuleKeys.hasModule(cd, ProductionModuleKeys.development) &&
                        _canViewCard(
                          ProductionDashboardCard.developmentGovernance,
                        )) ...[
                      const SizedBox(height: 10),
                      ProductionDashboardActionTile(
                        icon: Icons.account_tree_outlined,
                        title: 'Razvoj / NPI / Projekti',
                        subtitle: 'Portfolio i projekti',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  DevelopmentProjectsListScreen(companyData: cd),
                            ),
                          );
                        },
                      ),
                    ],
                    if (_canAccessFinanceIntegrations()) ...[
                      const SizedBox(height: 10),
                      ProductionDashboardActionTile(
                        icon: Icons.account_balance_outlined,
                        title: 'Financije · integracije',
                        subtitle: 'ERP veze i sync',
                        onTap: () {
                          _shellScaffoldKey.currentState?.closeDrawer();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => FinanceControllingHubScreen(
                                companyData: cd,
                                debugUnlockModule: kDebugMode,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),
                  ProductionDashboardActionTile(
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

  bool get _globalTenantAdminNoPlant =>
      (ProductionAccessHelper.isAdminRole(_role) ||
          ProductionAccessHelper.isSuperAdminRole(_role)) &&
      _plantKey.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty ||
        (_plantKey.isEmpty && !_globalTenantAdminNoPlant)) {
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

  /// Brzi QR sken (nalog / naljepnica) — ikona u AppBar umjesto velike kartice.
  final bool showQrScanAction;
  final Future<void> Function(BuildContext context)? onOpenQrScan;
  final ProductionDashboardLayout dashboardLayout;
  final ValueChanged<ProductionDashboardLayout> onDashboardLayoutChanged;
  final List<ProductionDashboardModuleSection> moduleSections;
  final ProductionDashboardAccess dashboardAccess;

  const _ProductionHomePage({
    required this.companyData,
    required this.roleLabel,
    required this.companyId,
    required this.plantKey,
    required this.companyLine,
    this.showQrScanAction = false,
    this.onOpenQrScan,
    required this.dashboardLayout,
    required this.onDashboardLayoutChanged,
    required this.moduleSections,
    required this.dashboardAccess,
  });

  @override
  Widget build(BuildContext context) {
    final gap = kIsWeb ? 12.0 : 16.0;
    final pad = kIsWeb ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Početna'),
        actions: [
          if (showQrScanAction && onOpenQrScan != null)
            IconButton(
              tooltip: 'Skeniraj QR — nalog ili naljepnica s proizvodnog poda',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => onOpenQrScan!(context),
            ),
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
          ProductionDashboardLayoutSelector(
            value: dashboardLayout,
            onChanged: onDashboardLayoutChanged,
          ),
          SizedBox(height: gap * 0.75),
          ProductionDashboardHomeModulesView(
            layout: dashboardLayout,
            sections: moduleSections,
            access: dashboardAccess,
          ),
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
      return const Text(
        'Pogon: nije vezan na korisniku (globalni admin — biraj kontekst u modulima)',
        style: TextStyle(color: Colors.black87, fontSize: 13),
      );
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
    final isWordmark = CompanyLogoResolver.isWordmarkLogoUrl(u);
    final imageFit = isWordmark ? BoxFit.contain : BoxFit.cover;
    final imagePadding = isWordmark
        ? const EdgeInsets.all(_CompanyHeaderLogo.size * 0.12)
        : EdgeInsets.zero;

    return SizedBox(
      width: _CompanyHeaderLogo.size,
      height: _CompanyHeaderLogo.size,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, border: border),
        child: ClipRRect(
          borderRadius: radius,
          child: Padding(
            padding: imagePadding,
            child: Image.network(
              u,
              key: ValueKey<String>(u),
              fit: imageFit,
              alignment: Alignment.center,
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
