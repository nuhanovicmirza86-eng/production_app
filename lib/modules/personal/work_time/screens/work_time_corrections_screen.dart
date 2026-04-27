import 'dart:async' show unawaited;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_access.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_operational_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_period_bar.dart';

/// Korekcije — [work_time_corrections] + IATF audit.
class WorkTimeCorrectionsScreen extends StatefulWidget {
  const WorkTimeCorrectionsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeCorrectionsScreen> createState() =>
      _WorkTimeCorrectionsScreenState();
}

class _WorkTimeCorrectionsScreenState extends State<WorkTimeCorrectionsScreen> {
  final _ops = WorkTimeOperationalService();
  int _y = DateTime.now().year;
  int _m = DateTime.now().month;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _admin => WorkTimeAccess.canOpenTenantAdminScreens(
        ProductionAccessHelper.normalizeRole(widget.companyData['role']),
      );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final l = await _ops.listCorrections(
        companyId: _cid,
        plantKey: _pk,
        year: _y,
        month: _m,
      );
      if (mounted) {
        setState(() {
          _rows = l;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _add() async {
    final emp = TextEditingController();
    final date = TextEditingController();
    final reason = TextEditingController();
    final hours = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zahtjev za korekciju'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emp,
                decoration: const InputDecoration(
                  labelText: 'ID radnika (workforce) *',
                ),
              ),
              TextField(
                controller: date,
                decoration: const InputDecoration(
                  labelText: 'Dan (YYYY-MM-DD) *',
                ),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Razlog *'),
                maxLines: 2,
              ),
              TextField(
                controller: hours,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Nadomjesni broj sati (opcionalno, nakon odobrenja)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pošalji'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    if (emp.text.isEmpty || date.text.isEmpty || reason.text.isEmpty) {
      return;
    }
    double? ow;
    if (hours.text.trim().isNotEmpty) {
      ow = double.tryParse(hours.text.trim().replaceAll(',', '.'));
    }
    try {
      await _ops.createCorrection(
        companyId: _cid,
        plantKey: _pk,
        employeeDocId: emp.text.trim(),
        dateKeyYyyyMmDd: date.text.trim(),
        reason: reason.text.trim(),
        overrideWorkedHours: ow,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zahtjev poslan. Admin odobrava; zatim preračunaj dnevne.')),
        );
        await _load();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.code)),
        );
      }
    }
  }

  Future<void> _resolve(String id, String res) async {
    try {
      await _ops.resolveCorrection(companyId: _cid, correctionId: id, resolution: res);
      if (mounted) {
        await _load();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Korekcije evidencije')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(_add()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const WorkTimeDemoBanner(),
                WorkTimePeriodBar(
                  year: _y,
                  month: _m,
                  onChanged: (y, m) {
                    setState(() {
                      _y = y;
                      _m = m;
                    });
                    unawaited(_load());
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Odobrenje i ručna nadomjestanja sati idu u audit. '
                  'Nakon odobrenja, pokreni preračun dnevnih (mjesečni ekran).',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                for (final r in _rows)
                  Card(
                    child: ListTile(
                      title: Text('${r['dateKey']} — ${r['status'] ?? ''}'),
                      subtitle: Text(
                        (r['reason'] ?? '').toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: (r['status'] == 'pending' && _admin)
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => unawaited(_resolve(r['id']?.toString() ?? '', 'approved')),
                                  child: const Text('Odobri'),
                                ),
                                TextButton(
                                  onPressed: () => unawaited(_resolve(r['id']?.toString() ?? '', 'rejected')),
                                  child: const Text('Odbij'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            ),
    );
  }
}
