import 'package:flutter/material.dart';

import '../models/planning_scenario_record.dart';
import '../planning_session_controller.dart';
import '../planning_viewport.dart';
import '../services/planning_scenario_service.dart';
import '../widgets/planning_help_icon.dart';

/// F4.1 — scenariji (baseline / what-if), vez na opcionalno spremljeni plan.
class PlanningScenariosTab extends StatefulWidget {
  const PlanningScenariosTab({
    super.key,
    required this.companyData,
    required this.session,
    this.scenarioLoader,
  });

  final Map<String, dynamic> companyData;
  final PlanningSessionController session;

  /// When set, the tab does not call the scenario Callable.
  /// Production leaves this null.
  final Future<List<PlanningScenarioRecord>> Function()? scenarioLoader;

  @override
  State<PlanningScenariosTab> createState() => _PlanningScenariosTabState();
}

class _PlanningScenariosTabState extends State<PlanningScenariosTab> {
  late final PlanningScenarioService _svc = PlanningScenarioService();
  final _title = TextEditingController();
  final _basePlan = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'baseline';
  String? _editingId;
  List<PlanningScenarioRecord> _rows = [];
  String? _err;
  bool _loading = true;
  bool _saving = false;

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk => (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _basePlan.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_cid.isEmpty || _pk.isEmpty) {
      setState(() {
        _loading = false;
        _err = 'Nema companyId / plantKey.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final loader = widget.scenarioLoader;
      final list = loader != null
          ? await loader()
          : await _svc.listScenarios(companyId: _cid, plantKey: _pk);
      if (mounted) {
        setState(() {
          _rows = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _err = e.toString();
        });
      }
    }
  }

  void _useLastPlanId() {
    final id = widget.session.lastSavedPlanId;
    if (id != null && id.isNotEmpty) {
      _basePlan.text = id;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nema spremljenog plana u ovoj sesiji. Spremite nacrt ili unesite ID ručno.',
          ),
        ),
      );
    }
  }

  void _startEdit(PlanningScenarioRecord r) {
    setState(() {
      _editingId = r.id;
      _title.text = r.title;
      _type = r.scenarioType;
      _basePlan.text = r.basePlanId;
      _notes.text = r.notes ?? '';
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _title.clear();
      _type = 'baseline';
      _basePlan.clear();
      _notes.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesite naslov scenarija.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.upsertScenario(
        companyId: _cid,
        plantKey: _pk,
        scenarioId: _editingId,
        title: _title.text.trim(),
        scenarioType: _type,
        basePlanId: _basePlan.text.trim(),
        notes: _notes.text.trim(),
      );
      if (mounted) {
        _clearForm();
        await _load();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Scenarij spremljen.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Greška: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(PlanningScenarioRecord r) async {
    final ok = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati scenarij?'),
        content: Text(
          '„${r.title}” — ovo ne briše nacrt proizvodnog plana, samo zapis scenarija.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _svc.deleteScenario(
        companyId: _cid,
        plantKey: _pk,
        scenarioId: r.id,
      );
      if (mounted) {
        if (_editingId == r.id) {
          _clearForm();
        }
        await _load();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Obrisano.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Brisanje: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty || _pk.isEmpty) {
      return const Center(
        child: Text('Kontekst kompanija/pogon nije učitavan.'),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_err!, textAlign: TextAlign.center),
        ),
      );
    }
    return PlanningScenariosLayout(
      rows: _rows,
      locked: widget.session.isLocked,
      onRefresh: widget.session.isLocked ? null : _load,
      onEdit: _startEdit,
      onDelete: _delete,
      form: PlanningScenarioForm(
        editing: _editingId != null,
        locked: widget.session.isLocked,
        saving: _saving,
        title: _title,
        basePlan: _basePlan,
        notes: _notes,
        type: _type,
        onType: widget.session.isLocked
            ? null
            : (v) => setState(() => _type = v),
        onUseLastPlan: widget.session.isLocked ? null : _useLastPlanId,
        onSave: widget.session.isLocked || _saving ? null : _save,
        onClear: widget.session.isLocked ? null : _clearForm,
      ),
    );
  }
}

/// Scenariji: jedna kolona na telefonu, dva okna tek kad oba imaju širinu.
class PlanningScenariosLayout extends StatelessWidget {
  static const twoColumnMinWidth = PlanningViewport.multiColumnMinWidth;
  static const introText =
      'Baseline / what-if, opcionalno vezan nacrt plana. Pisanje: Callable u pozadini.';

  final List<PlanningScenarioRecord> rows;
  final bool locked;
  final VoidCallback? onRefresh;
  final ValueChanged<PlanningScenarioRecord> onEdit;
  final ValueChanged<PlanningScenarioRecord> onDelete;
  final Widget form;

  const PlanningScenariosLayout({
    super.key,
    required this.rows,
    required this.locked,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final intro = _intro(context);
        final cards = [for (final r in rows) _card(r)];
        final width = PlanningViewport.decisionWidth(context, constraints);
        final multi = width >= twoColumnMinWidth;
        final bottom = MediaQuery.viewPaddingOf(context).bottom;
        final column = ListView(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 16 + bottom),
          children: [intro, ...cards, const SizedBox(height: 8), form],
        );
        final body = multi
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [intro, ...cards],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(child: form),
                  ),
                ],
              )
            : column;
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: body),
        );
      },
    );
  }

  Widget _intro(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Scenariji planiranja (F4)',
                  style: t.textTheme.titleMedium,
                ),
              ),
              PlanningHelpIcon(
                title: PlanningHelpTexts.scenariosTabTitle,
                message: PlanningHelpTexts.scenariosTabMessage,
                size: 18,
              ),
              IconButton(
                tooltip: 'Osvježi',
                icon: const Icon(Icons.refresh),
                onPressed: onRefresh,
              ),
            ],
          ),
          Text(introText, style: t.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _card(PlanningScenarioRecord r) {
    return Card(
      child: ListTile(
        title: Text(r.title),
        subtitle: Text(
          'Tip: ${r.scenarioType} · baza: ${r.basePlanId.isEmpty ? "—" : r.basePlanId}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: (r.notes ?? '').isNotEmpty,
        trailing: locked
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEdit(r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(r),
                  ),
                ],
              ),
        onTap: () => onEdit(r),
      ),
    );
  }
}

