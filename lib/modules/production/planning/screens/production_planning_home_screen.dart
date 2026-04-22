import 'package:flutter/material.dart';

import '../../../../core/ui/company_plant_label_text.dart';
import '../planning_session_controller.dart';
import '../planning_workflow_scope.dart';
import '../widgets/planning_context_sidebar.dart';
import '../widgets/planning_kpi_strip.dart';
import 'planning_schedule_tab.dart';
import 'production_capacity_overview_screen.dart';
import 'production_plan_details_screen.dart';
import 'production_plan_gantt_screen.dart';
import 'production_plan_execution_screen.dart';
import 'production_planning_screen.dart';
import 'production_plans_list_screen.dart';

/// Zajednički **planning workflow**: zaglavlje (pogon, horizont, scenarij, vremenski odsjek, akcije, KPI) i tabovi
/// Nalozi · Raspored · Provedba · Kapacitet.
class ProductionPlanningHomeScreen extends StatefulWidget {
  const ProductionPlanningHomeScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductionPlanningHomeScreen> createState() => _ProductionPlanningHomeScreenState();
}

class _ProductionPlanningHomeScreenState extends State<ProductionPlanningHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _sidebarMinWidth = 1280.0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _tab;
  late final PlanningSessionController _session;

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk => (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _session = PlanningSessionController(_cid, _pk)..loadPool();
  }

  @override
  void dispose() {
    _tab.dispose();
    _session.dispose();
    super.dispose();
  }

  Future<void> _onGenerate() async {
    if (_session.selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite barem jedan nalog (tab Nalozi).')),
      );
      return;
    }
    await _session.generatePlan();
    if (!mounted) return;
    if (_session.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_session.errorMessage!)),
      );
    } else {
      _tab.index = 1;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan generiran. Tab Raspored.')),
      );
    }
  }

  void _onSimulate() {
    _session.setScenarioIndex(1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Scenarij: Simulacija. Na tabu Nalozi podesite parametre pa kliknite Generiši plan (isti motor kao preračun, bez odvojenog MES pisanja).',
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    await _session.saveDraft();
    if (!mounted) return;
    if (_session.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_session.errorMessage!)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nacrt plana spremljen u bazu.')),
      );
    }
  }

  void _openGanttFullscreen() {
    final d = _session.ganttDto;
    if (d == null || d.operations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema Gantta (prvo generirajte plan).')),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionPlanGanttScreen(companyData: widget.companyData, planningSession: _session),
      ),
    );
  }

  void _openRelease() {
    final id = _session.lastSavedPlanId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema spremljenog nacrta. Spremite plan ili otvorite spremljene planove.'),
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionPlanDetailsScreen(companyData: widget.companyData, planId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        return PlanningWorkflowScope(
          session: _session,
          child: LayoutBuilder(
            builder: (context, c) {
              final showSidebar = c.maxWidth >= _sidebarMinWidth;
              return Scaffold(
                key: _scaffoldKey,
                endDrawer: showSidebar
                    ? null
                    : Drawer(
                        child: SafeArea(
                          child: PlanningContextSidebar(
                            session: _session,
                            onOpenGanttFullscreen: _openGanttFullscreen,
                            onSaveDraft: _onSave,
                          ),
                        ),
                      ),
                appBar: AppBar(
                  title: const Text('Planiranje proizvodnje'),
                  actions: [
                    IconButton(
                      tooltip: 'Spremljeni planovi',
                      onPressed: _session.isLocked
                          ? null
                          : () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => ProductionPlansListScreen(companyData: widget.companyData),
                                ),
                              );
                            },
                      icon: const Icon(Icons.view_list_outlined),
                    ),
                    IconButton(
                      tooltip: 'Osvježi pool naloga',
                      onPressed: _session.isLocked || _session.loadingPool ? null : _session.loadPool,
                      icon: const Icon(Icons.refresh),
                    ),
                    if (!showSidebar)
                      IconButton(
                        tooltip: 'Kontekst / KPI',
                        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                        icon: const Icon(Icons.view_sidebar),
                      ),
                  ],
                ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    if (_session.result != null)
                      PlanningKpiStrip(
                        r: _session.result!,
                        companyId: _cid,
                        plantKey: _pk,
                        compact: true,
                      ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Material(
                                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                  child: TabBar(
                                    controller: _tab,
                                    isScrollable: true,
                                    tabAlignment: TabAlignment.start,
                                    tabs: const [
                                      Tab(text: 'Nalozi', icon: Icon(Icons.checklist_outlined)),
                                      Tab(text: 'Raspored', icon: Icon(Icons.view_timeline_outlined)),
                                      Tab(text: 'Provedba', icon: Icon(Icons.fact_check_outlined)),
                                      Tab(text: 'Kapacitet', icon: Icon(Icons.speed_outlined)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tab,
                                    children: [
                                      const ProductionPlanningScreen(),
                                      PlanningScheduleTab(
                                        companyData: widget.companyData,
                                        onOpenFullscreen: _openGanttFullscreen,
                                      ),
                                      ProductionPlanExecutionScreen(companyData: widget.companyData),
                                      ProductionCapacityOverviewScreen(companyData: widget.companyData),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showSidebar)
                            PlanningContextSidebar(
                              session: _session,
                              onOpenGanttFullscreen: _openGanttFullscreen,
                              onSaveDraft: _onSave,
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
      },
    );
  }

  Widget _header(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                CompanyPlantLabelText(
                  companyId: _cid,
                  plantKey: _pk,
                  prefix: 'Pogon:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Text('·'),
                Text('Horizont (d):', style: Theme.of(context).textTheme.labelMedium),
                for (final d in const [1, 3, 7, 14, 30, 60])
                  FilterChip(
                    label: Text('$d'),
                    showCheckmark: false,
                    selected: _session.horizonDays == d,
                    onSelected: _session.isLocked
                        ? null
                        : (v) {
                            if (v) _session.setHorizonDays(d);
                          },
                  ),
                const Text('·'),
                Text('Prikaz vremena:', style: Theme.of(context).textTheme.labelMedium),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Smjena'), icon: Icon(Icons.schedule, size: 16)),
                    ButtonSegment(value: 1, label: Text('Dan'), icon: Icon(Icons.today, size: 16)),
                    ButtonSegment(value: 2, label: Text('Tjedan'), icon: Icon(Icons.date_range, size: 16)),
                  ],
                  selected: {_session.timeScopeIndex},
                  onSelectionChanged: _session.isLocked
                      ? null
                      : (s) {
                          if (s.isNotEmpty) _session.setTimeScopeIndex(s.first);
                        },
                ),
                const Text('·'),
                Text('Scenarij:', style: Theme.of(context).textTheme.labelMedium),
                for (var i = 0; i < PlanningSessionController.scenarioOptions.length; i++) ...[
                  if (PlanningSessionController.scenarioOptions[i].enabled)
                    FilterChip(
                      label: Text(PlanningSessionController.scenarioOptions[i].label),
                      selected: _session.scenarioIndex == i,
                      onSelected: _session.isLocked
                          ? null
                          : (v) {
                              if (v) _session.setScenarioIndex(i);
                            },
                    )
                  else
                    Tooltip(
                      message: 'Kasnije: veza s MES-om u realnom vremenu',
                      child: InputChip(
                        label: Text(PlanningSessionController.scenarioOptions[i].label),
                        isEnabled: false,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: _session.isLocked || _session.loadingPool ? null : _onGenerate,
                  icon: _session.busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Generiši plan'),
                ),
                OutlinedButton(
                  onPressed: _session.isLocked || _session.loadingPool ? null : _onGenerate,
                  child: const Text('Preračunaj'),
                ),
                OutlinedButton(
                  onPressed: _session.isLocked ? null : _onSimulate,
                  child: const Text('Simuliraj'),
                ),
                FilledButton.tonal(
                  onPressed: _session.saving || _session.lastSavedPlanId == null ? null : _openRelease,
                  child: const Text('Otpusti plan (detalji)'),
                ),
              ],
            ),
            if (_session.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _session.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
