import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_help_texts.dart';
import '../utils/development_permissions.dart';
import '../../production/ooe/widgets/ooe_info_icon.dart';

class _ChatLine {
  const _ChatLine({required this.fromUser, required this.markdown});
  final bool fromUser;
  final String markdown;
}

/// AI asistent za Razvoj — svaka poruka poziva [runDevelopmentProjectAiAnalysis]
/// s [analysisFocus] (server učitava pun kontekst projekta). Višekratni razgovor
/// bez pamćenja između poruka (arhitektura: tenant + jedan projekat po Callableu).
class DevelopmentPortfolioAiAssistantTab extends StatefulWidget {
  const DevelopmentPortfolioAiAssistantTab({
    super.key,
    required this.companyData,
    required this.projects,
    required this.showPlantChip,
    required this.onOpenProject,
  });

  final Map<String, dynamic> companyData;
  final List<DevelopmentProjectModel> projects;
  /// Isto što i na tabu Projekti — prikaz pogona na kartici kad je portfelj za cijelu kompaniju.
  final bool showPlantChip;
  final void Function(DevelopmentProjectModel p) onOpenProject;

  @override
  State<DevelopmentPortfolioAiAssistantTab> createState() =>
      _DevelopmentPortfolioAiAssistantTabState();
}

class _DevelopmentPortfolioAiAssistantTabState
    extends State<DevelopmentPortfolioAiAssistantTab> {
  final DevelopmentProjectService _service = DevelopmentProjectService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatLine> _lines = [];

  DevelopmentProjectModel? _selected;
  bool _busy = false;

  bool get _canAi => DevelopmentPermissions.canRunDevelopmentProjectAi(
        role: widget.companyData['role']?.toString(),
        companyData: widget.companyData,
      );

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DevelopmentPortfolioAiAssistantTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null &&
        !widget.projects.any((p) => p.id == _selected!.id)) {
      setState(() => _selected = null);
    }
  }

  Future<void> _send({
    String? presetQuestion,
    bool defaultSummary = false,
  }) async {
    final project = _selected;
    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    if (!_canAi) return;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odaberi projekat iz liste — AI koristi njegov pun kontekst.'),
        ),
      );
      return;
    }

    late final String userDisplay;
    final String? analysisFocus;
    if (defaultSummary) {
      userDisplay = 'Sažetak stanja i prioriteti (podrazumijevano)';
      analysisFocus = null;
    } else {
      final q = (presetQuestion ?? _input.text).trim();
      if (q.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upiši pitanje ili koristi brzi predložak ispod.'),
          ),
        );
        return;
      }
      userDisplay = q;
      analysisFocus = q;
      if (presetQuestion == null) {
        _input.clear();
      }
    }

    final companyId = cid;
    final plantKey = project.plantKey.trim();
    if (companyId.isEmpty || plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaju podaci o organizaciji ili pogonu.')),
      );
      return;
    }

    setState(() {
      _lines.add(_ChatLine(fromUser: true, markdown: userDisplay));
      _busy = true;
    });
    _scrollBottom();

    try {
      final md = await _service.runDevelopmentProjectAiAnalysis(
        companyId: companyId,
        plantKey: plantKey,
        projectId: project.id,
        analysisFocus: analysisFocus,
      );
      if (!mounted) return;
      setState(() {
        _lines.add(_ChatLine(fromUser: false, markdown: md));
        _busy = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final m = e.message?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (m != null && m.isNotEmpty) ? m : 'AI trenutno nije dostupan.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI: $e')),
      );
    }
    _scrollBottom();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!_canAi) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Icon(Icons.auto_awesome_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'AI asistent za Razvoj',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Ova mogućnost zahtijeva pretplatu (npr. development_ai ili OperonixAI Production) '
            'i ulogu s pravom pregleda AI analize. Duboka analiza ide uz odabrani projekat — '
            'model ne odobrava Gate niti release.\n\n'
            'Analitika portfelja (KPI i grafovi) nalazi se na tabu Analitika, ne ovdje.',
            style: tt.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      );
    }

    if (widget.projects.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'AI asistent',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Ovaj tab je samo za razgovor uz odabrani projekat (puni kontekst na serveru). '
            'Trenutno nema projekata u opsegu portfelja — promijeni poslovnu godinu ili pogon.',
            style: tt.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'KPI, Gate graf i dobavljači: tab Analitika. Lista i filteri: tab Projekti.',
            style: tt.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () {
              final tc = DefaultTabController.maybeOf(context);
              if (tc != null) tc.animateTo(0);
            },
            icon: const Icon(Icons.view_list_outlined),
            label: const Text('Prijeđi na tab Projekti'),
          ),
        ],
      );
    }

    Widget bubble(_ChatLine line) {
      final user = line.fromUser;
      return Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.92,
          ),
          child: Card(
            elevation: 0,
            color: user
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.75),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(user ? 14 : 4),
                bottomRight: Radius.circular(user ? 4 : 14),
              ),
              side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: user
                  ? Text(line.markdown, style: tt.bodyMedium)
                  : MarkdownBody(
                      data: line.markdown,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: tt.bodyMedium,
                        h3: tt.titleMedium,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    final presets = <({String label, String? focus, bool defaultSummary})>[
      (label: 'Sažetak i alarmi', focus: null, defaultSummary: true),
      (
        label: 'Rizici i blokade releasea',
        focus:
            'Fokus: rizici koji mogu blokirati release, izmjene (ECO) i otvoreni zahtjevi za odobrenje.',
        defaultSummary: false,
      ),
      (
        label: 'Dokumenti i Gate',
        focus:
            'Fokus: dokumentacija (vrste, statusi, linkedGate) i što nedostaje za aktualni Gate.',
        defaultSummary: false,
      ),
      (
        label: 'Red Team',
        focus: 'red_team launch_intelligence',
        defaultSummary: false,
      ),
      (
        label: 'Dobavljači (IATF 8.4)',
        focus:
            'Fokus: vanjski dobavljači iz JSON polja suppliers — status odobrenja, rokovi (dueDateMs), '
            'ocjene kvalitet/rok/cijena, IATF trag; poveži s rizicima i zadacima ako su taskId navedeni.',
        defaultSummary: false,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Kontekst projekta',
                        style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OoeInfoIcon(
                      tooltip: DevelopmentHelpTexts.portfolioAiContextTooltip,
                      dialogTitle: DevelopmentHelpTexts.portfolioAiContextTitle,
                      dialogBody: DevelopmentHelpTexts.portfolioAiContextBody,
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Projekat',
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selected != null &&
                              widget.projects.any((p) => p.id == _selected!.id)
                          ? _selected!.id
                          : null,
                      isExpanded: true,
                      isDense: true,
                      hint: const Text('Odaberi…'),
                      items: widget.projects
                          .map(
                            (p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(
                                '${p.projectCode} · ${p.projectName.isEmpty ? '—' : p.projectName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        setState(() {
                          if (id == null) {
                            _selected = null;
                          } else {
                            _selected =
                                widget.projects.firstWhere((p) => p.id == id);
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI analizira jedan projekat po zahtjevu (podaci se učitavaju na poslužitelju). '
                        'Ne odobrava Gate niti release.',
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (_selected != null)
                      IconButton(
                        tooltip: 'Potpuni pregled projekta',
                        onPressed: () => widget.onOpenProject(_selected!),
                        icon: const Icon(Icons.open_in_new),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text('Brzi predlošci', style: tt.labelMedium),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final p = presets[i];
              return FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => p.defaultSummary
                        ? _send(defaultSummary: true)
                        : _send(presetQuestion: p.focus!),
                child: Text(
                  p.label,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              if (_lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Odaberi projekat i pošalji pitanje ili pritisni brzi predložak. '
                    'Odgovori su na bosanskom; koriste samo podatke iz sustava.',
                    style: tt.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ..._lines.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: bubble(e),
                  )),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
        Material(
          elevation: 2,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Pitanje o odabranom projektu…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) {
                        if (!_busy) _send();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _send(),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
