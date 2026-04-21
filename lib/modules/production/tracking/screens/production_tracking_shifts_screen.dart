import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../models/production_shift_day_summary.dart';
import '../services/production_tracking_hub_callable_service.dart';
import '../services/production_tracking_hub_firestore_service.dart';
import '../services/tracking_effective_plant_key.dart';
import 'production_operator_tracking_day_report_screen.dart';

/// Smjene i raspoloživost radne snage za odabrani dan (Firestore + Callable).
class ProductionTrackingShiftsScreen extends StatefulWidget {
  const ProductionTrackingShiftsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductionTrackingShiftsScreen> createState() =>
      _ProductionTrackingShiftsScreenState();
}

class _ProductionTrackingShiftsScreenState
    extends State<ProductionTrackingShiftsScreen> {
  final _hub = ProductionTrackingHubFirestoreService();
  final _hubCall = ProductionTrackingHubCallableService();

  late DateTime _day;
  String? _plantKey;
  bool _plantLoading = true;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString();

  bool get _canManageHubData {
    final r = ProductionAccessHelper.normalizeRole(_role);
    return ProductionAccessHelper.isAdminRole(_role) ||
        ProductionAccessHelper.isSuperAdminRole(_role) ||
        r == ProductionAccessHelper.roleProductionManager ||
        r == ProductionAccessHelper.roleSupervisor;
  }

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    _loadPlant();
  }

  Future<void> _loadPlant() async {
    setState(() => _plantLoading = true);
    final pk = await resolveEffectiveTrackingPlantKey(widget.companyData);
    if (!mounted) return;
    final t = pk?.trim() ?? '';
    setState(() {
      _plantKey = t.isEmpty ? null : t;
      _plantLoading = false;
    });
  }

  String _workDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDay() async {
    final first = DateTime.now().subtract(const Duration(days: 120));
    final last = DateTime.now().add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(
        () => _day = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _openEditDialog(ProductionShiftDaySummary? current) async {
    final pk = _plantKey;
    if (pk == null || !_canManageHubData) return;

    final wd = _workDateKey(_day);
    final plannedCtrl = TextEditingController(
      text: current?.plannedHeadcount.toString() ?? '0',
    );
    final presentCtrl = TextEditingController(
      text: current?.presentCount.toString() ?? '0',
    );
    final absentCtrl = TextEditingController(
      text: current?.absentCount.toString() ?? '0',
    );
    final notesCtrl = TextEditingController(text: current?.notes ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Dnevni sažetak smjena'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: plannedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Planirana radna snaga (os.)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: presentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prisutni (os.)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: absentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Odsutni (os.)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Napomena (opcionalno)',
                  ),
                  maxLines: 3,
                  maxLength: 2000,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Spremi'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) {
      plannedCtrl.dispose();
      presentCtrl.dispose();
      absentCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final planned = int.tryParse(plannedCtrl.text.trim()) ?? 0;
    final present = int.tryParse(presentCtrl.text.trim()) ?? 0;
    final absent = int.tryParse(absentCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim();

    plannedCtrl.dispose();
    presentCtrl.dispose();
    absentCtrl.dispose();
    notesCtrl.dispose();

    if (planned < 0 || present < 0 || absent < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brojevi moraju biti nenegativni.')),
      );
      return;
    }

    try {
      await _hubCall.upsertProductionShiftDaySummary(
        companyId: _companyId,
        plantKey: pk,
        workDate: wd,
        plannedHeadcount: planned,
        presentCount: present,
        absentCount: absent,
        absentByReason: current?.absentByReason,
        notes: notes.isEmpty ? null : notes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  String _formatDay(BuildContext context) {
    return MaterialLocalizations.of(context).formatFullDate(_day);
  }

  String _formatDateTime(BuildContext context, DateTime d) {
    final date = MaterialLocalizations.of(context).formatFullDate(d);
    final t = TimeOfDay.fromDateTime(d);
    final time = t.format(context);
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smjene'),
        actions: [
          IconButton(
            tooltip: 'Odaberi dan',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
        ],
      ),
      floatingActionButton: _canManageHubData &&
              _plantKey != null &&
              !_plantLoading
          ? FloatingActionButton.extended(
              onPressed: () => _openEditDialog(null),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Uredi'),
            )
          : null,
      body: _plantLoading
          ? const Center(child: CircularProgressIndicator())
          : _plantKey == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nije odabran pogon (plantKey). Postavi pogon u postavkama ili odaberi stanicu.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _formatDay(context),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pogon: $_plantKey',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Brojke su ručni unos ili kasnije automatski iz HR / evidencije. '
                      'Detalji razloga odsutnosti mogu se proširiti u sljedećim verzijama.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<ProductionShiftDaySummary?>(
                      key: ValueKey(
                        '${_workDateKey(_day)}_$_plantKey',
                      ),
                      stream: _hub.watchShiftDaySummary(
                        companyId: _companyId,
                        plantKey: _plantKey!,
                        workDate: _workDateKey(_day),
                      ),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text(
                            AppErrorMapper.toMessage(snap.error!),
                            style: TextStyle(color: cs.error),
                          );
                        }
                        final s = snap.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Planirana radna snaga',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      s == null
                                          ? '—'
                                          : '${s.plannedHeadcount} os.',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                    color: cs.primary,
                                  ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prisutnost i odsutnosti',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      s == null
                                          ? 'Nema unosa za ovaj dan.'
                                          : 'Prisutni: ${s.presentCount} · Odsutni: ${s.absentCount}',
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                    ),
                                    if (s != null &&
                                        s.absentByReason.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: s.absentByReason.entries
                                            .map(
                                              (e) => Chip(
                                                label: Text(
                                                  '${e.key}: ${e.value}',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                    if (s != null &&
                                        (s.notes ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        s.notes!,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                    if (s?.updatedAt != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Zadnja izmjena: ${_formatDateTime(context, s!.updatedAt!)}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: cs.outline,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (_canManageHubData && s != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _openEditDialog(s),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Uredi'),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Operativni podaci iz praćenja',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf_outlined),
                        title: const Text('Dnevni operativni izvještaj (PDF)'),
                        subtitle: const Text(
                          'Unosi po fazama za odabrani dan — iz modula praćenja proizvodnje.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProductionOperatorTrackingDayReportScreen(
                                companyData: widget.companyData,
                              ),
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
