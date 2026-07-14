import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/branding/operonix_ai_branding.dart';
import '../../../core/saas/production_module_keys.dart';
import '../../../features/station_evidence/screens/profile_driven_evidence_list_screen.dart';
import '../../../screens/about_screen.dart';
import '../../auth/register/screens/pending_users_screen.dart';
import '../../auth/screens/station_device_mode_screen.dart';
import '../../commercial/orders/screens/document_pdf_settings_screen.dart';
import '../../commercial/orders/screens/orders_list_screen.dart';
import '../../commercial/partners/screens/partners_screen.dart';
import '../../development/screens/development_projects_list_screen.dart';
import '../../finance_integrations/screens/finance_controlling_hub_screen.dart';
import '../../logistics/receipt/screens/station1_packed_boxes_logistics_screen.dart';
import '../../logistics/screens/logistics_hub_entry_screen.dart';
import '../../personal/work_time/screens/work_time_hub_screen.dart';
import '../../planning/aps/screens/aps_hub_screen.dart';
import '../../quality/screens/execute_inspection_screen.dart';
import '../../quality/screens/quality_hub_screen.dart';
import '../../sustainability/screens/carbon_footprint_screen.dart';
import '../../workforce/screens/workforce_dashboard_screen.dart';
import '../ai/screens/production_ai_hub_screen.dart';
import '../analytics/screens/operonix_analytics_dashboard_screen.dart';
import '../downtime/screens/downtimes_screen.dart';
import '../execution/screens/process_execution_hub_screen.dart';
import '../ooe/screens/factory_performance_dashboard_screen.dart';
import '../ooe/screens/ooe_dashboard_screen.dart';
import '../ooe/screens/teep_analysis_screen.dart';
import '../packing/services/packing_box_service.dart';
import '../planning/screens/production_planning_home_screen.dart';
import '../processes/screens/production_processes_list_screen.dart';
import '../production_orders/screens/production_orders_list_screen.dart';
import '../products/screens/products_list_screen.dart';
import '../issues/screens/production_problem_reporting_screen.dart';
import '../station_pages/screens/production_profile_stations_hub_screen.dart';
import '../station_pages/screens/production_stations_admin_screen.dart';
import '../station_pages/screens/station1_operator_launch_screen.dart';
import '../station_pages/screens/station2_operator_launch_screen.dart';
import '../station_pages/widgets/station_page_active_gate.dart';
import '../tracking/models/production_operator_tracking_entry.dart';
import '../tracking/screens/production_operator_tracking_screen.dart';
import '../tracking/screens/production_operator_tracking_station_screen.dart';
import '../tracking/screens/production_reports_hub_screen.dart';
import '../work_centers/screens/work_centers_list_screen.dart';
import 'models/production_dashboard_module.dart';
import 'production_dashboard_access.dart';
import 'widgets/production_dashboard_action_tile.dart';

/// Jedan izvor istine za module na početnom zaslonu (standard + ikonski prikaz).
class ProductionDashboardModuleCatalog {
  ProductionDashboardModuleCatalog({
    required this.access,
    required this.companyData,
    this.debugUnlockFinanceModule = false,
  });

  final ProductionDashboardAccess access;
  final Map<String, dynamic> companyData;
  final bool debugUnlockFinanceModule;

