import 'dart:async' show unawaited;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/branding/operonix_ai_branding.dart';
import '../../../../core/company_plant_display_name.dart';
import '../models/production_ai_chat_message.dart';
import '../services/firebase_callable_user_message.dart';
import '../services/production_ai_chat_persistence.dart';
import '../services/production_tracking_assistant_client_service.dart';

/// Operativni asistent nad praćenjem proizvodnje (Callable [productionTrackingAssistant]).
class ProductionTrackingAssistantScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// Unaprijed ispunjen upit (npr. zalijepljen iz „Brzi izvještaji“ / drugih ekrana).
  final String? initialPrompt;

  /// Učitava backend fokus-blok s ORV, MES, zastojima, feedbackom (Callable).
  final String? evaluationEmployeeDocId;
  final String? evaluationPeriodYyyyMm;

  /// Kad je [true] i [initialPrompt] nije prazan, prvi se upit automatski šalje nakon učitavanja.
  final bool autoSendInitialPrompt;

  /// Prazni spremljeni thread za taj pogon (npr. fokus „evidencija ocjene“) da se odmah učitaju novi kontekst i upit.
  final bool startFreshThread;

  const ProductionTrackingAssistantScreen({
    super.key,
    required this.companyData,
    this.initialPrompt,
    this.evaluationEmployeeDocId,
    this.evaluationPeriodYyyyMm,
    this.autoSendInitialPrompt = false,
    this.startFreshThread = false,
  });

  @override
  State<ProductionTrackingAssistantScreen> createState() =>
      _ProductionTrackingAssistantScreenState();
}

