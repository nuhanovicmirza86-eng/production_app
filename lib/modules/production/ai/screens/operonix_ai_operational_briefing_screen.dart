import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/branding/operonix_ai_branding.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../services/firebase_callable_user_message.dart';
import '../services/operonix_ai_operational_briefing_service.dart';

/// AI-M3-G4 — dnevni operativni briefing (G2/G3 Callables).
class OperonixAiOperationalBriefingScreen extends StatefulWidget {
  const OperonixAiOperationalBriefingScreen({
    super.key,
    required this.companyData,
    this.initialPlantKey,
    this.initialPlantLabel,
  });

  final Map<String, dynamic> companyData;

  /// Opaque plant scope from mes_inbox (not shown as raw ID in UI).
  final String? initialPlantKey;
  final String? initialPlantLabel;

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

  static bool canRefresh(Map<String, dynamic> companyData) =>
      canView(companyData);

  @override
  State<OperonixAiOperationalBriefingScreen> createState() =>
      _OperonixAiOperationalBriefingScreenState();
}

class _OperonixAiOperationalBriefingScreenState
    extends State<OperonixAiOperationalBriefingScreen> {
  final _svc = OperonixAiOperationalBriefingService();

  bool _loading = true;
  bool _refreshing = false;
  bool _acking = false;
  bool _markingViewed = false;
  String? _error;
  OperonixAiOperationalBriefingSnapshot? _snap;

  String? _selectedPlantKey;
  String? _selectedPlantLabel;
  List<({String plantKey, String label})> _plantChoices = [];
  bool _plantsLoading = false;

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
      OperonixAiOperationalBriefingScreen.canRefresh(widget.companyData);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final initialPk = (widget.initialPlantKey ?? '').trim();
    if (initialPk.isNotEmpty) {
      _selectedPlantKey = initialPk;
      _selectedPlantLabel = (widget.initialPlantLabel ?? '').trim().isEmpty
          ? null
          : widget.initialPlantLabel!.trim();
      _selectedPlantLabel ??= await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: initialPk,
      );
      if ((_selectedPlantLabel ?? '').startsWith('PLANT_')) {
        _selectedPlantLabel = 'Pogon';
      }
      await _load();
      return;
    }

    final sessionPk = _sessionPlantKey;
    if (sessionPk != null) {
      _selectedPlantKey = sessionPk;
      _selectedPlantLabel = _sessionPlantLabel;
      _selectedPlantLabel ??= await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: sessionPk,
      );
      if ((_selectedPlantLabel ?? '').startsWith('PLANT_')) {
        _selectedPlantLabel = 'Pogon';
      }
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
        _error = 'Odaberi pogon za prikaz briefinga.';
        _snap = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _svc.getBriefing(
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
      await _autoMarkViewed(snap);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = firebaseCallableUserMessage(e);
        _snap = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _snap = null;
      });
    }
  }

  Future<void> _autoMarkViewed(OperonixAiOperationalBriefingSnapshot snap) async {
    if (!snap.needsViewMark || _markingViewed) return;
    setState(() => _markingViewed = true);
    try {
      final updated = await _svc.markViewed(
        companyId: _companyId,
        briefingKey: snap.briefingKey,
        plantKey: _selectedPlantKey,
      );
      if (!mounted) return;
      setState(() {
        _snap = updated;
        _markingViewed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingViewed = false);
      // Soft: opening still shows briefing even if viewed mark fails.
    }
  }

  Future<void> _refresh() async {
    final pk = _selectedPlantKey?.trim();
    if (pk == null || pk.isEmpty || !_canRefresh) return;

    setState(() {
      _refreshing = true;
      _error = null;
    });

    try {
      final snap = await _svc.refreshBriefing(
        companyId: _companyId,
        plantKey: pk,
      );
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _refreshing = false;
      });
      await _autoMarkViewed(snap);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Briefing je osvježen.')),
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

  Future<void> _acknowledge() async {
    final snap = _snap;
    if (snap == null ||
        !snap.found ||
        snap.briefingKey.isEmpty ||
        snap.isAcknowledged ||
        _acking) {
      return;
    }

    setState(() => _acking = true);
    try {
      final updated = await _svc.acknowledge(
        companyId: _companyId,
        briefingKey: snap.briefingKey,
        plantKey: _selectedPlantKey,
      );
      if (!mounted) return;
      setState(() {
        _snap = updated;
        _acking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Briefing je potvrđen. Ovo ne zatvara upozorenja Asistenta ni NCR.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _acking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firebaseCallableUserMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _acking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsPlantPick =
        _sessionPlantKey == null && (widget.initialPlantKey ?? '').isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(kOperonixAiOperationalBriefingScreenTitle),
        actions: [
          if (_canRefresh)
            IconButton(
              tooltip: 'Osvježi briefing',
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
            'Čitljiv menadžerski sažetak rizika, prilika i otvorenih '
            'upozorenja Asistenta za dan. Potvrda briefinga nije poslovna '
            'akcija i ne zatvara upozorenja ni NCR.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
            ..._buildBody(theme, _snap!),
        ],
      ),
    );
  }

  List<Widget> _buildBody(
    ThemeData theme,
    OperonixAiOperationalBriefingSnapshot snap,
  ) {
    if (!snap.found &&
        snap.topRisks.isEmpty &&
        snap.topOpportunities.isEmpty &&
        snap.openAlerts.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Još nema dnevnog briefinga za ovaj pogon. '
              '${_canRefresh ? 'Pokreni osvježavanje.' : 'Zatraži osvježavanje od menadžera ili kvalitete.'}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ];
    }

    final meta = [
      if (snap.briefingDayLabel != null) 'Dan: ${snap.briefingDayLabel}',
      snap.statusLabel,
      if (snap.refreshSourceLabel != null) snap.refreshSourceLabel!,
    ].join(' · ');

    return [
      if (meta.isNotEmpty) ...[
        Text(
          meta,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
      ],
      Card(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sažetak',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(snap.summaryText),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(theme, 'Rizici: ${snap.riskCount}'),
                  _chip(theme, 'Prilike: ${snap.opportunityCount}'),
                  _chip(theme, 'Upozorenja: ${snap.openAlertCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prva preporučena akcija',
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
      const SizedBox(height: 12),
      if (!snap.isAcknowledged)
        FilledButton.icon(
          onPressed: (_acking || _loading) ? null : _acknowledge,
          icon: _acking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_outlined),
          label: Text(
            _acking ? 'Potvrđujem…' : 'Potvrdi briefing',
          ),
        )
      else
        Card(
          child: ListTile(
            leading: Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Briefing je potvrđen'),
            subtitle: const Text(
              'Potvrda znači da je sažetak pročitan — ne zatvara '
              'upozorenja Asistenta ni NCR.',
            ),
          ),
        ),
      const SizedBox(height: 20),
      _sectionTitle(theme, 'Najvažniji rizici'),
      if (snap.topRisks.isEmpty)
        _emptyLine(theme, 'Nema rangiranih rizika u briefingu.')
      else
        ...snap.topRisks.map((item) => _riskCard(theme, item)),
      const SizedBox(height: 16),
      _sectionTitle(theme, 'Najvažnije prilike'),
      if (snap.topOpportunities.isEmpty)
        _emptyLine(theme, 'Nema rangiranih prilika u briefingu.')
      else
        ...snap.topOpportunities.map((item) => _oppCard(theme, item)),
      const SizedBox(height: 16),
      _sectionTitle(theme, 'Otvorena upozorenja Asistenta'),
      if (snap.openAlerts.isEmpty)
        _emptyLine(theme, 'Nema otvorenih upozorenja Asistenta u briefingu.')
      else
        ...snap.openAlerts.map((item) => _alertCard(theme, item)),
      const SizedBox(height: 16),
      _sectionTitle(theme, 'Promjene od prethodnog dana'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < snap.changes.lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                Text(snap.changes.lines[i]),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyLine(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, String label) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _riskCard(ThemeData theme, OperonixAiBriefingRiskItem item) {
    final tags = <String>[
      if (item.riskLevel != null) item.riskLevel!,
      'Ocjena ${item.score}',
      ...item.products.take(2),
      ...item.machines.take(2),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
            Text(item.evidence),
            const SizedBox(height: 8),
            Text(
              'Preporučena akcija: ${item.firstAction}',
              style: theme.textTheme.bodySmall,
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((t) => _chip(theme, t)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _oppCard(ThemeData theme, OperonixAiBriefingOpportunityItem item) {
    final tags = <String>[
      'Ocjena ${item.score}',
      ...item.products.take(2),
      ...item.machines.take(2),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
            Text(item.evidence),
            const SizedBox(height: 8),
            Text(
              'Preporučena akcija: ${item.firstAction}',
              style: theme.textTheme.bodySmall,
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((t) => _chip(theme, t)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alertCard(ThemeData theme, OperonixAiBriefingOpenAlertItem item) {
    final title = [
      item.kindLabel,
      if (item.typeLabel.isNotEmpty) item.typeLabel,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          [
            'Status: ${item.statusLabel}',
            'Ozbiljnost: ${item.severityLabel}',
            'Pogon: ${item.plantDisplayName}',
            'Ocjena: ${item.score}',
          ].join(' · '),
        ),
      ),
    );
  }
}