  List<ProductionDashboardModuleSection> buildSections(BuildContext context) {
    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
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
                ? Station1OperatorLaunchScreen(companyData: companyData)
                : phase == ProductionOperatorTrackingEntry.phaseFirstControl
                ? Station2OperatorLaunchScreen(companyData: companyData)
                : ProductionOperatorTrackingStationScreen(
                    companyData: companyData,
                    phase: phase,
                  ),
          ),
        ),
      );
    }

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

    final sections = <ProductionDashboardModuleSection>[];

    if (access.canViewCard(ProductionDashboardCard.registrations)) {
      sections.add(
        ProductionDashboardModuleSection(
          id: 'users',
          title: 'Korisnici',
          subtitle:
              'Administracija tenant računa (odobravanje novih prijava).',
          icon: Icons.manage_accounts_outlined,
          entries: [
            ProductionDashboardModuleEntry(
              id: 'users.registrations',
              icon: Icons.person_add_alt_1,
              title: 'Registracije',
              subtitle: 'Odobri nove korisnike (pending).',
              onTap: () => open(const PendingUsersScreen()),
            ),
          ],
        ),
      );
    }

    if (access.showProductionModuleSections) {
      final productionEntries = <ProductionDashboardModuleEntry>[];

      if (access.hasModule('production')) {
        if (access.canConfigureStationDevice()) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.device_mode',
              icon: Icons.display_settings_outlined,
              title: 'Način rada na ovom uređaju',
              subtitle:
                  'Cijela aplikacija ili jedna stanica nakon prijave (samo uloga Admin).',
              onTap: () => open(const StationDeviceModeScreen()),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.products)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.products',
              icon: Icons.inventory_2_outlined,
              title: 'Proizvodi',
              subtitle: 'Pregled i upravljanje proizvodima.',
              onTap: () => open(ProductsListScreen(companyData: companyData)),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.productionOrders)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.orders',
              icon: Icons.assignment,
              title: 'Proizvodni nalozi',
              subtitle: 'Lista naloga, detalji i statusi.',
              onTap: () =>
                  open(ProductionOrdersListScreen(companyData: companyData)),
            ),
          );
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.planning',
              icon: Icons.view_timeline_outlined,
              title: 'Planiranje proizvodnje',
              subtitle:
                  'Nalozi → Raspored → Provedba → Kapacitet; isti kontekst plana.',
              onTap: () =>
                  open(ProductionPlanningHomeScreen(companyData: companyData)),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.productionTracking)) {
          productionEntries.addAll([
            ProductionDashboardModuleEntry(
              id: 'production.tracking_tabs',
              icon: Icons.play_circle_outline,
              title: 'Praćenje proizvodnje (tabovi)',
              subtitle:
                  'Pregled KPI i trendova, zatim tri faze unosa u jednom ekranu.',
              onTap: () => open(
                ProductionOperatorTrackingScreen(companyData: companyData),
              ),
            ),
            ProductionDashboardModuleEntry(
              id: 'production.station_preparation',
              icon: Icons.fullscreen_outlined,
              title: 'Stanica: pripremna',
              subtitle:
                  'Puni zaslon — pripremna + traka prijave (QR uskoro). Jedan monitor.',
              onTap: () => openTrackingStation(
                ProductionOperatorTrackingEntry.phasePreparation,
              ),
            ),
            ProductionDashboardModuleEntry(
              id: 'production.station_first_control',
              icon: Icons.fact_check_outlined,
              title: 'Stanica: prva kontrola',
              subtitle: access.hasModule('quality')
                  ? 'Kontrola kvaliteta u tijeku obrade. Seriju unosite u „Praćenje proizvodnje“.'
                  : 'Puni zaslon — faza u izradi (placeholder do punog unosa).',
              onTap: () => access.hasModule('quality')
                  ? openQmsInspectionForStationPhase(
                      ProductionOperatorTrackingEntry.phaseFirstControl,
                    )
                  : openTrackingStation(
                      ProductionOperatorTrackingEntry.phaseFirstControl,
                    ),
            ),
            ProductionDashboardModuleEntry(
              id: 'production.station_final_control',
              icon: Icons.verified_outlined,
              title: 'Stanica: završna kontrola',
              subtitle: access.hasModule('quality')
                  ? 'Završna kontrola kvalitete. Seriju unosite u „Praćenje proizvodnje“.'
                  : 'Puni zaslon — faza u izradi (placeholder do punog unosa).',
              onTap: () => access.hasModule('quality')
                  ? openQmsInspectionForStationPhase(
                      ProductionOperatorTrackingEntry.phaseFinalControl,
                    )
                  : openTrackingStation(
                      ProductionOperatorTrackingEntry.phaseFinalControl,
                    ),
            ),
          ]);
          if (ProductionAccessHelper.canUseProfileStationRuntime(access.role)) {
            productionEntries.add(
              ProductionDashboardModuleEntry(
                id: 'production.profile_stations',
                icon: Icons.science_outlined,
                title: 'Operativne stanice (profil)',
                subtitle:
                    'Rad na stanicama prema profilu (npr. doziranje hemikalija).',
                onTap: () => open(
                  ProductionProfileStationsHubScreen(companyData: companyData),
                ),
              ),
            );
          }
        }
        if (access.hasModule('production') &&
            ProductionAccessHelper.canViewProfileDrivenEvidence(access.role)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.profile_evidence',
              icon: Icons.fact_check_outlined,
              title: 'Evidencije procesa — profile-driven',
              subtitle:
                  'Pregled završenih evidencija doziranja hemikalija i obrade otpadnih voda.',
              onTap: () => open(
                ProfileDrivenEvidenceListScreen(companyData: companyData),
              ),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.stationPages)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.station_pages',
              icon: Icons.touch_app_outlined,
              title: 'Stanice proizvodnje',
              subtitle:
                  'Konfiguracija proizvodnih i mašinskih stanica po kompaniji.',
              onTap: () => open(
                ProductionStationsAdminScreen(companyData: companyData),
              ),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.workCenters)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.work_centers',
              icon: Icons.precision_manufacturing_outlined,
              title: 'Radni centri',
              subtitle:
                  'Strojevi i linije: kapacitet, tip, povezivanje s učinkom i imovinom.',
              onTap: () => open(WorkCentersListScreen(companyData: companyData)),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.productionProcesses)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.processes',
              icon: Icons.account_tree_outlined,
              title: 'Procesi',
              subtitle:
                  'Definicije procesa: tip aktivnosti, kvaliteta, sljedljivost, povezani radni centri; rutiranje bira redoslijed.',
              onTap: () => open(
                ProductionProcessesListScreen(companyData: companyData),
              ),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.shifts)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.workforce',
              icon: Icons.groups_2_outlined,
              title: 'Radna snaga',
              subtitle:
                  'F1: profil, smjene, prisutnost, tko smije raditi na kojem mjestu.',
              onTap: () =>
                  open(WorkforceDashboardScreen(companyData: companyData)),
            ),
          );
        }
        if (access.canAccessPersonalWorkTime()) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.work_time',
              icon: Icons.access_time_filled,
              title: 'Obračun radnog vremena',
              subtitle:
                  'Prisutnost, dnevna i mjesečna slaganja, korekcije (modul Osobno).',
              onTap: () => open(WorkTimeHubScreen(companyData: companyData)),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.downtime)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.downtime',
              icon: Icons.warning_amber_outlined,
              title: 'Zastoji',
              subtitle:
                  'Vrijeme zastoja, povezivanje s nalogom i centrom, utjecaj na učinak, audit.',
              onTap: () => open(DowntimesScreen(companyData: companyData)),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.ooe)) {
          productionEntries.addAll([
            ProductionDashboardModuleEntry(
              id: 'production.ooe_dashboard',
              icon: Icons.dashboard_customize_outlined,
              title: 'OOE — učinak pogona',
              subtitle:
                  'Iskoristivost, gubici, raspoloživost u jednom pregledu (isti raspored, tamna tema).',
              onTap: () => open(
                FactoryPerformanceDashboardScreen(companyData: companyData),
              ),
            ),
            ProductionDashboardModuleEntry(
              id: 'production.ooe_live',
              icon: Icons.speed_outlined,
              title: 'OOE — praćenje uživo',
              subtitle:
                  'Trenutno stanje, gubici i sažetak smjene iz zabilježenih događaja.',
              onTap: () => open(OoeDashboardScreen(companyData: companyData)),
            ),
            ProductionDashboardModuleEntry(
              id: 'production.teep',
              icon: Icons.percent_outlined,
              title: 'TEEP i kapacitet',
              subtitle:
                  'Kalendar, iskorištenje, TEEP (dan / tjedan / mjesec, pogon ili stroj).',
              onTap: () => open(TeepAnalysisScreen(companyData: companyData)),
            ),
          ]);
        }
        if (access.canViewCard(ProductionDashboardCard.operonixAnalytics)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.analytics',
              icon: Icons.hub_outlined,
              title: 'Operonix Analytics',
              subtitle:
                  'Pregled učinkovitosti, Pareto, trendovi, smjene, sažetak s asistentom, detalji po centrima.',
              onTap: () => open(
                OperonixAnalyticsDashboardScreen(companyData: companyData),
              ),
            ),
          );
        }
        if (access.canAccessMaintenanceFaultBridge() &&
            access.canViewCard(ProductionDashboardCard.problemReporting)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.problem_reporting',
              icon: Icons.report_problem_outlined,
              title: 'Prijava problema',
              subtitle: 'Prijava kvara + pregled mojih prijava.',
              onTap: () => open(
                ProductionProblemReportingScreen(companyData: companyData),
              ),
            ),
          );
        }
        if (access.canViewCard(ProductionDashboardCard.processExecution)) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.process_execution',
              icon: Icons.science_outlined,
              title: 'Evidencija procesa',
              subtitle:
                  'Procesi u šifrarniku, nalozi i praćenje — IATF i izvršenje koraka.',
              onTap: () =>
                  open(ProcessExecutionHubScreen(companyData: companyData)),
            ),
          );
        }
        if (access.canShowReportsCard()) {
          productionEntries.add(
            ProductionDashboardModuleEntry(
              id: 'production.reports',
              icon: Icons.assessment_outlined,
              title: 'Izvještaji',
              subtitle: 'Otpad, dnevna proizvodnja, IATF / CAPA.',
              onTap: () =>
                  open(ProductionReportsHubScreen(companyData: companyData)),
            ),
          );
        }
      }

      if (productionEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'production',
            title: 'Proizvodnja',
            subtitle:
                'SaaS modul „production“: proizvodi, proizvodni nalozi, praćenje, stanice, izvještaji.',
            icon: Icons.precision_manufacturing_outlined,
            entries: productionEntries,
          ),
        );
      }

      final advancedPlanningEntries = <ProductionDashboardModuleEntry>[];
      if (ProductionModuleKeys.hasAdvancedPlanningModule(companyData) &&
          access.canViewCard(ProductionDashboardCard.advancedPlanning)) {
        advancedPlanningEntries.add(
          ProductionDashboardModuleEntry(
            id: 'advanced_planning.hub',
            icon: Icons.auto_graph_outlined,
            title: 'Napredno planiranje',
            subtitle:
                'Scenariji, kapacitet, optimizacija i raspored po resursima (APS).',
            onTap: () => open(ApsHubScreen(companyData: companyData)),
          ),
        );
      }
      if (advancedPlanningEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'advanced_planning',
            title: 'Napredno planiranje',
            subtitle:
                'Modul „advanced_planning“: scenariji, kapacitet, optimizacija, Gantt.',
            icon: Icons.auto_graph_outlined,
            entries: advancedPlanningEntries,
          ),
        );
      }

      final qualityEntries = <ProductionDashboardModuleEntry>[];
      if (access.hasModule('quality') &&
          access.canViewCard(ProductionDashboardCard.qualityManagement)) {
        qualityEntries.add(
          ProductionDashboardModuleEntry(
            id: 'quality.hub',
            icon: Icons.assignment_turned_in_outlined,
            title: 'Kvalitet — središnji izbornik',
            subtitle:
                'Kontrolni planovi, kontrole (sken), neslaganja, CAPA, IATF 16949.',
            onTap: () => open(QualityHubScreen(companyData: companyData)),
          ),
        );
      }
      if (qualityEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'quality',
            title: 'Kvalitet',
            subtitle:
                'SaaS modul „quality“: IATF-friendly kontrola — plan, izvršenje, neskladi, CAPA.',
            icon: Icons.fact_check_outlined,
            entries: qualityEntries,
          ),
        );
      }

      final developmentEntries = <ProductionDashboardModuleEntry>[];
      if (ProductionModuleKeys.hasModule(
            companyData,
            ProductionModuleKeys.development,
          ) &&
          access.canViewCard(ProductionDashboardCard.developmentGovernance)) {
        developmentEntries.add(
          ProductionDashboardModuleEntry(
            id: 'development.projects',
            icon: Icons.account_tree_outlined,
            title: 'Razvoj / NPI / Projekti',
            subtitle:
                'Portfolio, Stage-Gate, KPI i veza prema proizvodnji i kvalitetu (pretplata „development“).',
            onTap: () =>
                open(DevelopmentProjectsListScreen(companyData: companyData)),
          ),
        );
      }
      if (developmentEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'development',
            title: 'Razvoj i projekti',
            subtitle:
                'SaaS modul „development“: NPI, Stage-Gate, portfolio po poslovnoj godini i pogonu.',
            icon: Icons.account_tree_outlined,
            entries: developmentEntries,
          ),
        );
      }

      final financeEntries = <ProductionDashboardModuleEntry>[];
      if (access.canAccessFinanceIntegrations()) {
        financeEntries.add(
          ProductionDashboardModuleEntry(
            id: 'finance.integrations',
            icon: Icons.account_balance_outlined,
            title: 'Financije · ERP integracije',
            subtitle:
                'Operativna finansijska istina, KPI, troškovi i ERP sync (pretplata Finance & Controlling).',
            onTap: () => open(
              FinanceControllingHubScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockFinanceModule,
              ),
            ),
          ),
        );
      }
      if (financeEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'finance',
            title: 'Finance & Controlling',
            subtitle:
                'Modul „finance_controlling“ / „finance_integrations“: troškovi, KPI, budžeti, ERP.',
            icon: Icons.account_balance_outlined,
            entries: financeEntries,
          ),
        );
      }

      final commercialEntries = <ProductionDashboardModuleEntry>[];
      if (access.canAccessOrders()) {
        commercialEntries.addAll([
          ProductionDashboardModuleEntry(
            id: 'commercial.orders',
            icon: Icons.receipt_long_outlined,
            title: 'Narudžbe',
            subtitle: 'Pregled i rad s narudžbama.',
            onTap: () => open(OrdersListScreen(companyData: companyData)),
          ),
          ProductionDashboardModuleEntry(
            id: 'commercial.pdf_settings',
            icon: Icons.picture_as_pdf_outlined,
            title: 'Podaci za ispis PDF',
            subtitle: 'Zaglavlje, logo i podaci kompanije na dokumentima.',
            onTap: () =>
                open(DocumentPdfSettingsScreen(companyData: companyData)),
          ),
        ]);
      }
      if (access.canAccessPartners()) {
        commercialEntries.add(
          ProductionDashboardModuleEntry(
            id: 'commercial.partners',
            icon: Icons.groups_outlined,
            title: 'Kupci / dobavljači',
            subtitle: 'Partneri i poslovne veze.',
            onTap: () => open(PartnersScreen(companyData: companyData)),
          ),
        );
      }
      if (commercialEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'commercial',
            title: 'Komercijalno',
            subtitle:
                'Narudžbe i partneri u ovoj aplikaciji — dio iste „production“ pretplate (nije zaseban modul).',
            icon: Icons.storefront_outlined,
            entries: commercialEntries,
          ),
        );
      }

      final logisticsEntries = <ProductionDashboardModuleEntry>[];
      if (access.canAccessCentralWarehouse() && access.hasModule('logistics')) {
        logisticsEntries.add(
          ProductionDashboardModuleEntry(
            id: 'logistics.hub',
            icon: Icons.hub_outlined,
            title: 'Centralni magacin / Hub',
            subtitle:
                'Pregled zona, master MAG_*, WMS (prijem, kvaliteta, putaway, FIFO, otpremna), evidencija, QR.',
            onTap: () => open(LogisticsHubEntryScreen(companyData: companyData)),
          ),
        );
      }
      if (access.canAccessCentralWarehouse()) {
        logisticsEntries.add(
          ProductionDashboardModuleEntry(
            id: 'logistics.packed_boxes',
            icon: Icons.move_to_inbox_outlined,
            title: 'Upakovane kutije Stanica 1',
            subtitle:
                'Lista zatvorenih kutija i prijem u magacin skeniranjem QR-a.',
            onTap: () => open(
              Station1PackedBoxesLogisticsScreen(companyData: companyData),
            ),
            customTileBuilder: (ctx) => StreamBuilder(
              stream: PackingBoxService().watchClosedPendingReceipt(
                companyId: access.companyId,
                plantKey: access.plantKey,
              ),
              builder: (context, snap) {
                final count = snap.data?.length ?? 0;
                return ProductionDashboardActionTile(
                  icon: Icons.move_to_inbox_outlined,
                  title: 'Upakovane kutije Stanica 1',
                  subtitle:
                      'Lista zatvorenih kutija i prijem u magacin skeniranjem QR-a.',
                  noticeText: count > 0
                      ? access.packedBoxesPendingNotice(count)
                      : null,
                  onTap: () => open(
                    Station1PackedBoxesLogisticsScreen(
                      companyData: companyData,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
      if (logisticsEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'logistics',
            title: 'Logistika i magacin',
            subtitle: access.logisticsSectionSubtitle(),
            icon: Icons.local_shipping_outlined,
            entries: logisticsEntries,
          ),
        );
      }

      final sustainabilityEntries = <ProductionDashboardModuleEntry>[];
      if (access.canViewCard(ProductionDashboardCard.carbonFootprint)) {
        sustainabilityEntries.add(
          ProductionDashboardModuleEntry(
            id: 'sustainability.carbon',
            icon: Icons.eco_outlined,
            title: 'Karbonski otisak',
            subtitle: 'Praćenje i evidencija utjecaja.',
            onTap: () => open(CarbonFootprintScreen(companyData: companyData)),
          ),
        );
      }
      if (sustainabilityEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'sustainability',
            title: 'Održivost',
            subtitle:
                'Karbonski otisak uz proizvodnju (isti tenant; ovisi o uključenim izvještajima).',
            icon: Icons.eco_outlined,
            entries: sustainabilityEntries,
          ),
        );
      }

      final aiEntries = <ProductionDashboardModuleEntry>[];
      if (access.hasAiProductionAiHubAccess() &&
          access.canViewCard(ProductionDashboardCard.aiAssistant)) {
        aiEntries.add(
          ProductionDashboardModuleEntry(
            id: 'ai.hub',
            icon: Icons.smart_toy_outlined,
            title: kOperonixAiAssistantTitle,
            subtitle: 'Chat, analitika i izvještaji (SaaS AI paketi).',
            onTap: () => open(ProductionAiHubScreen(companyData: companyData)),
          ),
        );
      }
      if (aiEntries.isNotEmpty) {
        sections.add(
          ProductionDashboardModuleSection(
            id: 'ai',
            title: kOperonixAiShortLabel,
            subtitle:
                'Dodatni SaaS paketi (npr. ai_assistant_production, ai_reports) uz osnovnu pretplatu.',
            icon: Icons.smart_toy_outlined,
            entries: aiEntries,
          ),
        );
      }
    }

    sections.add(
      ProductionDashboardModuleSection(
        id: 'general',
        title: 'Općenito',
        subtitle: 'Informacije o aplikaciji.',
        icon: Icons.info_outline,
        entries: [
          ProductionDashboardModuleEntry(
            id: 'general.about',
            icon: Icons.article_outlined,
            title: 'O aplikaciji',
            subtitle: 'Verzija, autor, informacije.',
            onTap: () => open(const AboutScreen()),
          ),
        ],
      ),
    );

    return sections.where((s) => s.isVisible).toList(growable: false);
  }
}
