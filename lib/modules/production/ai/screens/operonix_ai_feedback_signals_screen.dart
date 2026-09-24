import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/branding/operonix_ai_branding.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../models/operonix_ai_feedback_signals_snapshot.dart';
import '../services/firebase_callable_user_message.dart';
import '../services/production_ai_assistant_feedback_service.dart';

/// AI-M2-G4 — admin pregled agregiranih AI feedback signala (D4 list Callable).
class OperonixAiFeedbackSignalsScreen extends StatefulWidget {
  const OperonixAiFeedbackSignalsScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  /// Usklađeno s D4 [LIST_SIGNAL_ROLES]; PASS: admin / super_admin moraju vidjeti.
  static bool canView(Map<String, dynamic> companyData) {
    if (!ProductionModuleKeys.hasAiAssistantModule(companyData) &&
        !ProductionModuleKeys.hasAnyProductionAiHubAccess(companyData)) {
      return false;
    }
    final role = ProductionAccessHelper.normalizeRole(companyData['role']);
    return ProductionAccessHelper.isAdminRole(role) ||
        ProductionAccessHelper.isSuperAdminRole(role) ||
        role == ProductionAccessHelper.roleQualityControl ||
        role == ProductionAccessHelper.roleProductionManager;
  }

  @override
  State<OperonixAiFeedbackSignalsScreen> createState() =>
      _OperonixAiFeedbackSignalsScreenState();
}

class _OperonixAiFeedbackSignalsScreenState
    extends State<OperonixAiFeedbackSignalsScreen> {
  final _svc = ProductionAiAssistantFeedbackService();

  late DateTimeRange _range;
  bool _loading = true;
  String? _error;
  OperonixAiFeedbackSignalsSnapshot? _snap;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String? get _plantKey {
    final v = (widget.companyData['plantKey'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(const Duration(days: 30));
    _range = DateTimeRange(start: from, end: to);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
      helpText: 'Odaberite period',
      cancelText: 'Odustani',
      confirmText: 'Primijeni',
      saveText: 'Primijeni',
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    await _load();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje kontekst tvrtke.';
        _snap = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final role = ProductionAccessHelper.normalizeRole(
        widget.companyData['role'],
      );
      final plantScoped = !(ProductionAccessHelper.isAdminRole(role) ||
          ProductionAccessHelper.isSuperAdminRole(role) ||
          ProductionAccessHelper.isCompanyWideContextRole(role));

      final snap = await _svc.listSignals(
        companyId: _companyId,
        dateFrom: _fmt(_range.start),
        dateTo: _fmt(_range.end),
        plantKey: plantScoped ? _plantKey : null,
      );
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = firebaseCallableUserMessage(e);
        _snap = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Pregled signala nije uspio. Pokušajte ponovo.';
        _snap = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = _snap;

    return Scaffold(
      appBar: AppBar(
        title: const Text(kOperonixAiFeedbackSignalsScreenTitle),
        actions: [
          IconButton(
            tooltip: 'Odabir perioda',
            onPressed: _loading ? null : _pickRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                )
              : snap == null
                  ? const Center(child: Text('Nema podataka.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          snap.companyDisplayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${snap.plantDisplayName}'
                          '${snap.periodFrom != null && snap.periodTo != null ? ' · ${snap.periodFrom} – ${snap.periodTo}' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          snap.note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TotalsCard(snap: snap),
                        const SizedBox(height: 12),
                        _CountSection(
                          title: 'Najčešći razlozi',
                          rows: snap.topReasons,
                          emptyText: 'Nema zabilježenih razloga u periodu.',
                        ),
                        const SizedBox(height: 12),
                        _CountSection(
                          title: 'Po površini asistenta',
                          rows: snap.bySurface,
                          emptyText: 'Nema signala po površini.',
                        ),
                        const SizedBox(height: 12),
                        _CountSection(
                          title: 'Po tipu AI konteksta',
                          rows: snap.byContract,
                          emptyText: 'Nema signala po tipu konteksta.',
                        ),
                        const SizedBox(height: 12),
                        _CountSection(
                          title: 'Po modulu',
                          rows: snap.byModule,
                          emptyText: 'Nema signala po modulu.',
                        ),
                      ],
                    ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.snap});

  final OperonixAiFeedbackSignalsSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sažetak ocjena',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(
                  label: 'Ukupno',
                  value: '${snap.total}',
                ),
                _StatChip(
                  label: snap.helpfulLabel,
                  value: '${snap.helpful}',
                  tone: theme.colorScheme.primaryContainer,
                  onTone: theme.colorScheme.onPrimaryContainer,
                ),
                _StatChip(
                  label: snap.notHelpfulLabel,
                  value: '${snap.notHelpful}',
                  tone: theme.colorScheme.tertiaryContainer,
                  onTone: theme.colorScheme.onTertiaryContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.tone,
    this.onTone,
  });

  final String label;
  final String value;
  final Color? tone;
  final Color? onTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = tone ?? theme.colorScheme.surfaceContainerHighest;
    final fg = onTone ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: fg),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountSection extends StatelessWidget {
  const _CountSection({
    required this.title,
    required this.rows,
    required this.emptyText,
  });

  final String title;
  final List<OperonixAiFeedbackSignalCountRow> rows;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...rows.map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.label),
                  trailing: Text(
                    '${r.count}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
