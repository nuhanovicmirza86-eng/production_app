import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../../tracking/services/production_asset_display_lookup.dart';
import '../planning_scheduled_ops_export.dart';
import '../planning_scheduled_ops_pdf_export.dart';
import '../planning_ui_formatters.dart';
import '../models/saved_plan_scheduled_row.dart';
import '../models/saved_production_plan_details.dart';
import '../services/production_plan_persistence_service.dart';
import 'production_plan_gantt_screen.dart';

/// Detalj spremljenog nacrta: KPI, upute i cijela lista upozorenja/konflikata iz baze.
class ProductionPlanDetailsScreen extends StatefulWidget {
  const ProductionPlanDetailsScreen({
    super.key,
    required this.companyData,
    required this.planId,
  });

  final Map<String, dynamic> companyData;
  final String planId;

  @override
  State<ProductionPlanDetailsScreen> createState() =>
      _ProductionPlanDetailsScreenState();
}

class _ProductionPlanDetailsScreenState extends State<ProductionPlanDetailsScreen> {
  final _persistence = ProductionPlanPersistenceService();
  SavedProductionPlanDetails? _detail;
  /// Ime stroja (šifarnik) za KPI bottleneck — ne prikazujemo interni ID.
  String? _bottleneckResourceLabel;
  List<SavedPlanScheduledRow> _scheduledRows = const [];
  /// Ako učitavanje podkolekcije nije uspjelo, detalj plana i dalje je vidljiv.
  bool _scheduledTableFailed = false;
  bool _statusBusy = false;
  bool _exportBusy = false;
  bool _pdfBusy = false;
  bool _loading = true;
  String? _error;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk => (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canAdvancePlanStatus {
    final r = ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    return r == ProductionAccessHelper.roleAdmin ||
        r == ProductionAccessHelper.roleProductionManager ||
        r == ProductionAccessHelper.roleSupervisor;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final first = _detail == null;
    if (first) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final d = await _persistence.loadPlanDetails(
        planId: widget.planId,
        companyId: _cid,
        plantKey: _pk,
      );
      String? bn;
      if (d.bottleneckMachineId != null && d.bottleneckMachineId!.isNotEmpty) {
        final look = await ProductionAssetDisplayLookup.loadForPlant(
          companyId: _cid,
          plantKey: _pk,
          limit: 500,
        );
        bn = look.resolve(d.bottleneckMachineId);
      }
      var sched = const <SavedPlanScheduledRow>[];
      var schedFailed = false;
      try {
        sched = await _persistence.loadScheduledOperationRows(
          planId: widget.planId,
          companyId: _cid,
          plantKey: _pk,
        );
      } catch (_) {
        schedFailed = true;
      }
      if (mounted) {
        setState(() {
          _detail = d;
          _bottleneckResourceLabel = bn;
          _scheduledRows = sched;
          _scheduledTableFailed = schedFailed;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (first) _error = 'Nije moguće učitati detalj plana.';
        });
      }
    } finally {
      if (mounted && first) setState(() => _loading = false);
    }
  }

