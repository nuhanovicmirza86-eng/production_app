import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/ai/production_ai_context_scope.dart';
import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../services/production_ai_report_service.dart';

/// AI izvještaj za proizvodnju (Callable + Gemini na backendu).
class ProductionAiReportScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionAiReportScreen({super.key, required this.companyData});

  @override
  State<ProductionAiReportScreen> createState() =>
      _ProductionAiReportScreenState();
}

class _ProductionAiReportScreenState extends State<ProductionAiReportScreen> {
  static const int _maxInclusivePeriodDays = 31;

  final _svc = ProductionAiReportService();
  late DateTime _start;
  late DateTime _end;
  bool _loading = false;
  String? _markdown;
  String? _error;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  int _inclusiveCalendarDays() {
    final a = DateTime(_start.year, _start.month, _start.day);
    final b = DateTime(_end.year, _end.month, _end.day);
    return b.difference(a).inDays + 1;
  }

  bool get _periodOrderOk => !_start.isAfter(_end);

  bool get _periodExceedsLimit =>
      _periodOrderOk && _inclusiveCalendarDays() > _maxInclusivePeriodDays;

  bool get _reportAllowedByRbac =>
      ProductionAiContextScope.allowsProductionAiReport(widget.companyData);

  static const String _periodTooLongMessage =
      'Period ne smije biti dulji od 31 dan (uključivo). Skrati raspon datuma.';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _end = DateTime(now.year, now.month, now.day);
    _start = _end.subtract(const Duration(days: 6));
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
    if (_periodExceedsLimit) return;
    if (_error == _periodTooLongMessage ||
        _error == 'Početni datum mora biti prije krajnjeg.') {
      _error = null;
    }
  }

  Future<void> _generate() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() => _error = 'Nedostaje podatak o kompaniji ili pogonu. Obrati se administratoru.');
      return;
    }
    if (!_periodOrderOk) {
      setState(() => _error = 'Početni datum mora biti prije krajnjeg.');
      return;
    }
    if (_periodExceedsLimit) {
      setState(() => _error = _periodTooLongMessage);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _markdown = null;
    });

    try {
      final r = await _svc.generate(
        companyId: _companyId,
        plantKey: _plantKey,
        start: _start,
        end: _end,
      );
      if (!mounted) return;
      setState(() {
        _markdown = r.markdown;
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

    if (!ProductionModuleKeys.hasAiProductionMarkdownReportModule(
      widget.companyData,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI izvještaj')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'AI izvještaji zahtijevaju ai_assistant, ai_assistant_production '
              'ili add-on ai_reports (enabledModules).',
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
      appBar: AppBar(title: const Text('AI izvještaj — proizvodnja')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Odaberi period (najviše 31 dan). Podaci: operativno praćenje '
                  '(workDate) i uzorak proizvodnih naloga (createdAt).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _pickStart,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          'Od: ${_start.year}-${_start.month.toString().padLeft(2, '0')}-${_start.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _pickEnd,
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
                ] else if (_periodExceedsLimit) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Period: ${_inclusiveCalendarDays()} dana — najviše '
                    '$_maxInclusivePeriodDays dan (uključivo).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (!_reportAllowedByRbac) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Nemaš u aplikaciji pristup praćenju ni nalozima u dometu uloge — izvještaj nije dostupan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (_loading ||
                          !_periodOrderOk ||
                          _periodExceedsLimit ||
                          !_reportAllowedByRbac)
                      ? null
                      : _generate,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? 'Generiranje…' : 'Generiraj izvještaj'),
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
          const Divider(height: 1),
          Expanded(
            child: _markdown == null
                ? Center(
                    child: Text(
                      _loading
                          ? ''
                          : 'Odaberi period i generiraj izvještaj.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

/// Prikaz pločice u hubu samo za dozvoljene uloge (usklađeno s backendom).
bool productionAiReportVisibleForRole(dynamic roleRaw) {
  final r = ProductionAccessHelper.normalizeRole(roleRaw);
  return r == 'admin' ||
      r == 'super_admin' ||
      r == 'production_manager' ||
      r == 'supervisor';
}