class _ProductionTrackingAssistantScreenState
    extends State<ProductionTrackingAssistantScreen>
    with WidgetsBindingObserver {
  final _svc = ProductionTrackingAssistantClientService();
  final _prompt = TextEditingController();
  final _scroll = ScrollController();
  final List<ProductionAiChatMessage> _turns = [];
  bool _loading = false;
  bool _restored = false;

  /// Za [isCompanyWideContextRole]: [null] = Callable bez [plantKey] (cijela tvrtka).
  /// Ne inicijalizirati iz sesijskog pogona — korisnik eksplicitno bira filter u UI.
  String? _assistantPlantScopeKey;
  List<({String plantKey, String label})> _plantChoices = [];
  bool _plantChoicesLoaded = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _sessionPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _orvFocus {
    final e = (widget.evaluationEmployeeDocId ?? '').trim();
    final p = (widget.evaluationPeriodYyyyMm ?? '').trim();
    return e.isNotEmpty && p.isNotEmpty;
  }

  bool get _isCompanyWideContextUser {
    return ProductionAccessHelper.isCompanyWideContextRole(
      ProductionAccessHelper.rawRoleFromCompanySession(widget.companyData),
    );
  }

  bool get _showPlantScopeSelector =>
      _isCompanyWideContextUser && !_orvFocus;

  String get _threadStorageKey {
    if (_isCompanyWideContextUser) {
      if (_orvFocus) {
        return _sessionPlantKey.isEmpty
            ? '__orv_missing_plant__'
            : _sessionPlantKey;
      }
      final scoped = (_assistantPlantScopeKey ?? '').trim();
      if (scoped.isEmpty) return '__company_wide__';
      return scoped;
    }
    return _sessionPlantKey;
  }

  bool get _canUseChatPersistence {
    if (_companyId.isEmpty) return false;
    if (_orvFocus) return _sessionPlantKey.isNotEmpty;
    if (!_isCompanyWideContextUser && _sessionPlantKey.isEmpty) {
      return false;
    }
    return true;
  }

  /// Za Callable: [null] = izostavi [plantKey] (backend: doseg cijele tvrtke za globalne uloge).
  String? get _plantKeyForCallable {
    if (_orvFocus) {
      final s = _sessionPlantKey;
      return s.isEmpty ? null : s;
    }
    if (_isCompanyWideContextUser) {
      final scoped = (_assistantPlantScopeKey ?? '').trim();
      if (scoped.isEmpty) return null;
      return scoped;
    }
    final s = _sessionPlantKey;
    return s.isEmpty ? null : s;
  }

  String? get _dropdownPlantValue {
    final s = _assistantPlantScopeKey;
    if (s == null || s.trim().isEmpty) return null;
    final t = s.trim();
    if (_plantChoices.any((e) => e.plantKey == t)) return t;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPlantChoices());
    unawaited(_restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prompt.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resyncFromCloud());
    }
  }

  Future<void> _loadPlantChoices() async {
    if (!_showPlantScopeSelector) {
      if (mounted) setState(() => _plantChoicesLoaded = true);
      return;
    }
    try {
      final list = await CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
      if (!mounted) return;
      setState(() {
        _plantChoices = list;
        _plantChoicesLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _plantChoicesLoaded = true);
    }
  }

  Future<void> _onAssistantScopeChanged(String? newKey) async {
    if (_loading || !_showPlantScopeSelector) return;
    final next = (newKey ?? '').trim();
    final normalized = next.isEmpty ? null : next;
    final prior = (_assistantPlantScopeKey ?? '').trim();
    final priorNorm =
        (_assistantPlantScopeKey == null || prior.isEmpty) ? null : prior;
    if (normalized == priorNorm) return;

    final keyForLoad =
        (normalized == null || normalized.isEmpty)
        ? '__company_wide__'
        : normalized;

    setState(() {
      _assistantPlantScopeKey = normalized;
      _turns.clear();
      _restored = false;
    });

    final list = await ProductionAiChatPersistence.load(
      _companyId,
      keyForLoad,
    );
    if (!mounted) return;
    setState(() {
      _turns
        ..clear()
        ..addAll(list);
      _restored = true;
    });
    _scrollToEnd();
  }

  Future<void> _resyncFromCloud() async {
    if (_loading) return;
    if (!_canUseChatPersistence) return;
    final list = await ProductionAiChatPersistence.reloadFromCloud(
      _companyId,
      _threadStorageKey,
    );
    if (!mounted) return;
    setState(() {
      _turns
        ..clear()
        ..addAll(list);
    });
    _scrollToEnd();
  }

  Future<void> _restore() async {
    if (_companyId.isEmpty || !_canUseChatPersistence) {
      if (mounted) setState(() => _restored = true);
      return;
    }
    if (widget.startFreshThread) {
      await ProductionAiChatPersistence.clear(_companyId, _threadStorageKey);
    }
    final list = await ProductionAiChatPersistence.load(
      _companyId,
      _threadStorageKey,
    );
    if (!mounted) return;
    setState(() {
      _turns
        ..clear()
        ..addAll(list);
      _restored = true;
    });
    final seed = widget.initialPrompt?.trim();
    if (seed != null && seed.isNotEmpty && _turns.isEmpty) {
      _prompt.text = seed;
    }
    _scrollToEnd();
    if (widget.autoSendInitialPrompt &&
        _prompt.text.trim().isNotEmpty &&
        _turns.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_ask());
        }
      });
    }
  }

  void _schedulePersist() {
    if (!_canUseChatPersistence) return;
    unawaited(
      ProductionAiChatPersistence.save(
        _companyId,
        _threadStorageKey,
        List.of(_turns),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clearThread() async {
    if (_loading) return;
    setState(_turns.clear);
    if (_canUseChatPersistence) {
      await ProductionAiChatPersistence.clear(_companyId, _threadStorageKey);
    }
  }

  Future<void> _ask() async {
    final q = _prompt.text.trim();
    if (q.isEmpty || _loading || !_restored) return;

    if (!_canUseChatPersistence) {
      setState(() {
        _turns.add(
          const ProductionAiChatMessage.error(
            'Nedostaje podatak o kompaniji ili pogonu. Obrati se administratoru.',
          ),
        );
      });
      _schedulePersist();
      _scrollToEnd();
      return;
    }

    final pkCall = _plantKeyForCallable;
    if (!_isCompanyWideContextUser && (pkCall == null || pkCall.isEmpty)) {
      setState(() {
        _turns.add(
          const ProductionAiChatMessage.error(
            'Nedostaje podatak o pogonu. Obrati se administratoru.',
          ),
        );
      });
      _schedulePersist();
      _scrollToEnd();
      return;
    }
    if (_orvFocus && (pkCall == null || pkCall.isEmpty)) {
      setState(() {
        _turns.add(
          const ProductionAiChatMessage.error(
            'Za ocjenu radnika potreban je pogon u kontekstu sesije (plantKey).',
          ),
        );
      });
      _schedulePersist();
      _scrollToEnd();
      return;
    }

    setState(() {
      _turns.add(ProductionAiChatMessage.user(q));
      if (_turns.length > 40) {
        _turns.removeRange(0, _turns.length - 40);
      }
      _loading = true;
    });
    _schedulePersist();
    _prompt.clear();
    _scrollToEnd();

    try {
      final text = await _svc.ask(
        companyId: _companyId,
        plantKey: pkCall,
        prompt: q,
        evaluationEmployeeDocId: widget.evaluationEmployeeDocId,
        evaluationPeriodYyyyMm: widget.evaluationPeriodYyyyMm,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(ProductionAiChatMessage.assistant(text));
        if (_turns.length > 40) {
          _turns.removeRange(0, _turns.length - 40);
        }
        _loading = false;
      });
      _schedulePersist();
      _scrollToEnd();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.add(
          ProductionAiChatMessage.error(firebaseCallableUserMessage(e)),
        );
        _loading = false;
      });
      _schedulePersist();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.add(ProductionAiChatMessage.error(e.toString()));
        _loading = false;
      });
      _schedulePersist();
      _scrollToEnd();
    }
  }

  MarkdownStyleSheet _md(ThemeData theme) {
    final base = theme.textTheme.bodyMedium?.copyWith(height: 1.38);
    return MarkdownStyleSheet(
      p: base,
      strong: base?.copyWith(fontWeight: FontWeight.w700),
      h1: base?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      h2: base?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      h3: base?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      code: base?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ProductionAiChatMessage m,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    final maxW = MediaQuery.sizeOf(context).width * 0.88;
    Widget bubble;
    if (m.isUser) {
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(
          m.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
      );
    } else if (m.isError) {
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
        ),
        child: SelectableText(
          m.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onErrorContainer,
          ),
        ),
      );
    } else {
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: MarkdownBody(
          data: m.text,
          selectable: true,
          styleSheet: _md(theme),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: bubble,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    Widget inputBar() {
      return Material(
        color: scheme.surface,
        elevation: 8,
        shadowColor: Colors.black26,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _prompt,
                  enabled: !_loading && _restored,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Pitanje',
                    hintText: 'Npr. Koji je omjer škarta ovaj tjedan?',
                    alignLabelWithHint: true,
                  ),
                  onSubmitted: (_) => _ask(),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: (_loading || !_restored) ? null : _ask,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_outlined),
                  label: Text(_loading ? 'Odgovor…' : 'Pošalji'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(kOperonixAiOperationalAssistantTitle),
        actions: [
          IconButton(
            tooltip: 'Više informacija o kontekstu i dosegu',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAssistantScopeHelp(context),
          ),
          if (_turns.isNotEmpty)
            TextButton(
              onPressed: _loading || !_restored ? null : _clearThread,
              child: const Text('Očisti razgovor'),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardBottom),
        child: !_restored
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_showPlantScopeSelector) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Doseg asistenta',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Više informacije o dosegu',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                icon: Icon(
                                  Icons.info_outline,
                                  color: scheme.onSurfaceVariant,
                                  size: 22,
                                ),
                                onPressed: () =>
                                    _showAssistantScopeHelp(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (!_plantChoicesLoaded)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            )
                          else
                            InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: _dropdownPlantValue,
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Svi pogoni (cijela tvrtka)'),
                                    ),
                                    ..._plantChoices.map(
                                      (e) => DropdownMenuItem<String?>(
                                        value: e.plantKey,
                                        child: Text(e.label),
                                      ),
                                    ),
                                  ],
                                  onChanged: _loading
                                      ? null
                                      : (v) =>
                                            unawaited(_onAssistantScopeChanged(v)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: 1 + _turns.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _buildIntroSection(context, theme, scheme);
                        }
                        if (i <= _turns.length) {
                          return _buildMessageBubble(
                            context,
                            _turns[i - 1],
                            scheme,
                            theme,
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Asistent priprema odgovor…',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  inputBar(),
                ],
              ),
      ),
    );
  }

  String get _assistantScopeHelpMessage {
    if (_orvFocus) {
      return 'Fokus na ocjenu radnika za pogon iz sesije — odgovori koriste ORV i povezane '
          'podatke za taj pogon (plantKey mora biti u kontekstu).';
    }
    if (_showPlantScopeSelector) {
      return 'Kao korisnik s dosegom cijele tvrtke (admin, financije, voditelj kvaliteta / QMS, voditelj projekta, inženjer razvoja, …) '
          'možete birati doseg u padajućem izboru iznad: svi pogoni (cijela tvrtka) ili jedan pogon. '
          'Zadano je cijela tvrtka — sesijski ili spremljeni pogon ne šalje se u pozadinu dok ne odaberete '
          'konkretan pogon. Povijest razgovora je odvojena po dosegu.';
    }
    return 'Kontekst za vaš pogon učitava podatke iz sustava. '
        'Povijest razgovora sinkronizira se u oblaku (isti korisnik i pogon na svim uređajima); '
        'lokalno se drži kopija za offline.';
  }

  void _showAssistantScopeHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informacije'),
        content: SingleChildScrollView(
          child: Text(_assistantScopeHelpMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_turns.isEmpty && !_loading) ...[
          Text(
            'Postavite pitanje ispod. Stariji razgovor učitava se automatski ako je spremljen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
