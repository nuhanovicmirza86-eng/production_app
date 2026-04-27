import 'dart:async' show unawaited;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_operational_service.dart';

/// Tablica sirovih događaja in/out s poslužitelja + unos s terminala.
class WorkTimeEventPanel extends StatefulWidget {
  const WorkTimeEventPanel({
    super.key,
    required this.companyData,
    required this.employeeDocId,
    required this.year,
    required this.month,
    this.onEventsChanged,
  });

  final Map<String, dynamic> companyData;
  final String? employeeDocId;
  final int year;
  final int month;
  final VoidCallback? onEventsChanged;

  @override
  State<WorkTimeEventPanel> createState() => _WorkTimeEventPanelState();
}

class _WorkTimeEventPanelState extends State<WorkTimeEventPanel> {
  final _svc = WorkTimeOperationalService();
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _err;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void didUpdateWidget(WorkTimeEventPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.employeeDocId != widget.employeeDocId) {
      unawaited(_load());
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_cid.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final l = await _svc.listEvents(
        companyId: _cid,
        plantKey: _pk,
        year: widget.year,
        month: widget.month,
      );
      if (mounted) {
        setState(() {
          _all = l;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _forEmployee {
    final e = widget.employeeDocId;
    if (e == null || e.isEmpty) {
      return const [];
    }
    return _all.where((x) => x['employeeDocId'] == e).toList();
  }

  Future<void> _record(String kind) async {
    final emp = widget.employeeDocId;
    if (emp == null || emp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi radnika u lijevom stupcu.')),
      );
      return;
    }
    final now = DateTime.now();
    final iso = now.toIso8601String();
    try {
      await _svc.recordEvent(
        companyId: _cid,
        plantKey: _pk,
        employeeDocId: emp,
        eventKind: kind,
        occurredAtIso: iso,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kind == 'in' ? 'Ulaz zabilježen. Preračunaj dnevne nakon niza unosa.' : 'Izlaz zabilježen.',
            ),
          ),
        );
        await _load();
        widget.onEventsChanged?.call();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.code)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_err != null) {
      return Text(_err!, style: TextStyle(color: theme.colorScheme.error));
    }
    final loc = Localizations.localeOf(context).toString();
    final rows = _forEmployee;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Prijave s uređaja / unos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: () => unawaited(_record('in')),
                  child: const Text('Zabilježi ulaz'),
                ),
                FilledButton.tonal(
                  onPressed: () => unawaited(_record('out')),
                  child: const Text('Zabilježi izlaz'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Osvježi s poslužitelja',
                  onPressed: () => unawaited(_load()),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('Vrijeme')),
                  DataColumn(label: Text('Vrsta')),
                ],
                rows: [
                  for (final e in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _fmtMs(
                              (e['occurredAtMs'] as num?)?.toInt() ?? 0,
                              loc,
                            ),
                          ),
                        ),
                        DataCell(Text(_kindHr(e['eventKind']?.toString() ?? ''))),
                      ],
                    ),
                ],
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nema unosa za odabranog radnika u ovom mjesecu.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _kindHr(String k) {
    switch (k) {
      case 'in':
        return 'Ulaz';
      case 'out':
        return 'Izlaz';
      default:
        return k;
    }
  }

  String _fmtMs(int ms, String loc) {
    if (ms <= 0) {
      return '—';
    }
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat.yMMMd(loc).add_Hm().format(d);
  }
}
