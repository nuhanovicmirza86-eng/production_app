import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_operational_service.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_matrix_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';
import 'package:production_app/modules/workforce/models/workforce_employee.dart';

/// Dodjela radnika managerima — [work_time_manager_assignments] (samo Admin, Callable).
class WorkTimeManagerAssignmentScreen extends StatefulWidget {
  const WorkTimeManagerAssignmentScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeManagerAssignmentScreen> createState() =>
      _WorkTimeManagerAssignmentScreenState();
}

class _WorkTimeManagerAssignmentScreenState
    extends State<WorkTimeManagerAssignmentScreen> {
  final _op = WorkTimeOperationalService();
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _managers = [];
  List<WorkforceEmployee> _employees = [];
  String? _selectedManagerUid;
  Set<String> _selectedEmployeeIds = {};
  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final m = await _op.listOrvAssignmentManagers(companyId: _companyId);
      final a = await _op.listManagerAssignments(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      final emSnap = await FirebaseFirestore.instance
          .collection('workforce_employees')
          .where('companyId', isEqualTo: _companyId)
          .where('plantKey', isEqualTo: _plantKey)
          .orderBy('displayName')
          .limit(500)
          .get();
      final emList = emSnap.docs.map(WorkforceEmployee.fromDoc).toList();
      if (mounted) {
        setState(() {
          _managers = m;
          _employees = emList;
          if (_selectedManagerUid == null && m.isNotEmpty) {
            _selectedManagerUid = m.first['managerUid']?.toString();
            _applyAssignment(a, _selectedManagerUid!);
          }
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

  void _applyAssignment(List<Map<String, dynamic>> assignments, String uid) {
    for (final row in assignments) {
      if ((row['managerUid'] ?? '').toString() == uid) {
        final raw = row['employeeDocIds'];
        if (raw is List) {
          _selectedEmployeeIds = raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
        } else {
          _selectedEmployeeIds = {};
        }
        return;
      }
    }
    _selectedEmployeeIds = {};
  }

  Future<void> _save() async {
    final uid = _selectedManagerUid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _op.setManagerAssignment(
        companyId: _companyId,
        plantKey: _plantKey,
        managerUid: uid,
        employeeDocIds: _selectedEmployeeIds.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodjela spremljena.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dodjela radnika managerima')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dodjela radnika managerima')),
        body: Center(child: Text(_err!)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodjela radnika managerima'),
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Spremi',
              onPressed: _managers.isEmpty ? null : _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          Text(
            'Korisnici s ulogom menadžer (proizvodnja, logistika, održavanje) mogu se ograničiti '
            'na određene zaposlenike u pogonu ${workTimePlantKeyFrom(widget.companyData)}. '
            'Ako nema evidenata dodjele, menadžer vidi sve zaposlenike u pogonu.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_managers.isEmpty)
            Text(
              'Nema korisnika s menadžerskom ulogom u Firestoreu za ovu tvrtku.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Menadžer',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedManagerUid,
                      items: [
                        for (final m in _managers)
                          DropdownMenuItem(
                            value: m['managerUid']?.toString(),
                            child: Text(
                              '${m['displayName'] ?? m['email'] ?? m['managerUid']}'
                              ' (${m['role']})',
                            ),
                          ),
                      ],
                      onChanged: (v) async {
                        if (v == null) {
                          return;
                        }
                        final a = await _op.listManagerAssignments(
                          companyId: _companyId,
                          plantKey: _plantKey,
                        );
                        if (mounted) {
                          setState(() {
                            _selectedManagerUid = v;
                            _applyAssignment(a, v);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Zaposlenici u pogonu (označite koje ovaj menadžer vidi u ORV)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final w in _employees)
                  CheckboxListTile(
                    dense: true,
                    value: _selectedEmployeeIds.contains(w.id),
                    onChanged: (c) {
                      setState(() {
                        if (c == true) {
                          _selectedEmployeeIds = {..._selectedEmployeeIds, w.id};
                        } else {
                          _selectedEmployeeIds = {..._selectedEmployeeIds}..remove(w.id);
                        }
                      });
                    },
                    title: Text(w.displayName),
                    subtitle: Text(w.subtitleLine),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