class PlanningScenarioForm extends StatelessWidget {
  final bool editing;
  final bool locked;
  final bool saving;
  final TextEditingController title;
  final TextEditingController basePlan;
  final TextEditingController notes;
  final String type;
  final ValueChanged<String>? onType;
  final VoidCallback? onUseLastPlan;
  final VoidCallback? onSave;
  final VoidCallback? onClear;

  const PlanningScenarioForm({
    super.key,
    required this.editing,
    required this.locked,
    required this.saving,
    required this.title,
    required this.basePlan,
    required this.notes,
    required this.type,
    required this.onType,
    required this.onUseLastPlan,
    required this.onSave,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              editing ? 'Uređivanje' : 'Novi scenarij',
              style: t.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: title,
              enabled: !locked,
              decoration: const InputDecoration(labelText: 'Naslov'),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vrsta',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: type,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'baseline',
                      child: Text('Baseline'),
                    ),
                    DropdownMenuItem(value: 'whatif', child: Text('What-if')),
                  ],
                  onChanged: onType == null
                      ? null
                      : (v) {
                          if (v != null) onType!(v);
                        },
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: basePlan,
              enabled: !locked,
              decoration: const InputDecoration(
                labelText: 'ID baze (nacrt u production_plans, opcij.)',
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: onUseLastPlan,
                child: const Text(
                  'Ubaci zadnje spremljeni plan iz sesije',
                  textAlign: TextAlign.start,
                ),
              ),
            ),
            TextField(
              controller: notes,
              enabled: !locked,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Napomena'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onSave,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Spremljeni zapis'),
                ),
                OutlinedButton(
                  onPressed: onClear,
                  child: const Text('Očisti formu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
