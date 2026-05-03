import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../models/ooe_live_status.dart';
import '../ooe_help_texts.dart';
import '../services/ooe_live_service.dart';
import '../services/ooe_machine_target_service.dart';
import '../widgets/ooe_info_icon.dart';
import '../widgets/ooe_line_group_header.dart';
import '../widgets/ooe_live_status_card.dart';
import 'ooe_alerts_screen.dart';
import 'ooe_alert_rules_screen.dart';
import 'ooe_loss_analysis_screen.dart';
import 'ooe_loss_reasons_screen.dart';
import 'ooe_machine_details_screen.dart';
import 'ooe_machine_targets_screen.dart';
import 'ooe_shift_context_screen.dart';
import 'ooe_daily_overview_screen.dart';
import 'capacity_overview_screen.dart';
import 'teep_analysis_screen.dart';
import 'ooe_shift_summary_screen.dart';
import 'scada_live_hub_screen.dart';

enum _LiveCardSort { ooeDesc, nameAsc }

enum _LineLayout { flat, byLine }

/// Live pregled OOE po mašinama (čita [ooe_live_status]).
class OoeDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// Kontekst iz druge analitike (npr. period zastoja) — prikaz ispod naslova.
  final String? analyticsContextHint;

  const OoeDashboardScreen({
    super.key,
    required this.companyData,
    this.analyticsContextHint,
  });

  @override
  State<OoeDashboardScreen> createState() => _OoeDashboardScreenState();
}

class _OoeDashboardScreenState extends State<OoeDashboardScreen> {
  late final Future<({ProductionPlantAssetsSnapshot assets, Map<String, double?> targets})>
      _assetsAndTargets;
  _LiveCardSort _liveSort = _LiveCardSort.ooeDesc;
  _LineLayout _lineLayout = _LineLayout.flat;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canAnalytics =>
      ProductionAccessHelper.canView(role: _role, card: ProductionDashboardCard.ooe) &&
      (ProductionAccessHelper.normalizeRole(_role) ==
              ProductionAccessHelper.roleProductionManager ||
          ProductionAccessHelper.normalizeRole(_role) ==
              ProductionAccessHelper.roleAdmin ||
          ProductionAccessHelper.normalizeRole(_role) ==
              ProductionAccessHelper.roleQualityOperator);

  bool get _canManageOoe => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  bool get _canViewOoe =>
      ProductionAccessHelper.canView(role: _role, card: ProductionDashboardCard.ooe);

  @override
  void initState() {
    super.initState();
    _assetsAndTargets = _loadAssetsAndTargets();
  }

