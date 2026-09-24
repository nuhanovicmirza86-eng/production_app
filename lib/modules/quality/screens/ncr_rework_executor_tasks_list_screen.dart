import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../models/ncr_rework_executor_task.dart';
import '../services/quality_callable_service.dart';
import 'ncr_rework_executor_task_screen.dart';

/// M1-I12-D — lista aktivnih zadataka dorade za dodijeljenog izvršioca.
class NcrReworkExecutorTasksListScreen extends StatefulWidget {
  const NcrReworkExecutorTasksListScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<NcrReworkExecutorTasksListScreen> createState() =>
      _NcrReworkExecutorTasksListScreenState();
}

class _NcrReworkExecutorTasksListScreenState
    extends State<NcrReworkExecutorTasksListScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  List<NcrReworkExecutorTask> _tasks = const [];

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
      final res = await _svc.listMyNcrReworkExecutorTasks(companyId: _cid);
      final raw = res['tasks'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => NcrReworkExecutorTask.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .where((t) => t.ncrId.isNotEmpty)
              .toList(growable: false)
          : const <NcrReworkExecutorTask>[];
      if (!mounted) return;
      setState(() {
        _tasks = list;
        _loading = false;
      });
      if (list.length == 1 && mounted) {
        await _openTask(list.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _openTask(NcrReworkExecutorTask task) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NcrReworkExecutorTaskScreen(
          companyData: widget.companyData,
          ncrId: task.ncrId,
          initialTask: task,
        ),
      ),
    );
    if (mounted) await _load();
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

  @override
  Widget build(BuildContext context) {
    final role = ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    if (!ProductionAccessHelper.canBeNcrReworkExecutorRole(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moji zadaci dorade')),
        body: const Center(
          child: Text('Nemaš pristup zadacima dorade.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moji zadaci dorade'),
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
                        'Trenutno nemaš dodijeljenih zadataka dorade.',
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
                                Text(task.displayProduct),
                                if ((task.productionOrderCode ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  Text('Nalog: ${task.productionOrderCode}'),
                                Text('Rok: ${_formatDue(task.dueAt)}'),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openTask(task),
                          ),
                        );
                      },
                    ),
    );
  }
}
