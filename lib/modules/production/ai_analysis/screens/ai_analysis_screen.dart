import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../ai_analysis_payloads.dart';
import '../models/ai_analysis_domain.dart';
import '../services/ai_analysis_service.dart';
import '../services/ai_analysis_snapshot_service.dart';

/// Strukturirana AI analiza (Callable [runAiAnalysis]) — odvojeno od slobodnog chata.
///
/// Payload može biti demo ili učitavanje iz Firestorea (praćenje / nalozi) za odabrani period.
class AiAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const AiAnalysisScreen({super.key, required this.companyData});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  /// Usklađeno s AI izvještajem: učitavanje iz baze ograničeno radi performansi i veličine payloada.
  static const int _maxInclusivePeriodDays = 31;

  final _svc = AiAnalysisService();
  final _snapshotSvc = AiAnalysisSnapshotService();
  final _focusCtrl = TextEditingController();

  AiAnalysisDomain _domain = AiAnalysisDomain.oee;
  Map<String, dynamic>? _payload;
  bool _loading = false;
  bool _snapshotLoading = false;
  late DateTime _start;
  late DateTime _end;
  String? _markdown;
  String? _error;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _busy => _loading || _snapshotLoading;

  /// Broj kalendarskih dana od [Od] do [Do], uključivo oba kraja.
  int _inclusiveCalendarDays() {
    final a = DateTime(_start.year, _start.month, _start.day);
    final b = DateTime(_end.year, _end.month, _end.day);
    return b.difference(a).inDays + 1;
  }

  bool get _periodOrderOk => !_start.isAfter(_end);

  bool get _periodExceedsFirestoreLimit =>
      _periodOrderOk && _inclusiveCalendarDays() > _maxInclusivePeriodDays;

  static const String _periodTooLongMessage =
      'Za učitavanje iz baze period ne smije biti dulji od 31 dan (uključivo). Skrati raspon datuma.';

  bool _rejectIfPeriodTooLongForFirestore() {
    if (!_periodOrderOk) {
      setState(() => _error = 'Početni datum mora biti prije krajnjeg.');
      return true;
    }
    if (_periodExceedsFirestoreLimit) {
      setState(() => _error = _periodTooLongMessage);
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _end = DateTime(now.year, now.month, now.day);
    _start = _end.subtract(const Duration(days: 6));
  }

  @override
  void dispose() {
    _focusCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(_end.year - 1),
      lastDate: _end,
    );
    if (d != null) {
      setState(() {
        _start = DateTime(d.year, d.month, d.day);
        _clearStalePeriodError();
      });
    }
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _end = DateTime(d.year, d.month, d.day);
        _clearStalePeriodError();
      });
    }
  }

  void _clearStalePeriodError() {
    if (!_periodOrderOk) return;
    if (_periodExceedsFirestoreLimit) return;
    if (_error == _periodTooLongMessage ||
        _error == 'Početni datum mora biti prije krajnjeg.') {
      _error = null;
    }
  }

  Future<void> _loadOeeFromTracking() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() => _error = 'Nedostaje podatak o kompaniji ili pogonu. Obrati se administratoru.');
      return;
    }
    if (_rejectIfPeriodTooLongForFirestore()) return;
    setState(() {
      _snapshotLoading = true;
      _error = null;
      _markdown = null;
    });
    try {
      final payload = await _snapshotSvc.buildOeeStyleFromTracking(
        companyId: _companyId,
        plantKey: _plantKey,
        start: _start,
        end: _end,
      );
      if (!mounted) return;
      setState(() {
        _domain = AiAnalysisDomain.oee;
        _payload = payload;
        _snapshotLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _snapshotLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadScadaFromTracking() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() => _error = 'Nedostaje podatak o kompaniji ili pogonu. Obrati se administratoru.');
      return;
    }
    if (_rejectIfPeriodTooLongForFirestore()) return;
    setState(() {
      _snapshotLoading = true;
      _error = null;
      _markdown = null;
    });
    try {
      final payload = await _snapshotSvc.buildScadaStyleFromTracking(
        companyId: _companyId,
        plantKey: _plantKey,
        start: _start,
        end: _end,
      );
      if (!mounted) return;
      setState(() {
        _domain = AiAnalysisDomain.scada;
        _payload = payload;
        _snapshotLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _snapshotLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadFlowFromOrders() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() => _error = 'Nedostaje podatak o kompaniji ili pogonu. Obrati se administratoru.');
      return;
    }
    if (_rejectIfPeriodTooLongForFirestore()) return;
    setState(() {
      _snapshotLoading = true;
      _error = null;
      _markdown = null;
    });
    try {
      final payload = await _snapshotSvc.buildProductionFlowFromOrders(
        companyId: _companyId,
        plantKey: _plantKey,
        start: _start,
        end: _end,
      );
      if (!mounted) return;
      setState(() {
        _domain = AiAnalysisDomain.productionFlow;
        _payload = payload;
        _snapshotLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _snapshotLoading = false;
        _error = e.toString();
      });
    }
  }

  void _applyDemoPayload() {
    setState(() {
      _payload = _demoPayloadForDomain(_domain);
      _error = null;
      _markdown = null;
    });
  }

  Map<String, dynamic> _demoPayloadForDomain(AiAnalysisDomain d) {
    final now = DateTime.now().toUtc().toIso8601String();
    switch (d) {
      case AiAnalysisDomain.scada:
        return AiAnalysisPayloads.scadaSnapshot(
          source: 'production_app_demo',
          capturedAt: DateTime.now(),
          windowLabel: 'zadnji sat',
          deviceStates: <String, dynamic>{
            'line_A': 'running',
            'line_B': 'idle',
          },
          telemetryPoints: <Map<String, dynamic>>[
            {'tag': 'temp_zone_1', 'value': 64.2, 'unit': 'C'},
            {'tag': 'pressure_main', 'value': 6.1, 'unit': 'bar'},
          ],
          alarms: <String, dynamic>{
            'active': 1,
            'last': 'Low pressure warning — buffer tank',
          },
        );
      case AiAnalysisDomain.oee:
        return AiAnalysisPayloads.oeeBlock(
          periodLabel: 'smjena (demo)',
          availabilityPct: 88,
          performancePct: 79,
          qualityPct: 96,
          oeePct: 66.8,
          losses: <String, dynamic>{
            'scrap_qty': 42,
            'rework_min': 15,
          },
          downtimeSummary: <String, dynamic>{
            'planned_min': 20,
            'unplanned_min': 35,
          },
        );
      case AiAnalysisDomain.productionFlow:
        return AiAnalysisPayloads.productionFlow(
          label: 'demo_nalozi',
          orders: <Map<String, dynamic>>[
            {
              'code': 'PN-2401',
              'status': 'in_progress',
              'good': 1200,
              'scrap': 18,
            },
          ],
          phases: <Map<String, dynamic>>[
            {'name': 'pripreme', 'complete': true},
            {'name': 'kontrola', 'complete': false},
          ],
          totals: <String, dynamic>{'planned': 5000, 'good': 3200},
        );
      case AiAnalysisDomain.generic:
        return AiAnalysisPayloads.generic(<String, dynamic>{
          'generatedAt': now,
          'note': 'Generički demo — zamijeni stvarnim podacima iz servisa.',
        });
    }
  }

  Future<void> _run() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() => _error = 'Nedostaje podatak o kompaniji ili pogonu. Obrati se administratoru.');
      return;
    }
    if (_payload == null) {
      setState(() => _error = 'Učitaj demo podatke ili pripremi payload iz aplikacije.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _markdown = null;
    });

    try {
      final r = await _svc.run(
        companyId: _companyId,
        plantKey: _plantKey,
        domain: _domain,
        payload: _payload!,
        analysisFocus: _focusCtrl.text.trim().isEmpty
            ? null
            : _focusCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _markdown = r.analysisMarkdown;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!ProductionModuleKeys.hasAiProductionAnalyticsModule(widget.companyData)) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI analiza')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Strukturirana AI analiza zahtijeva modul ai_assistant_production '
              'ili legacy ai_assistant (enabledModules).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI analiza (strukturirani podaci)')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ovo nije chat. Šalje se JSON (SCADA / OEE / tok) na Callable '
                    'runAiAnalysis. Za učitavanje iz baze odaberi period (najviše '
                    '$_maxInclusivePeriodDays dan) ili koristi demo podatke.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickStart,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            'Od: ${_start.year}-${_start.month.toString().padLeft(2, '0')}-${_start.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickEnd,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            'Do: ${_end.year}-${_end.month.toString().padLeft(2, '0')}-${_end.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_periodOrderOk) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Početni datum mora biti prije krajnjeg.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ] else if (_periodExceedsFirestoreLimit) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Period: ${_inclusiveCalendarDays()} dana — za učitavanje iz '
                      'Firestorea najviše $_maxInclusivePeriodDays dan (uključivo).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Domena',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AiAnalysisDomain>(
                        value: _domain,
                        isExpanded: true,
                        items: AiAnalysisDomain.values
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(_domainLabel(d)),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() {
                                  _domain = v;
                                  _payload = null;
                                  _markdown = null;
                                });
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _focusCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Prioritet analize (opcionalno)',
                      hintText: 'npr. Naglasi zastoje',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Podaci iz aplikacije',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: (_busy ||
                                !_periodOrderOk ||
                                _periodExceedsFirestoreLimit)
                            ? null
                            : _loadOeeFromTracking,
                        icon: const Icon(Icons.speed, size: 18),
                        label: const Text('OEE iz praćenja'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: (_busy ||
                                !_periodOrderOk ||
                                _periodExceedsFirestoreLimit)
                            ? null
                            : _loadScadaFromTracking,
                        icon: const Icon(Icons.dashboard_customize, size: 18),
                        label: const Text('Operativni snimak (faze)'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: (_busy ||
                                !_periodOrderOk ||
                                _periodExceedsFirestoreLimit)
                            ? null
                            : _loadFlowFromOrders,
                        icon: const Icon(Icons.account_tree_outlined, size: 18),
                        label: const Text('Tok iz naloga'),
                      ),
                    ],
                  ),
                  if (_snapshotLoading) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Učitavanje iz Firestorea…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _applyDemoPayload,
                        icon: const Icon(Icons.data_object, size: 18),
                        label: const Text('Učitaj demo podatke'),
                      ),
                      const SizedBox(width: 8),
                      if (_payload != null)
                        Expanded(
                          child: Text(
                            'Payload: ${_payload!.length} ključeva',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _run,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(_loading ? 'Analiza…' : 'Pokreni analizu'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 3,
            child: _markdown == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _snapshotLoading
                            ? 'Učitavanje podataka…'
                            : _loading
                                ? ''
                                : 'Odaberi period, učitaj podatke ili demo, zatim pokreni analizu.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: _markdown!,
                      selectable: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Usklađeno s backend [canUseProductionAssistant] (uklj. operater).
bool aiStructuredAnalysisVisibleForRole(dynamic roleRaw) {
  final r = ProductionAccessHelper.normalizeRole(roleRaw);
  return r == 'admin' ||
      r == 'super_admin' ||
      r == 'production_manager' ||
      r == 'supervisor' ||
      r == 'production_operator';
}

String _domainLabel(AiAnalysisDomain d) {
  switch (d) {
    case AiAnalysisDomain.scada:
      return 'SCADA / telemetrija';
    case AiAnalysisDomain.oee:
      return 'OEE / KPI';
    case AiAnalysisDomain.productionFlow:
      return 'Tok proizvodnje';
    case AiAnalysisDomain.generic:
      return 'Generički';
  }
}