  Future<({ProductionPlantAssetsSnapshot assets, Map<String, double?> targets})>
  _loadAssetsAndTargets() async {
    final assets = await ProductionTrackingAssetsService().loadForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
      limit: 128,
    );
    final svc = OoeMachineTargetService();
    final t = await svc.loadTargetOoeByMachineForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    return (assets: assets, targets: t);
  }

  void _push(Widget screen) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  static List<OoeLiveStatus> _sortedLive(
    List<OoeLiveStatus> list,
    Map<String, String> labelMap,
    _LiveCardSort sort,
  ) {
    final copy = List<OoeLiveStatus>.from(list);
    switch (sort) {
      case _LiveCardSort.ooeDesc:
        copy.sort((a, b) => b.currentShiftOoe.compareTo(a.currentShiftOoe));
      case _LiveCardSort.nameAsc:
        copy.sort((a, b) {
          final la = (labelMap[a.machineId] ?? a.machineId).toLowerCase();
          final lb = (labelMap[b.machineId] ?? b.machineId).toLowerCase();
          final c = la.compareTo(lb);
          if (c != 0) return c;
          return a.machineId.compareTo(b.machineId);
        });
    }
    return copy;
  }

  String? _effectiveLineKey(
    OoeLiveStatus st,
    ProductionPlantAssetsSnapshot assets,
  ) {
    final live = st.lineId?.trim();
    if (live != null && live.isNotEmpty) return live;
    final fromAsset = assets.machineLineKeyByMachineId[st.machineId]?.trim();
    if (fromAsset != null && fromAsset.isNotEmpty) return fromAsset;
    return null;
  }

  List<String?> _orderedLineBuckets(
    Set<String?> keys,
    Map<String, String> lineNames,
  ) {
    final list = keys.toList();
    list.sort((a, b) {
      final aa = a?.trim() ?? '';
      final bb = b?.trim() ?? '';
      final aEmpty = aa.isEmpty;
      final bEmpty = bb.isEmpty;
      if (aEmpty && !bEmpty) return 1;
      if (!aEmpty && bEmpty) return -1;
      if (aEmpty && bEmpty) return 0;
      final da = (lineNames[aa] ?? '').toLowerCase();
      final db = (lineNames[bb] ?? '').toLowerCase();
      final c = da.compareTo(db);
      if (c != 0) return c;
      return aa.compareTo(bb);
    });
    return list;
  }

  Widget _liveCard(
    OoeLiveStatus st,
    Map<String, String> labelMap, {
    Map<String, double?>? ooeTargetById,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OoeLiveStatusCard(
        status: st,
        machineDisplayName: labelMap[st.machineId],
        targetOoe: ooeTargetById?[st.machineId],
        onOpenDetails: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => OoeMachineDetailsScreen(
                companyData: widget.companyData,
                machineId: st.machineId,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedLiveList({
    required List<OoeLiveStatus> sorted,
    required Map<String, String> labelMap,
    required ProductionPlantAssetsSnapshot assets,
    required Map<String, double?> ooeTargetById,
  }) {
    final grouped = <String?, List<OoeLiveStatus>>{};
    for (final st in sorted) {
      final k = _effectiveLineKey(st, assets);
      grouped.putIfAbsent(k, () => []).add(st);
    }
    final keys = _orderedLineBuckets(
      grouped.keys.toSet(),
      assets.lineDisplayNameByLineKey,
    );
    final children = <Widget>[];
    for (final lineKey in keys) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: OoeLineGroupHeader(
            lineKey: lineKey,
            lineDisplayNameByKey: assets.lineDisplayNameByLineKey,
          ),
        ),
      );
      final group = grouped[lineKey];
      if (group == null) continue;
      for (final st in group) {
        children.add(
          _liveCard(st, labelMap, ooeTargetById: ooeTargetById),
        );
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final live = OoeLiveService();

    final hint = widget.analyticsContextHint?.trim();
    return Scaffold(
      appBar: AppBar(
        title: hint == null || hint.isEmpty
            ? const Text('OOE — praćenje uživo')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('OOE — praćenje uživo'),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 11,
                      color: (Theme.of(context).appBarTheme.foregroundColor ??
                              Theme.of(context).colorScheme.onSurface)
                          .withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
        actions: [
          OoeInfoIcon(
            tooltip: OoeHelpTexts.liveDashboardTooltip,
            dialogTitle: OoeHelpTexts.liveDashboardTitle,
            dialogBody: OoeHelpTexts.liveDashboardBody,
          ),
          if (_canViewOoe)
            IconButton(
              icon: const Icon(Icons.view_quilt_outlined),
              tooltip: 'Mrežni pregled strojeva (kao SCADA)',
              onPressed: () => _push(ScadaLiveHubScreen(companyData: widget.companyData)),
            ),
          if (_canAnalytics || _canManageOoe)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Još opcija',
              onSelected: (id) {
                switch (id) {
                  case 'alerts':
                    _push(OoeAlertsScreen(companyData: widget.companyData));
                  case 'alert_rules':
                    _push(OoeAlertRulesScreen(companyData: widget.companyData));
                  case 'machine_targets':
                    _push(OoeMachineTargetsScreen(companyData: widget.companyData));
                  case 'loss_analysis':
                    _push(OoeLossAnalysisScreen(companyData: widget.companyData));
                  case 'shift_summary':
                    _push(OoeShiftSummaryScreen(companyData: widget.companyData));
                  case 'daily_overview':
                    _push(OoeDailyOverviewScreen(companyData: widget.companyData));
                  case 'capacity_overview':
                    _push(CapacityOverviewScreen(companyData: widget.companyData));
                  case 'teep_analysis':
                    _push(TeepAnalysisScreen(companyData: widget.companyData));
                  case 'shift_context':
                    _push(OoeShiftContextScreen(companyData: widget.companyData));
                  case 'loss_reasons':
                    _push(OoeLossReasonsScreen(companyData: widget.companyData));
                }
              },
              itemBuilder: (ctx) => [
                if (_canAnalytics || _canManageOoe)
                  const PopupMenuItem(
                    value: 'alerts',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.notifications_active_outlined),
                      title: Text('Alarmi učinka'),
                    ),
                  ),
                if (_canManageOoe) ...[
                  const PopupMenuItem(
                    value: 'alert_rules',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.tune),
                      title: Text('Pragovi alarma'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'machine_targets',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.flag_outlined),
                      title: Text('Ciljevi učinka po stroju'),
                    ),
                  ),
                ],
                if (_canAnalytics)
                  const PopupMenuItem(
                    value: 'loss_analysis',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bar_chart_outlined),
                      title: Text('Analiza gubitaka'),
                    ),
                  ),
                if (_canAnalytics)
                  const PopupMenuItem(
                    value: 'shift_summary',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today_outlined),
                      title: Text('Sažetak smjene'),
                    ),
                  ),
                if (_canAnalytics)
                  const PopupMenuItem(
                    value: 'daily_overview',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.view_day_outlined),
                      title: Text('Dnevni pregled'),
                    ),
                  ),
                if (_canAnalytics)
                  const PopupMenuItem(
                    value: 'capacity_overview',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_month_outlined),
                      title: Text('Kapacitet i kalendar'),
                    ),
                  ),
                if (_canAnalytics)
                  const PopupMenuItem(
                    value: 'teep_analysis',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.area_chart_outlined),
                      title: Text('TEEP analitika'),
                    ),
                  ),
                if (_canManageOoe)
                  const PopupMenuItem(
                    value: 'shift_context',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.schedule_outlined),
                      title: Text('Kontekst smjene'),
                    ),
                  ),
                if (_canManageOoe)
                  const PopupMenuItem(
                    value: 'loss_reasons',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.rule_folder_outlined),
                      title: Text('Razlozi gubitaka'),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<
          ({
            ProductionPlantAssetsSnapshot assets,
            Map<String, double?> targets
          })>(
        future: _assetsAndTargets,
        builder: (context, assetSnap) {
          if (assetSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppErrorMapper.toMessage(assetSnap.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!assetSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = assetSnap.data!;
          final labelMap = <String, String>{};
          for (final m in data.assets.machines) {
            labelMap[m.id] = m.title;
          }

          final assets = data.assets;
          final ooeTargetById = data.targets;

          return StreamBuilder(
            stream: live.watchLiveForPlant(
              companyId: _companyId,
              plantKey: _plantKey,
            ),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppErrorMapper.toMessage(snap.error!),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final raw = snap.data ?? const [];
              if (raw.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.precision_manufacturing_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nema live zapisa za ovaj pogon',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pokreni izvršenje naloga na stroju koji je u imovini '
                          'pogona. OOE koristi istu šifru stroja kao praćenje.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OoeInfoIcon(
                          tooltip: OoeHelpTexts.liveDashboardTooltip,
                          dialogTitle: 'Kako se pojavi prikaz',
                          dialogBody:
                              'Nakon što postoji barem jedan zapis u ooe_live_status '
                              'za pogon, ovdje će se pojaviti kartice po stroju.',
                        ),
                      ],
                    ),
                  ),
                );
              }
              final list = _sortedLive(raw, labelMap, _liveSort);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: SegmentedButton<_LineLayout>(
                      segments: const [
                        ButtonSegment(
                          value: _LineLayout.flat,
                          label: Text('Svi strojevi'),
                          icon: Icon(Icons.view_list_outlined),
                        ),
                        ButtonSegment(
                          value: _LineLayout.byLine,
                          label: Text('Po liniji'),
                          icon: Icon(Icons.account_tree_outlined),
                        ),
                      ],
                      selected: {_lineLayout},
                      onSelectionChanged: (s) {
                        setState(() {
                          _lineLayout = s.first;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: SegmentedButton<_LiveCardSort>(
                      segments: const [
                        ButtonSegment(
                          value: _LiveCardSort.ooeDesc,
                          label: Text('OOE'),
                          icon: Icon(Icons.south),
                        ),
                        ButtonSegment(
                          value: _LiveCardSort.nameAsc,
                          label: Text('Naziv'),
                          icon: Icon(Icons.sort_by_alpha),
                        ),
                      ],
                      selected: {_liveSort},
                      onSelectionChanged: (s) {
                        setState(() {
                          _liveSort = s.first;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _lineLayout == _LineLayout.flat
                        ? ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              return _liveCard(
                                list[i],
                                labelMap,
                                ooeTargetById: ooeTargetById,
                              );
                            },
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            children: _buildGroupedLiveList(
                              sorted: list,
                              labelMap: labelMap,
                              assets: assets,
                              ooeTargetById: ooeTargetById,
                            ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
