import 'package:flutter/material.dart';

import '../models/planning_scenario_record.dart';
import '../planning_session_controller.dart';
import '../services/planning_scenario_service.dart';

/// F4.1 — scenariji (baseline / what-if), vez na opcionalno spremljeni plan.
class PlanningScenariosTab extends StatefulWidget {
  const PlanningScenariosTab({
    super.key,
    required this.companyData,
    required this.session,
  });

  final Map<String, dynamic> companyData;
  final PlanningSessionController session;

  @override
  State<PlanningScenariosTab> createState() => _PlanningScenariosTabState();
}

class _PlanningScenariosTabState extends State<PlanningScenariosTab> {
  final _svc = PlanningScenarioService();
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
      final list = await _svc.listScenarios(companyId: _cid, plantKey: _pk);
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
          content: Text('Nema spremljenog plana u ovoj sesiji. Spremite nacrt ili unesite ID ručno.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scenarij spremljen.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(PlanningScenarioRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati scenarij?'),
        content: Text('„${r.title}” — ovo ne briše nacrt proizvodnog plana, samo zapis scenarija.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Obriši')),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _svc.deleteScenario(companyId: _cid, plantKey: _pk, scenarioId: r.id);
      if (mounted) {
        if (_editingId == r.id) {
          _clearForm();
        }
        await _load();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrisano.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Brisanje: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_cid.isEmpty || _pk.isEmpty) {
      return const Center(child: Text('Kontekst kompanija/pogon nije učitavan.'));
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              ListTile(
                title: const Text('Scenariji planiranja (F4)'),
                subtitle: const Text('Baseline / what-if, opcionalno vezan nacrt plana. Pisanje: Callable u pozadini.'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: widget.session.isLocked ? null : _load,
                ),
              ),
              for (final r in _rows)
                Card(
                  child: ListTile(
                    title: Text(r.title),
                    subtitle: Text(
                      'Tip: ${r.scenarioType} · baza: ${r.basePlanId.isEmpty ? "—" : r.basePlanId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: (r.notes ?? '').isNotEmpty,
                    trailing: widget.session.isLocked
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _startEdit(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(r),
                              ),
                            ],
                          ),
                    onTap: () => _startEdit(r),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  _editingId == null ? 'Novi scenarij' : 'Uređivanje',
                  style: t.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _title,
                  enabled: !widget.session.isLocked,
                  decoration: const InputDecoration(
                    labelText: 'Naslov',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Vrsta',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _type,
                      isExpanded: true,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'baseline', child: Text('Baseline')),
                        DropdownMenuItem(value: 'whatif', child: Text('What-if')),
                      ],
                      onChanged: widget.session.isLocked
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _type = v);
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _basePlan,
                  enabled: !widget.session.isLocked,
                  decoration: const InputDecoration(
                    labelText: 'ID baze (nacrt u production_plans, opcij.)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.session.isLocked ? null : _useLastPlanId,
                    child: const Text('Ubaci zadnje spremljeni plan iz sesije'),
                  ),
                ),
                TextField(
                  controller: _notes,
                  enabled: !widget.session.isLocked,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Napomena',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: widget.session.isLocked || _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Spremljeni zapis'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: widget.session.isLocked ? null : _clearForm,
                      child: const Text('Očisti formu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
