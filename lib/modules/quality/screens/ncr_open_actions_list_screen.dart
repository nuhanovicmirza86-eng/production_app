import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../models/ncr_open_action_task.dart';
import '../services/quality_callable_service.dart';
import '../utils/ncr_open_action_navigation.dart';

/// M1-I12-D — jedinstveni inbox otvorenih NCR akcija po ulozi.
class NcrOpenActionsListScreen extends StatefulWidget {
  const NcrOpenActionsListScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<NcrOpenActionsListScreen> createState() =>
      _NcrOpenActionsListScreenState();
}

class _NcrOpenActionsListScreenState extends State<NcrOpenActionsListScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  List<NcrOpenActionTask> _tasks = const [];

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _svc.listMyNcrOpenActionTasks(companyId: _cid);
      final raw = res['tasks'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => NcrOpenActionTask.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .where((t) => t.ncrId.isNotEmpty && t.canAct)
              .toList(growable: false)
          : const <NcrOpenActionTask>[];
      if (!mounted) return;
      setState(() {
        _tasks = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  String _formatDue(String? dueAt) {
    final raw = (dueAt ?? '').trim();
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.$y. $h:$min';
  }

  Future<void> _openTask(NcrOpenActionTask task) async {
    final closed = await openNcrOpenActionTask(
      context,
      companyData: widget.companyData,
      task: task,
    );
    if (closed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neusaglašenost je uspješno zatvorena.'),
        ),
      );
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final role = ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    if (!ProductionAccessHelper.canAccessNcrOpenActionsInbox(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moje otvorene akcije')),
        body: const Center(
          child: Text('Nemaš pristup otvorenim akcijama.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje otvorene akcije'),
        actions: [
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
              : _tasks.isEmpty
                  ? Center(
                      child: Text(
                        'Trenutno nemaš otvorenih akcija.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            title: Text(task.displayNcrCode),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.statusLabelBs),
                                if (task.displayProduct != '—')
                                  Text(task.displayProduct),
                                Text('Rok: ${_formatDue(task.dueAt)}'),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  task.actionLabelBs,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  textAlign: TextAlign.end,
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => _openTask(task),
                          ),
                        );
                      },
                    ),
    );
  }
}
