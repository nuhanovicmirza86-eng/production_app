import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../../ai/screens/production_tracking_assistant_screen.dart';
import '../../ai_analysis/screens/ai_analysis_screen.dart' show aiStructuredAnalysisVisibleForRole;
import '../../reports/screens/production_ai_report_screen.dart'
    show ProductionAiReportScreen, productionAiReportVisibleForRole;
import '../models/production_operator_tracking_entry.dart';
import '../models/production_tracking_ai_report_models.dart';
import '../services/production_tracking_ai_reports_service.dart';
import '../services/tracking_effective_plant_key.dart';

/// Brzi dnevni izvještaji (škart, uređaji) + ulaz u asistenta s kontekstom — tab „AI izvještaji“.
class ProductionTrackingAiReportsScreen extends StatefulWidget {
  const ProductionTrackingAiReportsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductionTrackingAiReportsScreen> createState() =>
      _ProductionTrackingAiReportsScreenState();
}

class _ProductionTrackingAiReportsScreenState
    extends State<ProductionTrackingAiReportsScreen> {
  final _svc = ProductionTrackingAiReportsService();

  bool _loading = true;
  Object? _error;
  String? _plantKey;
  String? _plantLabel;
  late DateTime _day;

  List<ProductScrapDayRollup> _topProducts = const [];
  List<ProductScrapDayRollup> _allProducts = const [];
  List<DeviceIssueDayRollup> _topDevices = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString();

  bool get _canAiAssistant {
    return ProductionModuleKeys.hasAiProductionAnalyticsModule(widget.companyData) &&
        aiStructuredAnalysisVisibleForRole(_role);
  }

  bool get _canMarkdownReport {
    return ProductionModuleKeys.hasAiProductionMarkdownReportModule(widget.companyData) &&
        productionAiReportVisibleForRole(_role);
  }

  static const Color _cardBg = Color(0xFF141418);
  static const Color _cardBorder = Color(0xFF2A2A32);
  static const Color _muted = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pk = await resolveEffectiveTrackingPlantKey(widget.companyData);
      if (pk == null || pk.isEmpty) {
        throw StateError('Nije odabran pogon (plantKey).');
      }
      final plantLabel = await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: pk,
      );
      final wd = ProductionTrackingAiReportsService.workDateKey(_day);
      final results = await Future.wait([
        _svc.loadTopScrapProductsByDay(
          companyId: _companyId,
          plantKey: pk,
          workDate: wd,
          limit: 5,
        ),
        _svc.loadAllScrapProductsByDay(
          companyId: _companyId,
          plantKey: pk,
          workDate: wd,
        ),
        _svc.loadTopDeviceIssuesByDay(
          companyId: _companyId,
          plantKey: pk,
          day: _day,
          limit: 5,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _plantKey = pk;
        _plantLabel = plantLabel;
        _topProducts = results[0] as List<ProductScrapDayRollup>;
        _allProducts = results[1] as List<ProductScrapDayRollup>;
        _topDevices = results[2] as List<DeviceIssueDayRollup>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _fmtDay(BuildContext context) {
    return MaterialLocalizations.of(context).formatFullDate(_day);
  }

  String _fmtPct(double v) =>
      '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

  String _fmtQty(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case ProductionOperatorTrackingEntry.phasePreparation:
        return 'Pripremna';
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prva kontrola';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Završna kontrola';
      default:
        return phase;
    }
  }

  void _openAssistantWithPrompt(BuildContext context) {
    final prompt = _svc.buildAssistantPrompt(
      workDateLabel: _fmtDay(context),
      plantLabel: _plantLabel ?? _plantKey ?? '',
      topProducts: _topProducts,
      topDevices: _topDevices,
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionTrackingAssistantScreen(
          companyData: widget.companyData,
          initialPrompt: prompt,
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final first = DateTime.now().subtract(const Duration(days: 120));
    final last = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI izvještaji'),
        actions: [
          IconButton(
            tooltip: 'Odaberi dan',
            onPressed: _loading ? null : _pickDay,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
          if (_canMarkdownReport)
            IconButton(
              tooltip: 'Dugi Markdown izvještaj (period)',
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProductionAiReportScreen(companyData: widget.companyData),
                  ),
                );
              },
              icon: const Icon(Icons.article_outlined),
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
                        Text(
                          AppErrorMapper.toMessage(_error!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: _load,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Radni dan: ${_fmtDay(context)} · ${_plantLabel ?? _plantKey ?? ''}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Brzi pregled za dnevne odluke. Asistent koristi ove brojke kao kontekst.',
                        style: theme.textTheme.bodySmall?.copyWith(color: _muted),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle(theme, 'Top 5 — najveći udio škarta'),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: _topProducts.isEmpty
                            ? Text(
                                'Nema dovoljno unosa za agregat (ili je masa ispod praga).',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _muted,
                                ),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < _topProducts.length; i++)
                                    _productTile(
                                      context,
                                      theme,
                                      cs,
                                      i + 1,
                                      _topProducts[i],
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle(theme, 'Izvještaj po proizvodu (svi s podacima)'),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: _allProducts.isEmpty
                            ? Text(
                                'Nema agregiranih proizvoda za ovaj dan.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _muted,
                                ),
                              )
                            : Column(
                                children: _allProducts
                                    .map(
                                      (p) => ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        childrenPadding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        title: Text(
                                          '${p.itemCode.isNotEmpty ? p.itemCode : p.itemName} · ${_fmtPct(p.scrapPct)} škarta',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        subtitle: Text(
                                          'Dobro ${_fmtQty(p.goodQty)} · Škart ${_fmtQty(p.scrapQty)} · Ukupno ${_fmtQty(p.totalMass)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: _muted),
                                        ),
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: p.entries.map((e) {
                                                final sc = e.scrapBreakdown
                                                    .fold<double>(
                                                  0,
                                                  (a, b) => a + b.qty,
                                                );
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 6,
                                                  ),
                                                  child: Text(
                                                    '${_phaseLabel(e.phase)}: '
                                                    'dobro ${_fmtQty(e.quantity)}, '
                                                    'škart ${_fmtQty(sc)}',
                                                    style: theme
                                                        .textTheme.bodySmall,
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle(
                        theme,
                        'Top 5 uređaja — zastoji, alarmi, kvarovi',
                      ),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: _topDevices.isEmpty
                            ? Text(
                                'Nema događaja u „Stanje uređaja“ niti prijavljenih kvarova za ovaj dan i pogon.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _muted,
                                ),
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < _topDevices.length; i++)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            cs.primary.withValues(alpha: 0.2),
                                        child: Text('${i + 1}'),
                                      ),
                                      title: Text(_topDevices[i].displayName),
                                      subtitle: Text(
                                        'Zastoji ${_topDevices[i].downtimeCount} · '
                                        'Alarmi ${_topDevices[i].alarmCount} · '
                                        'Kvarovi ${_topDevices[i].faultCount}',
                                      ),
                                      trailing: Text(
                                        'Bodovi ${_topDevices[i].score}',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          color: cs.tertiary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle(theme, 'AI asistent — sugestije'),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Asistent može povezati škart s ponavljajućim zastojima i alarmima '
                              '(isti pogon, isti dan). Predloženi upit ispunjava se automatski; '
                              'pošalji ga ili prilagodi.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_canAiAssistant)
                              FilledButton.icon(
                                onPressed: () =>
                                    _openAssistantWithPrompt(context),
                                icon: const Icon(Icons.psychology_outlined),
                                label: const Text(
                                  'Otvori asistenta s analizom dana',
                                ),
                              )
                            else
                              Text(
                                'Potreban je modul AI Assistant Production (ili legacy ai_assistant) '
                                'i uloga s pristupom operativnom asistentu.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String t) {
    return Text(
      t,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: child,
    );
  }

  Widget _productTile(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    int rank,
    ProductScrapDayRollup p,
  ) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: CircleAvatar(
        backgroundColor: cs.error.withValues(alpha: 0.2),
        child: Text(
          '$rank',
          style: TextStyle(
            color: cs.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        p.itemCode.isNotEmpty ? p.itemCode : p.itemName,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '${_fmtPct(p.scrapPct)} škarta · '
        'dobro ${_fmtQty(p.goodQty)} · škart ${_fmtQty(p.scrapQty)}',
        style: theme.textTheme.bodySmall?.copyWith(color: _muted),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: p.entries.map((e) {
              final sc =
                  e.scrapBreakdown.fold<double>(0, (a, b) => a + b.qty);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_phaseLabel(e.phase)}: dobro ${_fmtQty(e.quantity)}, škart ${_fmtQty(sc)}',
                  style: theme.textTheme.bodySmall,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
