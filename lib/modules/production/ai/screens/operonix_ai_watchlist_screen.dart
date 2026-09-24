import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/branding/operonix_ai_branding.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../services/firebase_callable_user_message.dart';
import '../services/operonix_ai_alerts_service.dart';
import '../services/operonix_ai_watchlist_service.dart';

/// AI-M3-E4 / F4 — UI nad E2 snapshotom + E3 explain + F2/F3 AI upozorenja.
class OperonixAiWatchlistScreen extends StatefulWidget {
  const OperonixAiWatchlistScreen({
    super.key,
    required this.companyData,
    this.highlightAlertKey,
  });

  final Map<String, dynamic> companyData;

  /// Opaque round-trip from mes_inbox (F3) — not shown in UI.
  final String? highlightAlertKey;

  static bool canView(Map<String, dynamic> companyData) {
    if (!ProductionModuleKeys.hasAiAssistantModule(companyData) &&
        !ProductionModuleKeys.hasAnyProductionAiHubAccess(companyData)) {
      return false;
    }
    final role = ProductionAccessHelper.normalizeRole(companyData['role']);
    // Usklađeno s backend AI context ulogama (read watchlist).
    return ProductionAccessHelper.isAdminRole(role) ||
        ProductionAccessHelper.isSuperAdminRole(role) ||
        ProductionAccessHelper.isCompanyWideContextRole(role) ||
        role == ProductionAccessHelper.roleProductionManager ||
        role == ProductionAccessHelper.roleProductionOperator ||
        role == ProductionAccessHelper.roleQualityOperator ||
        role == ProductionAccessHelper.roleShiftLead;
  }

  static bool canRefresh(Map<String, dynamic> companyData) {
    final role = ProductionAccessHelper.normalizeRole(companyData['role']);
    return ProductionAccessHelper.isAdminRole(role) ||
        ProductionAccessHelper.isSuperAdminRole(role) ||
        role == ProductionAccessHelper.roleQualityControl ||
        role == ProductionAccessHelper.roleProductionManager;
  }

  /// F1/F2/F3 — lifecycle AI upozorenja (ne NCR inbox).
  static bool canManageAlerts(Map<String, dynamic> companyData) {
    final role = ProductionAccessHelper.normalizeRole(companyData['role']);
    return ProductionAccessHelper.isAdminRole(role) ||
        ProductionAccessHelper.isSuperAdminRole(role) ||
        role == ProductionAccessHelper.roleQualityControl ||
        role == ProductionAccessHelper.roleProductionManager;
  }

  @override
  State<OperonixAiWatchlistScreen> createState() =>
      _OperonixAiWatchlistScreenState();
}

class _OperonixAiWatchlistScreenState extends State<OperonixAiWatchlistScreen> {
  final _svc = OperonixAiWatchlistService();
  final _alertsSvc = OperonixAiAlertsService();
  final _alertsSectionKey = GlobalKey();

  bool _loading = true;
  bool _refreshing = false;
  bool _explaining = false;
  bool _alertsLoading = false;
  String? _busyAlertKey;
  String? _error;
  OperonixAiWatchlistSnapshot? _snap;
  String? _explanation;
  List<OperonixAiAlertItem> _alerts = const [];
  String? _alertsError;

  String? _selectedPlantKey;
  String? _selectedPlantLabel;
  List<({String plantKey, String label})> _plantChoices = [];
  bool _plantsLoading = false;

