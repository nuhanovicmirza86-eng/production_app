import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../ooe_help_texts.dart';
import '../models/teep_summary.dart';
import '../services/teep_callable_service.dart';
import '../services/teep_summary_service.dart';
import '../widgets/oee_ooe_teep_hierarchy_card.dart';
import '../widgets/ooe_info_icon.dart';
import 'capacity_overview_screen.dart';

/// Menadžerska TEEP analitika — trend po periodu (Callable [recomputeTeepPeriod]).
class TeepAnalysisScreen extends StatefulWidget {
  const TeepAnalysisScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<TeepAnalysisScreen> createState() => _TeepAnalysisScreenState();
}

class _TeepAnalysisScreenState extends State<TeepAnalysisScreen> {
  final _callable = TeepCallableService();
  final _scopeIdCtrl = TextEditingController();
  bool _recomputing = false;

  String _scopeType = 'plant';
  String _periodType = 'day';

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canRecomputeTeep => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  @override
  void dispose() {
    _scopeIdCtrl.dispose();
    super.dispose();
  }

  static String _formatDay(DateTime d) {
    final l = d.toLocal();
    return '${l.day}.${l.month}.${l.year}.';
  }

  static String _pct(double x) => '${(x * 100).toStringAsFixed(1)} %';

  static String _scopeLine(TeepSummary s) {
    switch (s.scopeType) {
      case 'line':
        return 'Linija ${s.scopeId}';
      case 'machine':
        return 'Stroj ${s.scopeId}';
      default:
        return 'Cijeli pogon';
    }
  }

  Future<void> _recomputeForDay(DateTime day) async {
    if (_recomputing || !mounted) return;

    final sid = _scopeIdCtrl.text.trim();
    if (_scopeType != 'plant' && sid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Za liniju ili stroj unesi ID (scope).'),
        ),
      );
      return;
    }

    setState(() => _recomputing = true);
    try {
      final r = await _callable.recomputeTeepPeriod(
        companyId: _companyId,
        plantKey: _plantKey,
        periodDateLocal: DateTime(day.year, day.month, day.day),
        scopeType: _scopeType,
        scopeId: _scopeType == 'plant' ? '' : sid,
        periodType: _periodType,
      );
      if (!mounted) return;
      final ok = r['success'] == true;
      final teep = r['teep'];
      final pk = r['periodKeyYmd'];
      final msg = ok && teep is num
          ? 'TEEP preračunat: ${_pct(teep.toDouble())}'
          : 'TEEP sažetak spremljen.';
      final tail = pk is String ? ' ($pk)' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg$tail')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  Future<void> _pickDayAndRecompute() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      await _recomputeForDay(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = TeepSummaryService();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TEEP analitika'),
        actions: [
          IconButton(
            tooltip: 'Kapacitet i kalendar',
            icon: const Icon(Icons.calendar_view_month_outlined),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CapacityOverviewScreen(
                    companyData: widget.companyData,
                  ),
                ),
              );
            },
          ),
          if (_canRecomputeTeep)
            _recomputing
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Preračun TEEP (Callable)',
                    icon: const Icon(Icons.refresh),
                    onPressed: _pickDayAndRecompute,
                  ),
          OoeInfoIcon(
            tooltip: OoeHelpTexts.teepAnalysisTooltip,
            dialogTitle: OoeHelpTexts.teepAnalysisTitle,
            dialogBody: OoeHelpTexts.teepAnalysisBody,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CompanyPlantLabelText(
              companyId: _companyId,
              plantKey: _plantKey,
              prefix: '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (_canRecomputeTeep) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Preračun',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      OoeInfoIcon(
                        tooltip: OoeHelpTexts.teepRecomputePanelTooltip,
                        dialogTitle: OoeHelpTexts.teepRecomputePanelTitle,
                        dialogBody: OoeHelpTexts.teepRecomputePanelBody,
                        iconSize: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'day', label: Text('Dan')),
                      ButtonSegment(value: 'week', label: Text('Tjedan')),
                      ButtonSegment(value: 'month', label: Text('Mjesec')),
                    ],
                    selected: {_periodType},
                    onSelectionChanged: _recomputing
                        ? null
                        : (s) => setState(() => _periodType = s.first),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _scopeType,
                    decoration: const InputDecoration(
                      labelText: 'Opseg',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'plant', child: Text('Cijeli pogon')),
                      DropdownMenuItem(value: 'line', child: Text('Linija')),
                      DropdownMenuItem(value: 'machine', child: Text('Stroj')),
                    ],
                    onChanged: _recomputing
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _scopeType = v);
                          },
                  ),
                  if (_scopeType != 'plant') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _scopeIdCtrl,
                      decoration: InputDecoration(
                        labelText: _scopeType == 'line'
                            ? 'ID linije'
                            : 'ID stroja',
                        border: const OutlineInputBorder(),
                      ),
                      readOnly: _recomputing,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _periodType == 'day'
                        ? 'Sidro je kalendarski dan.'
                        : _periodType == 'week'
                            ? 'Sidro: bilo koji dan u tjednu (računa se cijeli ISO tjedan od ponedjeljka).'
                            : 'Sidro: bilo koji dan u mjesecu (računa se cijeli mjesec).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: StreamBuilder<List<TeepSummary>>(
              stream: svc.watchRecentForPlant(
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
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 48,
                            color: scheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nema TEEP sažetaka za ovaj pogon',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Potrebni su capacity_calendars za sve dane u periodu '
                            '(ili tri broja kao zbir u Callable) i OOE sažeci smjene.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final first = list.first;
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    OeeOoeTeepHierarchyCard(summary: first),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Povijest perioda',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        OoeInfoIcon(
                          tooltip: OoeHelpTexts.teepHistorySectionTooltip,
                          dialogTitle: OoeHelpTexts.teepHistorySectionTitle,
                          dialogBody: OoeHelpTexts.teepHistorySectionBody,
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...list.map(
                      (s) => Card(
                        child: ListTile(
                          title: Text(
                            '${_formatDay(s.periodDate)} · ${s.periodType} · '
                            '${_scopeLine(s)}',
                          ),
                          subtitle: Text(
                            'OEE ${_pct(s.oee)} · OOE ${_pct(s.ooe)} · TEEP ${_pct(s.teep)} · '
                            'Util. ${_pct(s.utilization)}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