  void _openGantt() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionPlanGanttScreen(
          companyData: widget.companyData,
          planId: widget.planId,
        ),
      ),
    );
  }

  Future<void> _advanceStatus(String next) async {
    if (_statusBusy) return;
    setState(() => _statusBusy = true);
    try {
      await _persistence.updatePlanStatus(
        planId: widget.planId,
        companyId: _cid,
        plantKey: _pk,
        newStatus: next,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status plana je ažuriran.')),
        );
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Promjena statusa nije uspjela. Potrebne su uloga (supervizor / menadžer / admin) i mreža.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _exportCsv() async {
    final d = _detail;
    if (d == null || _scheduledRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nema operacija za izvoz u CSV.')),
        );
      }
      return;
    }
    setState(() => _exportBusy = true);
    try {
      final name =
          'plan_${d.planCode.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}_operacije.csv';
      await PlanningScheduledOpsExport.shareCsv(
        fileName: name,
        planCode: d.planCode,
        rows: _scheduledRows,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izvoz u CSV nije uspio.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _openPdfPreview() async {
    final d = _detail;
    if (d == null || _scheduledRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nema operacija za PDF.')),
        );
      }
      return;
    }
    setState(() => _pdfBusy = true);
    try {
      String? plantLine;
      if (_cid.isNotEmpty && _pk.isNotEmpty) {
        plantLine = await CompanyPlantDisplayName.resolve(
          companyId: _cid,
          plantKey: _pk,
        );
      }
      await PlanningScheduledOpsPdfExport.openPreview(
        rows: _scheduledRows,
        planCode: d.planCode,
        companyPlantLine: plantLine,
        planStatusLabel: PlanningUiFormatters.planStatus(d.status),
        strategyLine: d.strategy.isNotEmpty
            ? PlanningUiFormatters.engineStrategy(d.strategy)
            : null,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Otvaranje PDF-a nije uspjelo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _sharePdf() async {
    final d = _detail;
    if (d == null || _scheduledRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nema operacija za PDF.')),
        );
      }
      return;
    }
    setState(() => _pdfBusy = true);
    try {
      String? plantLine;
      if (_cid.isNotEmpty && _pk.isNotEmpty) {
        plantLine = await CompanyPlantDisplayName.resolve(
          companyId: _cid,
          plantKey: _pk,
        );
      }
      await PlanningScheduledOpsPdfExport.sharePdfFile(
        rows: _scheduledRows,
        planCode: d.planCode,
        companyPlantLine: plantLine,
        planStatusLabel: PlanningUiFormatters.planStatus(d.status),
        strategyLine: d.strategy.isNotEmpty
            ? PlanningUiFormatters.engineStrategy(d.strategy)
            : null,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dijeljenje PDF-a nije uspjelo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalj plana')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalj plana')),
        body: Center(
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final d = _detail;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalj plana')),
        body: const Center(child: Text('Nema podataka.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(d.planCode),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGantt,
        icon: const Icon(Icons.view_timeline_outlined),
        label: const Text('Gantt'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          CompanyPlantLabelText(
            companyId: _cid,
            plantKey: _pk,
            prefix: '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openGantt,
            icon: const Icon(Icons.view_timeline_outlined),
            label: const Text('Otvori vremenski prikaz (Gantt)'),
          ),
          const SizedBox(height: 20),
          Text('Akcije', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: (_exportBusy || _pdfBusy || _statusBusy || _scheduledRows.isEmpty)
                    ? null
                    : _exportCsv,
                icon: _exportBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_chart_outlined),
                label: Text(
                  _scheduledRows.isEmpty
                      ? 'CSV (nema operacija u tablici)'
                      : 'CSV (tablica)',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: (_exportBusy || _pdfBusy || _statusBusy || _scheduledRows.isEmpty)
                    ? null
                    : _openPdfPreview,
                icon: _pdfBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF — pregled i ispis'),
              ),
              OutlinedButton.icon(
                onPressed: (_exportBusy || _pdfBusy || _statusBusy || _scheduledRows.isEmpty)
                    ? null
                    : _sharePdf,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Pošalji PDF'),
              ),
              if (_canAdvancePlanStatus) ...[
                ...() {
                  final next = PlanningUiFormatters.nextPlanWorkflowStatus(d.status);
                  if (next == null) {
                    return <Widget>[
                      Text(
                        'Plan je objavljen; u ovom toku nema sljedećeg statusa.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ];
                  }
                  return <Widget>[
                    FilledButton(
                      onPressed: _statusBusy ? null : () => _advanceStatus(next),
                      child: _statusBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(PlanningUiFormatters.planWorkflowAdvanceLabel(next)),
                    ),
                  ];
                }(),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Izvoz: CSV za Excel. PDF otvara sustavski pregled (tamo i ispis); „Pošalji PDF” dijeli datoteku (e-pošta, upravitelj datoteka, …).',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (_canAdvancePlanStatus) ...[
            const SizedBox(height: 4),
            Text(
              'Promjenu statusa: supervizor, menadžer proizvodnje ili admin (usklađeno s pravilima baze).',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Osnovno', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Labeled('Status', PlanningUiFormatters.planStatus(d.status)),
          if (d.strategy.isNotEmpty)
            _Labeled(
              'Strategija (motor)',
              PlanningUiFormatters.engineStrategy(d.strategy),
            ),
          if (d.source.isNotEmpty) _Labeled('Izvor', d.source),
          _Labeled('Kreirano', PlanningUiFormatters.formatDateTime(d.createdAt)),
          _Labeled(
            'Horizont (početak — kraj)',
            '${PlanningUiFormatters.formatDateTime(d.planningHorizonStart)}  —  '
            '${PlanningUiFormatters.formatDateTime(d.planningHorizonEnd)}',
          ),
          const SizedBox(height: 20),
          Text('KPI', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Labeled('Ukupno naloga u obradi (plan)', d.totalOrders.toString()),
          _Labeled('Zakazanih operacija', d.scheduledOperationCount.toString()),
          _Labeled('Mogućih naloga (izračun)', d.feasibleOrderCount.toString()),
          _Labeled('Nemogućih (prekid / horizont / stroj)', d.infeasibleOrderCount.toString()),
          _Labeled('Broj stavki upozorenja', d.totalConflicts.toString()),
          if (d.onTimeRate01 != null)
            _Labeled('U odnosu na tražene rokove', '${(d.onTimeRate01! * 100).toStringAsFixed(0)} %'),
          if (d.totalLatenessMinutes > 0)
            _Labeled('Zbir kašnjenja (min)', d.totalLatenessMinutes.toString()),
          if (d.estimatedUtilization01 != null)
            _Labeled('Gruba prosječna iskoristivost (horizont)', '${(d.estimatedUtilization01! * 100).toStringAsFixed(0)} %'),
          _Labeled(
            'Bottleneck u rasporedu',
            d.hasBottleneckHint
                ? (_bottleneckResourceLabel != null
                    ? 'Najzauzetiji resurs u horizontu: $_bottleneckResourceLabel'
                    : 'U izračunu je označen resurs s najvećim zauzećem; naziv trenutno nije moguće prikazati iz šifrarnika.')
                : 'Nije u ovom nacrtu zabilježeno (npr. nema zakazanih operacija).',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Zakazane operacije', style: Theme.of(context).textTheme.titleMedium),
              if (_scheduledRows.isNotEmpty) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text('${_scheduledRows.length}'),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (_scheduledTableFailed)
            Text(
              'Popis operacija trenutno nije moguće učitati. Pokušajte osvježiti (ikona gore) ili provjerite mrežu i prava.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            )
          else if (_scheduledRows.isEmpty)
            Text(
              d.scheduledOperationCount > 0
                  ? 'Operacije nisu učitane (podaci mogu biti u toku) ili nema zapisa u podkolekciji.'
                  : 'Nema zakazanih operacija u ovom nacrtu.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            _ScheduledOperationsTable(rows: _scheduledRows),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Konflikti i upozorenja', style: Theme.of(context).textTheme.titleMedium),
              if (d.conflicts.isNotEmpty) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text('${d.conflicts.length}'),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (d.conflicts.isEmpty)
            Text(
              'Nema stavki u listi (ili je lista prazna u dokumentu).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...d.conflicts.map(
              (c) {
                final hasSug = c.suggestion != null && c.suggestion!.trim().isNotEmpty;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: hasSug
                      ? ExpansionTile(
                          title: Text(
                            PlanningUiFormatters.conflictTypeLabel(c.type),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            c.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Text(
                                  'Prijedlog: ${c.suggestion!.trim()}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListTile(
                          title: Text(
                            PlanningUiFormatters.conflictTypeLabel(c.type),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            c.message,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ScheduledOperationsTable extends StatelessWidget {
  const _ScheduledOperationsTable({required this.rows});

  final List<SavedPlanScheduledRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 600),
        child: DataTable(
          columnSpacing: 12,
          horizontalMargin: 8,
          headingRowColor: WidgetStatePropertyAll(c.surfaceContainerHighest),
          columns: const [
            DataColumn(label: Text('R.b.', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Nalog', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Korak', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Operacija', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Stroj', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Početak', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Kraj', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(
              label: Text('Min', style: TextStyle(fontWeight: FontWeight.w600)),
              numeric: true,
            ),
          ],
          rows: [
            for (var i = 0; i < rows.length; i++)
              DataRow(
                cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(rows[i].productionOrderCode)),
                  DataCell(Text('${rows[i].operationSequence}')),
                  DataCell(
                    Text(
                      (rows[i].operationLabel == null || rows[i].operationLabel!.isEmpty)
                          ? '—'
                          : rows[i].operationLabel!,
                    ),
                  ),
                  DataCell(Text(rows[i].resourceDisplayName)),
                  DataCell(
                    Text(
                      PlanningUiFormatters.formatDateTime(rows[i].plannedStart),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      PlanningUiFormatters.formatDateTime(rows[i].plannedEnd),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(Text('${rows[i].durationMinutes}')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