  late DateTimeRange _range;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String? get _sessionPlantKey {
    final v = (widget.companyData['plantKey'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  String? get _sessionPlantLabel {
    final v = (widget.companyData['plantDisplayName'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  bool get _canRefresh =>
      OperonixAiWatchlistScreen.canRefresh(widget.companyData);

  bool get _canManageAlerts =>
      OperonixAiWatchlistScreen.canManageAlerts(widget.companyData);

  String? get _highlightKey {
    final k = (widget.highlightAlertKey ?? '').trim();
    return k.isEmpty ? null : k;
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get _periodLabel {
    final a = _fmt(_range.start);
    final b = _fmt(_range.end);
    return '${a.replaceAll('-', '.')} – ${b.replaceAll('-', '.')}';
  }

  DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(const Duration(days: 29));
    return DateTimeRange(start: from, end: to);
  }

  @override
  void initState() {
    super.initState();
    _range = _defaultRange();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final sessionPk = _sessionPlantKey;
    if (sessionPk != null) {
      _selectedPlantKey = sessionPk;
      _selectedPlantLabel = _sessionPlantLabel;
      _selectedPlantLabel ??= await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: sessionPk,
      );
      await _load();
      return;
    }

    setState(() {
      _plantsLoading = true;
      _loading = false;
    });
    final plants = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _companyId,
    );
    if (!mounted) return;
    setState(() {
      _plantChoices = plants;
      _plantsLoading = false;
      if (plants.length == 1) {
        _selectedPlantKey = plants.first.plantKey;
        _selectedPlantLabel = plants.first.label;
      }
    });
    if (_selectedPlantKey != null) {
      await _load();
    }
  }

  Future<void> _load() async {
    final pk = _selectedPlantKey?.trim();
    if (pk == null || pk.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Odaberi pogon za prikaz liste praćenja.';
        _snap = null;
        _alerts = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _explanation = null;
      _alertsError = null;
    });

    try {
      final snap = await _svc.getWatchlist(
        companyId: _companyId,
        plantKey: pk,
      );
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _loading = false;
        if (_selectedPlantLabel == null ||
            _selectedPlantLabel!.trim().isEmpty) {
          _selectedPlantLabel = snap.plantDisplayName;
        }
      });
      await _loadAlerts();
      _scrollToHighlightIfNeeded();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = firebaseCallableUserMessage(e);
        _snap = null;
      });
      await _loadAlerts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _snap = null;
      });
      await _loadAlerts();
    }
  }

  Future<void> _loadAlerts() async {
    if (!_canManageAlerts) {
      setState(() {
        _alerts = const [];
        _alertsLoading = false;
        _alertsError = null;
      });
      return;
    }
    final pk = _selectedPlantKey?.trim();
    setState(() {
      _alertsLoading = true;
      _alertsError = null;
    });
    try {
      final items = await _alertsSvc.listAlerts(
        companyId: _companyId,
        plantKey: pk,
        includeResolved: false,
      );
      if (!mounted) return;
      setState(() {
        _alerts = items;
        _alertsLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _alertsLoading = false;
        _alertsError = firebaseCallableUserMessage(e);
        _alerts = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _alertsLoading = false;
        _alertsError = e.toString();
        _alerts = const [];
      });
    }
  }

  void _scrollToHighlightIfNeeded() {
    final key = _highlightKey;
    if (key == null) return;
    if (!_alerts.any((a) => a.alertKey == key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _alertsSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
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
      fieldStartLabelText: 'Od',
      fieldEndLabelText: 'Do',
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    if (_selectedPlantKey != null) {
      await _load();
    }
  }

  Future<void> _refresh() async {
    final pk = _selectedPlantKey?.trim();
    if (pk == null || pk.isEmpty || !_canRefresh) return;

    setState(() {
      _refreshing = true;
      _error = null;
      _explanation = null;
    });

    try {
      final snap = await _svc.refreshWatchlist(
        companyId: _companyId,
        plantKey: pk,
        dateFrom: _fmt(_range.start),
        dateTo: _fmt(_range.end),
      );
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _refreshing = false;
      });
      await _loadAlerts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lista praćenja je osvježena.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseCallableUserMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _markAlertSeen(OperonixAiAlertItem item) async {
    if (_busyAlertKey != null) return;
    setState(() => _busyAlertKey = item.alertKey);
    try {
      final updated = await _alertsSvc.markSeen(
        companyId: _companyId,
        alertKey: item.alertKey,
        plantKey: _selectedPlantKey,
      );
      if (!mounted) return;
      setState(() {
        _alerts = _alerts
            .map((a) => a.alertKey == updated.alertKey ? updated : a)
            .toList();
        _busyAlertKey = null;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _busyAlertKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseCallableUserMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyAlertKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _snoozeAlert(OperonixAiAlertItem item) async {
    if (_busyAlertKey != null) return;
    final reasonCtrl = TextEditingController();
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var selectedDays = 1;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Odgodi upozorenje'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ovo odgađa samo AI upozorenje. Ne mijenja plan, '
                    'nalog ni NCR.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDays,
                    decoration: const InputDecoration(
                      labelText: 'Broj dana',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 dan')),
                      DropdownMenuItem(value: 3, child: Text('3 dana')),
                      DropdownMenuItem(value: 7, child: Text('7 dana')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => selectedDays = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Razlog (opcionalno)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selectedDays),
                  child: const Text('Odgodi'),
                ),
              ],
            );
          },
        );
      },
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (days == null || !mounted) return;

    setState(() => _busyAlertKey = item.alertKey);
    try {
      final updated = await _alertsSvc.snooze(
        companyId: _companyId,
        alertKey: item.alertKey,
        plantKey: _selectedPlantKey,
        reason: reason,
        snoozeDays: days,
      );
      if (!mounted) return;
      setState(() {
        _alerts = _alerts
            .map((a) => a.alertKey == updated.alertKey ? updated : a)
            .toList();
        _busyAlertKey = null;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _busyAlertKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseCallableUserMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyAlertKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _resolveAlert(OperonixAiAlertItem item) async {
    if (_busyAlertKey != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Označi kao riješeno'),
        content: const Text(
          'Zatvara se samo AI upozorenje. NCR, nalog i plan ostaju '
          'nepromijenjeni.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Riješi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyAlertKey = item.alertKey);
    try {
      final updated = await _alertsSvc.resolve(
        companyId: _companyId,
        alertKey: item.alertKey,
        plantKey: _selectedPlantKey,
      );
      if (!mounted) return;
      setState(() {
        // Aktivna lista — ukloni riješena
        _alerts = _alerts
            .where((a) => a.alertKey != updated.alertKey)
            .toList();
        _busyAlertKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI upozorenje je označeno kao riješeno.'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _busyAlertKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseCallableUserMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyAlertKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _explain() async {
    final pk = _selectedPlantKey?.trim();
    if (pk == null || pk.isEmpty) return;

    setState(() {
      _explaining = true;
      _error = null;
    });

    try {
      final text = await _svc.explainWatchlist(
        companyId: _companyId,
        plantKey: pk,
        message: 'Objasni trenutnu listu praćenja rizika i prilika.',
      );
      if (!mounted) return;
      setState(() {
        _explanation = text;
        _explaining = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _explaining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseCallableUserMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _explaining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsPlantPick = _sessionPlantKey == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(kOperonixAiWatchlistScreenTitle),
        actions: [
          IconButton(
            tooltip: 'Odabir perioda',
            onPressed: (_loading || _refreshing) ? null : _pickRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          if (_canRefresh)
            IconButton(
              tooltip: 'Osvježi prikaz',
              onPressed: (_refreshing ||
                      _loading ||
                      _selectedPlantKey == null)
                  ? null
                  : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Proaktivni pregled rangiranih rizika i prilika iz podatkovnog '
            'sloja Operonix Industrial platforme. Asistent može objasniti '
            'listu; ocjene i redoslijed dolaze iz sistema, ne iz slobodnog '
            'teksta.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: (_loading || _refreshing) ? null : _pickRange,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('Period: $_periodLabel'),
          ),
          if (needsPlantPick) ...[
            const SizedBox(height: 16),
            if (_plantsLoading)
              const LinearProgressIndicator()
            else if (_plantChoices.isEmpty)
              Text(
                'Nema dostupnih pogona. Dodaj pogon u postavkama kompanije.',
                style: TextStyle(color: theme.colorScheme.error),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey<String>(_selectedPlantKey ?? 'plant-pick'),
                initialValue: _selectedPlantKey,
                decoration: const InputDecoration(
                  labelText: 'Pogon',
                  border: OutlineInputBorder(),
                ),
                items: _plantChoices
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p.plantKey,
                        child: Text(p.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  final label = _plantChoices
                      .firstWhere((p) => p.plantKey == v)
                      .label;
                  setState(() {
                    _selectedPlantKey = v;
                    _selectedPlantLabel = label;
                  });
                  await _load();
                },
              ),
          ] else if (_selectedPlantLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              'Pogon: $_selectedPlantLabel',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            )
          else if (_snap != null)
            ..._buildSnapshotBody(theme, _snap!),
          if (_canManageAlerts &&
              _snap == null &&
              !_loading &&
              _selectedPlantKey != null) ...[
            const SizedBox(height: 8),
            ..._buildAlertsSection(theme),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: (_explaining ||
                    _loading ||
                    _selectedPlantKey == null)
                ? null
                : _explain,
            icon: _explaining
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _explaining ? 'Pripremam objašnjenje…' : 'Objasni listu praćenja',
            ),
          ),
          if (_explanation != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Objašnjenje Asistenta',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_explanation!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSnapshotBody(
    ThemeData theme,
    OperonixAiWatchlistSnapshot snap,
  ) {
    final period = [
      if (snap.periodFromLabel != null) snap.periodFromLabel,
      if (snap.periodToLabel != null) snap.periodToLabel,
    ].whereType<String>().join(' – ');

    return [
      if (!snap.found &&
          snap.topRisks.isEmpty &&
          snap.topOpportunities.isEmpty) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Još nema snimljene liste praćenja za ovaj pogon. '
              '${_canRefresh ? 'Pokreni osvježavanje.' : 'Zatraži osvježavanje od menadžera ili kvalitete.'}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        if (_canRefresh)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: (_refreshing || _loading) ? null : _refresh,
              child: const Text('Osvježi prikaz'),
            ),
          ),
      ],
      if (period.isNotEmpty || snap.refreshSourceLabel != null) ...[
        Text(
          [
            if (period.isNotEmpty) 'Period: $period',
            if (snap.refreshSourceLabel != null) snap.refreshSourceLabel!,
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
      ],
      Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preporučena prva akcija',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(snap.recommendedFirstAction),
            ],
          ),
        ),
      ),
      if (_canManageAlerts) ...[
        const SizedBox(height: 20),
        ..._buildAlertsSection(theme),
      ],
      const SizedBox(height: 16),
      Text(
        'Najveći rizici',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      if (snap.topRisks.isEmpty)
        Text(
          'Nema rangiranih rizika u trenutnom snimku.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else
        ...snap.topRisks.map((item) => _itemCard(theme, item, isRisk: true)),
      const SizedBox(height: 16),
      Text(
        'Najveće prilike',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      if (snap.topOpportunities.isEmpty)
        Text(
          'Nema rangiranih prilika u trenutnom snimku.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else
        ...snap.topOpportunities
            .map((item) => _itemCard(theme, item, isRisk: false)),
    ];
  }

  List<Widget> _buildAlertsSection(ThemeData theme) {
    return [
      KeyedSubtree(
        key: _alertsSectionKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upozorenja Asistenta',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kontrolisana dostava iz liste praćenja. Rješavanje upozorenja '
              'ne zatvara NCR niti mijenja nalog.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_alertsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else if (_alertsError != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _alertsError!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              )
            else if (_alerts.isEmpty)
              Text(
                'Nema aktivnih upozorenja Asistenta za odabrani opseg.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ..._alerts.map((a) => _alertCard(theme, a)),
          ],
        ),
      ),
    ];
  }

  Widget _alertCard(ThemeData theme, OperonixAiAlertItem item) {
    final highlighted = _highlightKey != null &&
        item.alertKey == _highlightKey;
    final busy = _busyAlertKey == item.alertKey;
    final contextBits = <String>[
      ...item.affectedProducts,
      ...item.affectedMachines,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: highlighted ? 2 : null,
        color: highlighted
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.typeLabel.isEmpty
                    ? item.kindLabel
                    : '${item.kindLabel}: ${item.typeLabel}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(
                      item.statusLabel,
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Chip(
                    label: Text(
                      'Ozbiljnost: ${item.severityLabel}',
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Chip(
                    label: Text(
                      'Ocjena: ${item.score}',
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pogon: ${item.plantDisplayName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.evidence != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Dokaz iz sistema',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(item.evidence!),
              ],
              if (item.recommendedFirstAction != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Preporučena prva akcija',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(item.recommendedFirstAction!),
              ],
              if (item.isDeferred && item.snoozeUntilLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Odgođeno do: ${item.snoozeUntilLabel}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (contextBits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  contextBits.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (busy)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.isNew)
                      OutlinedButton(
                        onPressed: () => _markAlertSeen(item),
                        child: const Text('Označi kao viđeno'),
                      ),
                    if (!item.isResolved)
                      OutlinedButton(
                        onPressed: () => _snoozeAlert(item),
                        child: const Text('Odgodi'),
                      ),
                    if (!item.isResolved)
                      FilledButton.tonal(
                        onPressed: () => _resolveAlert(item),
                        child: const Text('Označi kao riješeno'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(
    ThemeData theme,
    OperonixAiWatchlistItem item, {
    required bool isRisk,
  }) {
    final chips = <String>[
      if (item.riskLevel != null) 'Razina: ${item.riskLevel}',
      'Ocjena: ${item.score}',
      item.typeLabel,
    ];
    final contextBits = <String>[
      ...item.products,
      ...item.machines,
      ...item.openOrders,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.rank}. ${item.typeLabel}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: chips
                    .map(
                      (c) => Chip(
                        label: Text(c, style: theme.textTheme.labelSmall),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                isRisk ? 'Dokaz iz sistema' : 'Dokaz / signal',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(item.evidence),
              if (contextBits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  contextBits.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
