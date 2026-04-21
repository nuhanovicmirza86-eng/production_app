import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart'
    show ProductionAccessHelper, ProductionDashboardCard;
import '../../../../core/saas/production_module_keys.dart';
import '../../../quality/screens/quality_hub_screen.dart';
import '../../station/screens/station_tracking_setup_screen.dart';
import '../../station_pages/screens/production_station_pages_admin_screen.dart';
import '../config/station_screen_theme.dart';
import '../config/station_screen_theme_store.dart';
import '../config/station_tracking_setup_store.dart';
import '../models/production_operator_tracking_entry.dart';
import '../widgets/preparation_tracking_tab.dart';
import '../widgets/production_tracking_hub_nav_strip.dart';
import '../widgets/production_tracking_overview_tab.dart';
import '../widgets/station_appearance_editor_dialog.dart';
import 'production_tracking_ai_reports_screen.dart';
import 'production_tracking_devices_screen.dart';
import 'production_tracking_shifts_screen.dart';

/// Operativno praćenje toka proizvodnje: prvo **Pregled** (KPI, trend, strojevi, AI), zatim tri faze unosa
/// (pripremna → prva kontrola → završna kontrola). Svaki tab faze predstavlja zaseban dnevni radni list za unos;
/// Firestore model i štampa se dodaju iterativno.
///
/// Na webu i u punoj aplikaciji: lokalna tema (boje) i postavke preglednika (etiketa) vrijede za sve tri faze.
class ProductionOperatorTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionOperatorTrackingScreen({
    super.key,
    required this.companyData,
  });

  @override
  State<ProductionOperatorTrackingScreen> createState() =>
      _ProductionOperatorTrackingScreenState();
}

class _ProductionOperatorTrackingScreenState
    extends State<ProductionOperatorTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StationScreenAppearance _appearance = const StationScreenAppearance();

  /// Usklađeno s [StationTrackingSetupStore] nakon „Postavke preglednika“.
  late Map<String, dynamic> _effectiveCompanyData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _effectiveCompanyData = Map<String, dynamic>.from(widget.companyData);
    _applyLocalStationPrefsSync();
    _loadThemeAndStationPrefs();
  }

  void _applyLocalStationPrefsSync() {
    _effectiveCompanyData = Map<String, dynamic>.from(widget.companyData);
  }

  Future<void> _loadThemeAndStationPrefs() async {
    final appearance = await StationScreenThemeStore.load();
    final cid = (_effectiveCompanyData['companyId'] ?? '').toString().trim();
    if (cid.isEmpty) {
      if (mounted) setState(() => _appearance = appearance);
      return;
    }
    final setup = await StationTrackingSetupStore.load(cid);
    if (!mounted) return;
    setState(() {
      _appearance = appearance;
      _effectiveCompanyData = Map<String, dynamic>.from(widget.companyData);
      if (setup != null) {
        _effectiveCompanyData['stationLabelPrintingEnabled'] =
            setup.labelPrintingEnabled;
        _effectiveCompanyData['stationLabelLayout'] = setup.labelLayoutKey;
        _effectiveCompanyData['stationTrackingClassification'] =
            setup.classification;
      }
    });
  }

  @override
  void didUpdateWidget(ProductionOperatorTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyData != widget.companyData) {
      _applyLocalStationPrefsSync();
      _loadThemeAndStationPrefs();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _todayLine(BuildContext context) {
    final d = DateTime.now();
    return MaterialLocalizations.of(context).formatFullDate(d);
  }

  bool get _showStationPagesButton {
    final r = (widget.companyData['role'] ?? '').toString();
    return ProductionAccessHelper.canManage(
      role: r,
      card: ProductionDashboardCard.stationPages,
    );
  }

  bool get _showBrowserStationSetup {
    return ProductionAccessHelper.isAdminRole(
      widget.companyData['role'] ?? '',
    );
  }

  void _openHubDestination(BuildContext context, String label) {
    final cd = widget.companyData;
    final role = (cd['role'] ?? '').toString();

    void push(Widget page) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    }

    void needModule(String name) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Potreban je modul u pretplati: $name.')),
      );
    }

    void noAccess() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nemaš pravo pristupa ovom dijelu.'),
        ),
      );
    }

    switch (label) {
      case 'Kvaliteta':
        if (!ProductionModuleKeys.hasModule(cd, ProductionModuleKeys.quality)) {
          needModule('quality');
          return;
        }
        if (!ProductionAccessHelper.canView(
          role: role,
          card: ProductionDashboardCard.qualityManagement,
        )) {
          noAccess();
          return;
        }
        push(QualityHubScreen(companyData: cd));
        return;
      case 'Stanje uređaja':
        push(ProductionTrackingDevicesScreen(companyData: cd));
        return;
      case 'Smjene':
        push(ProductionTrackingShiftsScreen(companyData: cd));
        return;
      case 'AI izvještaji':
        push(ProductionTrackingAiReportsScreen(companyData: cd));
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label — nije prepoznato.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentTheme = Theme.of(context);
    final stationTheme = buildStationScreenTheme(parentTheme, _appearance);

    return AnimatedTheme(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      data: stationTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Praćenje proizvodnje'),
              actions: [
                if (_showStationPagesButton)
                  IconButton(
                    tooltip: 'Ekrani stanica za ovaj pogon',
                    icon: const Icon(Icons.settings_applications_outlined),
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => ProductionStationPagesAdminScreen(
                            companyData: widget.companyData,
                          ),
                        ),
                      );
                    },
                  ),
                if (_showBrowserStationSetup)
                  IconButton(
                    tooltip:
                        'Postavke ovog preglednika (pogon, klasifikacija, ispis etikete)',
                    icon: const Icon(Icons.tune),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (ctx) => StationTrackingSetupScreen(
                            companyData: _effectiveCompanyData,
                            onSaved: () {
                              Navigator.of(ctx).pop();
                              _loadThemeAndStationPrefs();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  tooltip: 'Izgled ekrana (boje i predlošci)',
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () async {
                    final next = await showStationAppearanceEditorDialog(
                      context: context,
                      current: _appearance,
                      allowCustomColors:
                          ProductionAccessHelper.canEditStationScreenCustomColors(
                        (widget.companyData['role'] ?? '').toString(),
                      ),
                    );
                    if (next == null || !mounted) return;
                    setState(() => _appearance = next);
                    await StationScreenThemeStore.save(next);
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Pregled'),
                  Tab(text: 'Pripremna'),
                  Tab(text: 'Prva kontrola'),
                  Tab(text: 'Završna kontrola'),
                ],
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductionTrackingHubNavStrip(
                  productionTabIndex: _tabController.index,
                  onSelectPregled: () {
                    _tabController.animateTo(0);
                  },
                  onSelectProizvodnjaFaze: () {
                    if (_tabController.index == 0) {
                      _tabController.animateTo(1);
                    } else {
                      _tabController.animateTo(_tabController.index.clamp(1, 3));
                    }
                  },
                  onSelectPlaceholder: (label) =>
                      _openHubDestination(context, label),
                ),
                if (_tabController.index > 0)
                  Material(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Radni dan: ${_todayLine(context)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ProductionTrackingOverviewTab(
                        companyData: _effectiveCompanyData,
                      ),
                      PreparationTrackingTab(companyData: _effectiveCompanyData),
                      PreparationTrackingTab(
                        companyData: _effectiveCompanyData,
                        phase: ProductionOperatorTrackingEntry.phaseFirstControl,
                      ),
                      PreparationTrackingTab(
                        companyData: _effectiveCompanyData,
                        phase:
                            ProductionOperatorTrackingEntry.phaseFinalControl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
