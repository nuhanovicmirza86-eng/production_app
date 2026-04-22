import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/company_plant_label_text.dart';
import '../../production_orders/models/production_order_model.dart';
import '../../production_orders/services/production_order_service.dart';
import '../../tracking/services/production_asset_display_lookup.dart';
import '../models/planning_engine_result.dart';
import '../planning_ui_formatters.dart';
import '../services/planning_engine_service.dart';
import '../services/planning_gantt_dto.dart';
import '../services/production_plan_persistence_service.dart';
import '../widgets/planning_kpi_strip.dart';
import 'production_plan_details_screen.dart';
import 'production_plan_gantt_screen.dart';
import 'production_plans_list_screen.dart';

/// Glavni **industrijski hub** planiranja: komandna traka, KPI, radni prostor (pool → Gantt → detalj) i donji tabovi.
///
/// Vidi: `maintenance_app/docs/architecture/PRODUCTION_PLANNING_UI_LAYOUT.md`.
const double _kPlanWideBreakpoint = 1100;

class ProductionPlanningHubScreen extends StatefulWidget {
  const ProductionPlanningHubScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductionPlanningHubScreen> createState() => _ProductionPlanningHubScreenState();
}

class _ProductionPlanningHubScreenState extends State<ProductionPlanningHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _workbenchTab;
  final _engine = PlanningEngineService();
  final _orderService = ProductionOrderService();
  final _persistence = ProductionPlanPersistenceService();

  PlanningEngineResult? _result;
  String? _lastSavedPlanId;
  bool _busy = false;
  String? _error;
  bool _saving = false;
  int _horizonDays = 14;
  final _perfCtrl = TextEditingController(text: '0.65');
  final _setupCtrl = TextEditingController(text: '30');
  final _cycleCtrl = TextEditingController(text: '60');

  List<ProductionOrderModel> _pool = [];
  final Set<String> _selected = {};
  bool _loadingPool = true;
  String? _poolError;
  String _searchQuery = '';
  int _scenarioIndex = 0;
  ProductionOrderModel? _selectedOrder;
  Map<String, String> _ganttMachineLabels = const {};
  String? _ganttLabelForResultId;

  bool get _uiLocked => _busy || _saving;
  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk => (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _workbenchTab = TabController(length: 5, vsync: this);
    _loadPool();
  }

  @override
  void dispose() {
    _workbenchTab.dispose();
    _perfCtrl.dispose();
    _setupCtrl.dispose();
    _cycleCtrl.dispose();
    super.dispose();
  }

  static const _scenarioOptions = <({String id, String label, bool enabled})>[
    (id: 'draft', label: 'Nacrt', enabled: true),
    (id: 'sim', label: 'Simulacija', enabled: true),
    (id: 'ok', label: 'Potvrđeno', enabled: true),
    (id: 'live', label: 'U produkciji', enabled: false),
  ];

  List<ProductionOrderModel> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _pool;
    return _pool.where((o) {
      return o.productionOrderCode.toLowerCase().contains(q) ||
          o.productName.toLowerCase().contains(q) ||
          o.productCode.toLowerCase().contains(q);
    }).toList();
  }

  PlanningGanttDto? get _ganttDto {
    final r = _result;
    if (r == null) return null;
    return PlanningGanttDto.fromEngineResult(r);
  }

  Color _poolRisk(ProductionOrderModel o) {
    final hasMachine = (o.machineId ?? '').trim().isNotEmpty;
    if (!hasMachine) return Colors.red;
    final due = o.requestedDeliveryDate;
    if (due != null) {
      final d = due.difference(DateTime.now());
      if (d.inDays < 3) return Colors.amber;
    }
    return Colors.green;
  }

  Future<void> _loadPool() async {
    if (_cid.isEmpty || _pk.isEmpty) {
      setState(() {
        _loadingPool = false;
        _poolError = 'Nedostaje podatak o kompaniji ili pogonu.';
        _pool = [];
        _selected.clear();
        _selectedOrder = null;
      });
      return;
    }
    setState(() {
      _loadingPool = true;
      _poolError = null;
    });
    try {
      final all = await _orderService.getOrders(companyId: _cid, plantKey: _pk);
      var list = all.where((o) {
        final s = o.status.toLowerCase();
        return s == 'released' || s == 'in_progress';
      }).toList();
      list.sort((a, b) {
        final da = a.requestedDeliveryDate;
        final db = b.requestedDeliveryDate;
        if (da != null && db != null) {
          final c = da.compareTo(db);
          if (c != 0) return c;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      if (!mounted) return;
      setState(() {
        _pool = list;
        _selected
          ..clear()
          ..addAll(list.map((e) => e.id));
        _selectedOrder = list.isNotEmpty ? list.first : null;
        _loadingPool = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPool = false;
          _pool = [];
          _selected.clear();
          _poolError = 'Učitavanje naloga nije uspjelo. Pokušajte kasnije.';
          _selectedOrder = null;
        });
      }
    }
  }

  Future<void> _resolveGanttLabels(PlanningGanttDto d) async {
    final rid = _result?.plan.id;
    if (d.operations.isEmpty) {
      if (mounted) {
        setState(() {
          _ganttMachineLabels = const {};
          _ganttLabelForResultId = rid;
        });
      }
      return;
    }
    try {
      final lookup = await ProductionAssetDisplayLookup.loadForPlant(
        companyId: _cid,
        plantKey: _pk,
        limit: 500,
      );
      final ids = <String>{for (final o in d.operations) o.machineId};
      final m = <String, String>{};
      for (final id in ids) {
        m[id] = id.isEmpty ? 'Nije dodijeljen stroj' : lookup.resolve(id);
      }
      if (mounted) {
        setState(() {
          _ganttMachineLabels = m;
          _ganttLabelForResultId = rid;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ganttMachineLabels = const {};
          _ganttLabelForResultId = rid;
        });
      }
    }
  }

  void _onResultChanged() {
    final d = _ganttDto;
    if (d == null) {
      if (mounted) {
        setState(() {
          _ganttMachineLabels = const {};
          _ganttLabelForResultId = null;
        });
      }
    } else {
      _resolveGanttLabels(d);
    }
  }

  void _selectAll() {
    setState(() {
      _selected
        ..clear()
        ..addAll(_pool.map((e) => e.id));
    });
  }

  void _selectFiltered() {
    setState(() {
      for (final o in _filtered) {
        _selected.add(o.id);
      }
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  void _clearFilteredFromSelection() {
    setState(() {
      for (final o in _filtered) {
        _selected.remove(o.id);
      }
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Nacrt';
      case 'released':
        return 'Pušten';
      case 'in_progress':
        return 'U toku';
      case 'paused':
        return 'Pauziran';
      case 'completed':
        return 'Završen';
      case 'closed':
        return 'Zatvoren';
      case 'cancelled':
        return 'Otkazan';
      default:
        return status;
    }
  }

  String _formatQty(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  double _remaining(ProductionOrderModel o) {
    return (o.plannedQty - o.producedGoodQty).clamp(0, double.infinity);
  }

  void _openGanttFullscreenFromMemory() {
    final d = _ganttDto;
    if (d == null || d.operations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema zakazanih operacija za Gantt.'),
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionPlanGanttScreen(
          companyData: widget.companyData,
          gantt: d,
        ),
      ),
    );
  }

  Future<void> _saveDraft() async {
    final r = _result;
    if (r == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await _persistence.saveDraftFromEngineResult(
        result: r,
        companyId: _cid,
        plantKey: _pk,
      );
      if (mounted) {
        setState(() => _lastSavedPlanId = id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nacrt plana je spremljen u bazu.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Spremanje nije uspjelo. Provjerite uloge i mrežu.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openGanttFromFirestore() {
    final id = _lastSavedPlanId;
    if (id == null || id.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionPlanGanttScreen(
          companyData: widget.companyData,
          planId: id,
        ),
      ),
    );
  }

  void _openDetailsForLastSave() {
    final id = _lastSavedPlanId;
    if (id == null || id.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionPlanDetailsScreen(
          companyData: widget.companyData,
          planId: id,
        ),
      ),
    );
  }

  void _showCompareSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Usporedba scenarija — u pripremi (odaberite dva nacrta i usporedite).'),
      ),
    );
  }

  Future<void> _run() async {
    if (_cid.isEmpty || _pk.isEmpty) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite barem jedan nalog u poolu.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final start = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final end = start.add(Duration(days: _horizonDays));
      final perf = double.tryParse(_perfCtrl.text.replaceAll(',', '.')) ?? 0.65;
      final setup = double.tryParse(_setupCtrl.text.replaceAll(',', '.')) ?? 30;
      final cyc = double.tryParse(_cycleCtrl.text.replaceAll(',', '.')) ?? 60;
      final allPoolSelected = _pool.isNotEmpty &&
          _pool.every((o) => _selected.contains(o.id)) &&
          _selected.length == _pool.length;
      final r = await _engine.generateDraftPlan(
        companyId: _cid,
        plantKey: _pk,
        horizonStart: start,
        horizonEnd: end,
        productionOrderIds: allPoolSelected ? null : _selected.toList(),
        performanceFactor: perf,
        setupMinutes: setup,
        cycleSecPerUnit: cyc,
      );
      if (mounted) {
        setState(() => _result = r);
        _onResultChanged();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _commandBar(BuildContext context) {
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
              runSpacing: 6,
              children: [
                CompanyPlantLabelText(
                  companyId: _cid,
                  plantKey: _pk,
                  prefix: '',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Text('·'),
                Text('Horizont (d):', style: Theme.of(context).textTheme.labelMedium),
                ..._horizonChips(),
                const Text('·'),
                Text('Scenarij:', style: Theme.of(context).textTheme.labelMedium),
                for (var i = 0; i < _scenarioOptions.length; i++) ...[
                  _scenarioOptions[i].enabled
                      ? FilterChip(
                          label: Text(_scenarioOptions[i].label),
                          selected: _scenarioIndex == i,
                          onSelected: _uiLocked
                              ? null
                              : (v) {
                                  if (v) setState(() => _scenarioIndex = i);
                                },
                        )
                      : Tooltip(
                          message: 'Kasnije: veza s izvršenjem u realnom vremenu',
                          child: InputChip(
                            label: Text(_scenarioOptions[i].label),
                            isEnabled: false,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: (_uiLocked || _loadingPool) ? null : _run,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Generiši nacrt'),
                ),
                OutlinedButton(
                  onPressed: (_uiLocked || _loadingPool) ? null : _run,
                  child: const Text('Preračunaj'),
                ),
                OutlinedButton(
                  onPressed: _uiLocked ? null : _showCompareSoon,
                  child: const Text('Usporedi'),
                ),
                FilledButton.tonal(
                  onPressed: _lastSavedPlanId == null || _saving
                      ? null
                      : _openDetailsForLastSave,
                  child: const Text('Otpusti (detalji)'),
                ),
                IconButton(
                  tooltip: 'Spremljeni planovi',
                  onPressed: _uiLocked
                      ? null
                      : () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ProductionPlansListScreen(
                                companyData: widget.companyData,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.view_list_outlined),
                ),
                IconButton(
                  tooltip: 'Osvježi pool',
                  onPressed: _uiLocked || _loadingPool ? null : _loadPool,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _horizonChips() {
    const presets = [1, 3, 7, 14, 30, 60];
    return [
      for (final d in presets)
        FilterChip(
          label: Text('$d'),
          showCheckmark: false,
          selected: _horizonDays == d,
          onSelected: _uiLocked
              ? null
              : (v) {
                  if (v) setState(() => _horizonDays = d);
                },
        ),
    ];
  }

  Widget _kpiIfAny() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();
    return PlanningKpiStrip(
      r: r,
      companyId: _cid,
      plantKey: _pk,
      compact: true,
    );
  }

  Widget _leftPoolAndParams() {
    return Card(
      margin: const EdgeInsets.all(4),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          const Text('Pool naloga', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_loadingPool)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_poolError != null)
            Text(_poolError!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (_pool.isEmpty)
            Text(
              'Nema naloga (pušten / u toku) za ovaj pogon.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Pretraga',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                TextButton(onPressed: _uiLocked ? null : _selectAll, child: const Text('Sve')),
                TextButton(
                  onPressed: _uiLocked || _searchQuery.trim().isEmpty
                      ? null
                      : _selectFiltered,
                  child: const Text('+ filtrirane'),
                ),
                TextButton(
                  onPressed: _uiLocked || _searchQuery.trim().isEmpty
                      ? null
                      : _clearFilteredFromSelection,
                  child: const Text('− filtrirane'),
                ),
                TextButton(onPressed: _uiLocked ? null : _clearSelection, child: const Text('Očisti')),
                Text(
                  '${_selected.length}/${_pool.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Najviše ${PlanningEngineService.maxOrdersPerRun} po pokretanju; redoslijed: rok, kreirano.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 200,
              child: _filtered.isEmpty
                  ? const Center(child: Text('Nema rezultata pretrage'))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final o = _filtered[i];
                        final hasMachine = (o.machineId ?? '').trim().isNotEmpty;
                        final rem = _remaining(o);
                        final checked = _selected.contains(o.id);
                        final risk = _poolRisk(o);
                        return ListTile(
                          dense: true,
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: checked,
                                onChanged: _uiLocked
                                    ? null
                                    : (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selected.add(o.id);
                                          } else {
                                            _selected.remove(o.id);
                                          }
                                        });
                                      },
                              ),
                              Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: risk,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            o.productionOrderCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${o.productName} · ${_formatQty(rem)} ${o.unit} · '
                            '${hasMachine ? "stroj" : "nema stroja"}',
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasMachine ? null : Theme.of(context).colorScheme.error,
                            ),
                          ),
                          selected: _selectedOrder?.id == o.id,
                          onTap: _uiLocked
                              ? null
                              : () => setState(() => _selectedOrder = o),
                        );
                      },
                    ),
            ),
          ],
          const Divider(height: 20),
          Text('Parametri plana', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _perfCtrl,
            decoration: const InputDecoration(
              labelText: 'Faktor performanse (0–1)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            readOnly: _uiLocked,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _setupCtrl,
            decoration: const InputDecoration(
              labelText: 'Setup (min)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            readOnly: _uiLocked,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _cycleCtrl,
            decoration: const InputDecoration(
              labelText: 'Ciklus (s/kom) kad nema routingsa',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            readOnly: _uiLocked,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Kako FCS trenutno planira', style: TextStyle(fontSize: 13)),
            children: [
              Text(
                'Ako postoji routing u Firestoreu, planiraju se operacije; inače jedna operacija. '
                'Trajanje: setup + (količina×standard) / performansa.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _centerGantt() {
    final d = _ganttDto;
    if (d == null || d.operations.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(4),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _result == null
                  ? 'Generirajte nacrt plana (gumb iznad) da se ovdje prikaže Gantt.'
                  : 'Nema operacija u horizontu (npr. svi odbačeni).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }
    if (_ganttLabelForResultId != _result?.plan.id) {
      return const Card(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Card(
      margin: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
      child: PlanningGanttChart(
        data: d,
        machineLabels: _ganttMachineLabels,
        showNowLine: true,
      ),
    );
  }

  Widget _rightDetails() {
    final r = _result;
    final o = _selectedOrder;
    return Card(
      margin: const EdgeInsets.all(4),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          const Text('Detalj', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (o == null)
            const Text('Odaberite nalog u poolu (lijevo).')
          else ...[
            Text('Nalog: ${o.productionOrderCode}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Proizvod: ${o.productName}'),
            Text('Status: ${_statusLabel(o.status)}'),
            Text('Preostalo: ${_formatQty(_remaining(o))} ${o.unit}'),
            if (o.requestedDeliveryDate != null)
              Text('Rok: ${o.requestedDeliveryDate!.toLocal()}'),
            const SizedBox(height: 8),
            Text(
              (o.machineId ?? '').isEmpty
                  ? 'Nema stroja — plan za ovaj nalog nije moguć dok se ne dodijeli resurs.'
                  : 'Stroj dodijeljen nalogu.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (r != null) ...[
            const Divider(height: 20),
            PlanningKpiStrip(
              r: r,
              companyId: _cid,
              plantKey: _pk,
              compact: false,
            ),
            const SizedBox(height: 8),
            if (r.conflicts.isNotEmpty) ...[
              Text('Upozorenja', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ...r.conflicts.take(5).map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${PlanningUiFormatters.conflictTypeLabel(c.type.name)}: ${c.message}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy || _saving ? null : _openGanttFullscreenFromMemory,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Gantt puni ekran'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy || _saving ? null : _saveDraft,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Spremi nacrt'),
                ),
                if (_lastSavedPlanId != null) ...[
                  OutlinedButton(
                    onPressed: _busy || _saving ? null : _openGanttFromFirestore,
                    child: const Text('Gantt iz baze'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _planWorkbench() {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= _kPlanWideBreakpoint;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 25, child: _leftPoolAndParams()),
              Expanded(flex: 55, child: _centerGantt()),
              Expanded(flex: 20, child: _rightDetails()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 40, child: _leftPoolAndParams()),
            const Divider(height: 1),
            Expanded(flex: 38, child: _centerGantt()),
            const Divider(height: 1),
            Expanded(flex: 35, child: _rightDetails()),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planiranje proizvodnje'),
      ),
      body: Column(
        children: [
          _commandBar(context),
          _kpiIfAny(),
          Expanded(
            child: TabBarView(
              controller: _workbenchTab,
              children: [
                _planWorkbench(),
                _staticBottomTab(
                  'Provedba',
                  'Plan vs stvarno, MES unosi, smjenska tabla. Povezivanje s nacrtom = sljedeći korak.',
                ),
                _staticBottomTab(
                  'Varijanca',
                  'Analiza odstupanja (vrijeme, količina, ciklus). Podaci s izvršenja.',
                ),
                _staticBottomTab(
                  'Kapaciteti',
                  'Kalendar TEEP / iskoristivost resursa u kontekstu plana.',
                ),
                _staticBottomTab(
                  'Bottlenecki',
                  'Identifikacija ograničenja; KPI bottleneck iz motora i dalje su u traci iznad / desno.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: TabBar(
          controller: _workbenchTab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Plan', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Provedba', icon: Icon(Icons.fact_check_outlined)),
            Tab(text: 'Varijanca', icon: Icon(Icons.compare_arrows)),
            Tab(text: 'Kapaciteti', icon: Icon(Icons.speed_outlined)),
            Tab(text: 'Bottlenecki', icon: Icon(Icons.network_ping_outlined)),
          ],
        ),
      ),
    );
  }

  Widget _staticBottomTab(String title, String body) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          body,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProductionPlansListScreen(companyData: widget.companyData),
              ),
            );
          },
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Spremljeni planovi'),
        ),
      ],
    );
  }
}
