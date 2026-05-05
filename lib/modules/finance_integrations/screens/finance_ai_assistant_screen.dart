import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../../core/company_plant_display_name.dart';
import '../models/finance_ai_company_memory_doc.dart';
import '../models/finance_ai_insight_doc.dart';
import '../models/finance_kpi_snapshot_model.dart';
import '../services/finance_ai_company_memory_service.dart';
import '../services/finance_ai_insight_service.dart';
import '../services/finance_ai_insights_list_service.dart';
import '../services/finance_kpi_snapshot_service.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import '../widgets/finance_screen_context_info.dart';

/// Finance & Controlling — centralni AI asistent (upozorenja, analiza, kontekst kompanije).
class FinanceAiAssistantScreen extends StatefulWidget {
  const FinanceAiAssistantScreen({
    super.key,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    this.plantKey = '',
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;
  final bool debugUnlockModule;

  @override
  State<FinanceAiAssistantScreen> createState() => _FinanceAiAssistantScreenState();
}

class _FinanceAiAssistantScreenState extends State<FinanceAiAssistantScreen> {
  final _ai = FinanceAiInsightService();
  final _memorySvc = FinanceAiCompanyMemoryService();
  final _insightsList = FinanceAiInsightsListService();
  final _kpiSvc = FinanceKpiSnapshotService();

  bool _runningWatch = false;
  bool _runningAnalysis = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canAi => FinancePermissions.canRunFinanceControllingAiInsight(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canEditMemory =>
      FinancePermissions.canEditFinanceAiCompanyMemory(_role);

  Future<void> _showMarkdown(
    BuildContext context, {
    required String markdown,
    required String title,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: markdown,
                selectable: true,
                shrinkWrap: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zatvori'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runWatchlist(BuildContext context) async {
    if (!_canAi ||
        _companyId.isEmpty ||
        widget.businessYearId.trim().isEmpty) {
      return;
    }
    setState(() => _runningWatch = true);
    try {
      final r = await _ai.runInsight(
        companyId: _companyId,
        businessYearId: widget.businessYearId.trim(),
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
        plantKey: widget.plantKey.trim(),
        insightKind: FinanceAiInsightService.insightKindWatchlist,
      );
      if (!context.mounted) return;
      await _showMarkdown(
        context,
        markdown: r.markdown,
        title: 'AI — signalni pregled',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'AI nije uspio.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _runningWatch = false);
    }
  }

  Future<void> _runAnalysis(BuildContext context) async {
    if (!_canAi ||
        _companyId.isEmpty ||
        widget.businessYearId.trim().isEmpty) {
      return;
    }
    final focusCtrl = TextEditingController();
    final focus = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('AI — dubinska analiza'),
          content: SingleChildScrollView(
            child: TextField(
              controller: focusCtrl,
              decoration: const InputDecoration(
                labelText: 'Prioritet (opcionalno)',
                hintText: 'Npr. marža po proizvodu, zastoji, COPQ…',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, focusCtrl.text.trim()),
              child: const Text('Generiraj'),
            ),
          ],
        );
      },
    );
    focusCtrl.dispose();
    if (!context.mounted || focus == null) return;

    setState(() => _runningAnalysis = true);
    try {
      final r = await _ai.runInsight(
        companyId: _companyId,
        businessYearId: widget.businessYearId.trim(),
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
        plantKey: widget.plantKey.trim(),
        analysisFocus: focus,
        insightKind: FinanceAiInsightService.insightKindAnalysis,
      );
      if (!context.mounted) return;
      await _showMarkdown(
        context,
        markdown: r.markdown,
        title: 'AI — analiza',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'AI nije uspio.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _runningAnalysis = false);
    }
  }

  Future<void> _editMemoryDialog(
    BuildContext context,
    FinanceAiCompanyMemoryDoc? current,
  ) async {
    final ctrl = TextEditingController(text: current?.assistantContext ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Poslovni kontekst za AI'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Kratko opišite proizvode, strateške prioritete i knjigovodstvene '
                    'nuanse koje AI smije znati (bez lozinki i tajnih brojeva). '
                    'Tekst se dodaje u svaki Finance AI poziv za ovu kompaniju.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      hintText:
                          'Npr. fokus na MCU liniji, tarife energije, ključni kupci…',
                    ),
                  ),
                ],
              ),
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
    if (ok != true || !context.mounted) {
      ctrl.dispose();
      return;
    }
    try {
      await _memorySvc.upsertAssistantContext(
        companyId: _companyId,
        assistantContext: ctrl.text,
      );
      ctrl.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI kontekst kompanije je spremljen.')),
      );
    } on FirebaseFunctionsException catch (e) {
      ctrl.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Spremanje nije uspjelo.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      ctrl.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  List<_FinanceSignalChip> _signalsFromKpi(FinanceKpiSnapshotModel? s) {
    if (s == null) {
      return const [
        _FinanceSignalChip(
          'Za ovaj period još nema spremljenog sažetka. Otvorite karticu Pregled u istom modulu i pokrenite preračun.',
          Icons.info_outline,
        ),
      ];
    }
    final out = <_FinanceSignalChip>[];
    final rev = s.revenue;
    final tc = s.totalCost;
    if (rev > 0 && s.grossMargin / rev < 0.05) {
      out.add(
        const _FinanceSignalChip(
          'Marža je ispod 5% prihoda — provjerite strukturu troška i cijene.',
          Icons.trending_down_outlined,
          emphasis: true,
        ),
      );
    }
    if (tc > 0 && s.downtimeLoss / tc > 0.12) {
      out.add(
        const _FinanceSignalChip(
          'Zastoji (novčano) prelaze ~12% ukupnih troškova u snimku.',
          Icons.pause_circle_outline,
          emphasis: true,
        ),
      );
    }
    if (!s.orderProfitabilityAvailable) {
      out.add(
        const _FinanceSignalChip(
          'Profitabilnost po nalogu nije potpuno dostupna — AI naglašava ograničenje u interpretaciji.',
          Icons.receipt_long_outlined,
        ),
      );
    }
    if ((s.copqProductionCost + s.copqQualityEstimatedCost) > 0 &&
        tc > 0 &&
        (s.copqProductionCost + s.copqQualityEstimatedCost) / tc > 0.08) {
      out.add(
        const _FinanceSignalChip(
          'COPQ (proizvodnja + NCR procjena) zauzima značajan udio troška.',
          Icons.warning_amber_outlined,
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        const _FinanceSignalChip(
          'Nema izraženih numeričkih upozorenja u sažetku — ipak pokrenite listu za praćenje.',
          Icons.check_circle_outline,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final periodFmt = DateFormat.yMMMM(locale);

    if (!_canAi) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finance AI asistent')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nemate pretplatu ili ulogu za Finance AI. Potrebna je opcija '
              'Kontroling financija s AI pristupom u vašoj pretplati.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    if (widget.businessYearId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finance AI asistent')),
        body: Center(
          child: Text(
            'Odaberite poslovnu godinu u zaglavlju huba.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance AI asistent'),
        actions: [
          FinanceScreenContextInfo(
            title: 'Kako asistent koristi kontekst',
            body:
                'Tekst koji ovdje unese administrator dodaje se svakom Finance AI '
                'pozivu na poslužitelju. Povijest generiranih uvida čuva se sigurno '
                'uz vašu kompaniju. Vanjski model ne uči na vašim podacima izvan '
                'ovog toka — koriste se samo sažeci koje Vi generirate i spremljeni '
                'kontekst.',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<String>(
            future: widget.plantKey.trim().isEmpty
                ? Future<String>.value('')
                : CompanyPlantDisplayName.resolve(
                    companyId: _companyId,
                    plantKey: widget.plantKey.trim(),
                  ),
            builder: (context, plantSnap) {
              final pk = widget.plantKey.trim();
              final plantLine = pk.isEmpty
                  ? 'svi pogoni (zbroj)'
                  : 'pogon: ${plantSnap.connectionState == ConnectionState.waiting ? '…' : (plantSnap.data != null && plantSnap.data!.isNotEmpty ? plantSnap.data! : pk)}';
              return Text(
                '${periodFmt.format(DateTime(widget.periodYear, widget.periodMonth))} · '
                '$plantLine',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<FinanceAiCompanyMemoryDoc?>(
            stream: _memorySvc.watchMemory(companyId: _companyId),
            builder: (context, memSnap) {
              final m = memSnap.data;
              final hasCtx = (m?.assistantContext ?? '').trim().isNotEmpty;
              return Card(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasCtx
                                  ? 'Memorija kompanije aktivna (kontekst za svaki AI poziv).'
                                  : 'Još nema spremljenog poslovnog konteksta za AI.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (hasCtx) ...[
                        const SizedBox(height: 8),
                        Text(
                          m!.assistantContext.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_canEditMemory) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _editMemoryDialog(context, m),
                            icon: const Icon(Icons.edit_note_outlined),
                            label: Text(
                              hasCtx ? 'Uredi kontekst' : 'Dodaj kontekst',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<FinanceKpiSnapshotModel?>(
            stream: _kpiSvc.watchSnapshot(
              companyId: _companyId,
              businessYearId: widget.businessYearId.trim(),
              periodYear: widget.periodYear,
              periodMonth: widget.periodMonth,
              plantKey: widget.plantKey.trim(),
            ),
            builder: (context, kpiSnap) {
              final chips = _signalsFromKpi(kpiSnap.data);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Brzi numerički signali (iz sažetka)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...chips.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                c.icon,
                                size: 20,
                                color: c.emphasis
                                    ? cs.error
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c.text)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'AI radnje',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: (_runningWatch || _runningAnalysis)
                ? null
                : () => _runWatchlist(context),
            icon: _runningWatch
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.shield_moon_outlined),
            label: Text(_runningWatch ? 'Signalni pregled…' : 'Signalni pregled (brza lista)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: (_runningWatch || _runningAnalysis)
                ? null
                : () => _runAnalysis(context),
            icon: _runningAnalysis
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(_runningAnalysis ? 'Analiza…' : 'Dubinska analiza'),
          ),
          const SizedBox(height: 20),
          Text(
            'Zadnji zapisi u ovom periodu',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<FinanceAiInsightDoc>>(
            stream: _insightsList.watchRecentForPeriod(
              companyId: _companyId,
              businessYearId: widget.businessYearId.trim(),
              periodYear: widget.periodYear,
              periodMonth: widget.periodMonth,
              plantKey: widget.plantKey.trim(),
              limit: 8,
            ),
            builder: (context, hist) {
              if (hist.hasError) {
                final msg = financeUserFacingLoadError(hist.error);
                final raw = '${hist.error}'.trim();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        msg,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                        ),
                      ),
                    ),
                    if (raw.isNotEmpty)
                      FinanceTechnicalInfoIcon(
                        detail: raw,
                        dialogTitle: 'Tehnički detalj',
                      ),
                  ],
                );
              }
              final list = hist.data;
              if (list == null) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (list.isEmpty) {
                return Text(
                  'Još nema AI zapisa za ovaj period.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                );
              }
              final df = DateFormat.yMMMd(locale).add_Hm();
              return Column(
                children: list.map((e) {
                  final when = e.createdAt != null
                      ? df.format(e.createdAt!.toLocal())
                      : '—';
                  final kindLabel =
                      e.insightKind == FinanceAiInsightService.insightKindWatchlist
                          ? 'Lista za praćenje'
                          : 'Analiza';
                  final sched =
                      e.sourceTrigger == 'scheduled_nightly' ? ' · noćni' : '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      title: Text(when),
                      subtitle: Text(
                        e.analysisFocus != null &&
                                e.analysisFocus!.trim().isNotEmpty
                            ? '${e.analysisFocus} · $kindLabel$sched'
                            : '$kindLabel$sched',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showMarkdown(
                        context,
                        markdown: e.analysisMarkdown,
                        title: 'AI zapis — $when',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FinanceSignalChip {
  const _FinanceSignalChip(
    this.text,
    this.icon, {
    this.emphasis = false,
  });

  final String text;
  final IconData icon;
  final bool emphasis;
}
