import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_absence_types.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_annual_leave_display.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// Odsustva po radniku (sve uobičajene vrste) + saldo godišnjeg.
class WorkTimeWorkerAbsencesScreen extends StatefulWidget {
  const WorkTimeWorkerAbsencesScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeWorkerAbsencesScreen> createState() =>
      _WorkTimeWorkerAbsencesScreenState();
}

class _DemoWorker {
  const _DemoWorker({
    required this.id,
    required this.name,
    required this.balance,
  });

  final String id;
  final String name;
  final WorkTimeAnnualBalanceView balance;
}

class _WorkTimeWorkerAbsencesScreenState
    extends State<WorkTimeWorkerAbsencesScreen> {
  static const List<_DemoWorker> _workers = <_DemoWorker>[
    _DemoWorker(
      id: 'e1',
      name: 'Ivan K.',
      balance: WorkTimeAnnualBalanceView(
        carriedOverFromLastYear: 2,
        entitledThisYear: 20,
        scheduledThisYear: 5,
        takenThisYear: 8,
      ),
    ),
    _DemoWorker(
      id: 'e2',
      name: 'Ana S.',
      balance: WorkTimeAnnualBalanceView(
        carriedOverFromLastYear: 0,
        entitledThisYear: 20,
        scheduledThisYear: 10,
        takenThisYear: 4,
      ),
    ),
  ];

  final List<WorkTimeAbsenceEntry> _entries = <WorkTimeAbsenceEntry>[
    WorkTimeAbsenceEntry(
      id: 'a1',
      employeeId: 'e1',
      employeeName: 'Ivan K.',
      type: WorkTimeAbsenceType.sickLeave,
      start: DateTime(2026, 1, 10),
      end: DateTime(2026, 1, 12),
      note: 'L4',
    ),
  ];

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _tryParseDate(String raw) {
    return DateTime.tryParse(raw.trim());
  }

  Future<void> _openAddDialog(_DemoWorker w) async {
    WorkTimeAbsenceType type = WorkTimeAbsenceType.annualLeave;
    final startC = TextEditingController(text: _fmtDate(DateTime.now()));
    final endC = TextEditingController(
      text: _fmtDate(
        DateTime.now().add(const Duration(days: 1)),
      ),
    );
    final noteC = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setS) {
            return AlertDialog(
              title: Text('Novo odsustvo: ${w.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Vrsta',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<WorkTimeAbsenceType>(
                          value: type,
                          isExpanded: true,
                          items: WorkTimeAbsenceType.values
                              .map(
                                (x) => DropdownMenuItem<WorkTimeAbsenceType>(
                                  value: x,
                                  child: Text(x.labelHr),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) {
                              return;
                            }
                            setS(() => type = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: startC,
                      decoration: const InputDecoration(
                        labelText: 'Prvi dan (npr. 2026-04-10)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endC,
                      decoration: const InputDecoration(
                        labelText: 'Zadnji dan odsutnosti (uključivo)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteC,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Napomena (opcijalno)',
                        border: OutlineInputBorder(),
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
                  child: const Text('Dodaj'),
                ),
              ],
            );
          },
        );
      },
    );

    final startText = startC.text;
    final endText = endC.text;
    final note = noteC.text.trim();
    startC.dispose();
    endC.dispose();
    noteC.dispose();

    if (result != true || !mounted) {
      return;
    }

    final s = _tryParseDate(startText) ?? DateTime.now();
    var e = _tryParseDate(endText) ?? s;
    if (e.isBefore(s)) {
      e = s;
    }

    setState(() {
      _entries.insert(
        0,
        WorkTimeAbsenceEntry(
          id: 'a${DateTime.now().microsecondsSinceEpoch}',
          employeeId: w.id,
          employeeName: w.name,
          type: type,
          start: s,
          end: e,
          note: note,
        ),
      );
    });
  }

  Widget _balanceCard(WorkTimeAnnualBalanceView b, ThemeData t) {
    return Card(
      color: t.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Godišnji odmor', style: t.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              'Prijenos s prošle: ${b.carriedOverFromLastYear} d · pravo ove: ${b.entitledThisYear} d',
            ),
            Text(
              'U planu: ${b.scheduledThisYear} d · iskorišteno: ${b.takenThisYear} d',
            ),
            const Divider(height: 16),
            Text(
              'Preostalo: ${b.remainingThisYear.toStringAsFixed(1)} d (uključ. prijenos + tekuća)',
              style: t.textTheme.titleSmall?.copyWith(
                color: t.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Odsustva po radniku'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          Text(
            'Za svakog radnika mogu se evidentirati sve vrste odsustva. Godišnji odmor '
            'pokazuje prijenos s prošle i tekuće godine, plan i iskorištenje; točno '
            'stjecanje prava slijedi pravilima tvrtke i ZOR-u (vidi i Pravila obračuna).',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ..._workers.map((w) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(w.name, style: t.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _balanceCard(w.balance, t),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => unawaited(_openAddDialog(w)),
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj odsustvo'),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('Pregled unosa', style: t.textTheme.titleSmall),
          const SizedBox(height: 6),
          if (_entries.isEmpty)
            const Text('Nema unosa.')
          else
            ..._entries.map((e) {
              return ListTile(
                title: Text('${e.employeeName} — ${e.type.labelHr}'),
                subtitle: Text(
                  '${_fmtDate(e.start)}–${_fmtDate(e.end)} · ~${e.workingDaysApprox} d${e.note.isNotEmpty ? ' · ${e.note}' : ''}',
                ),
              );
            }),
          const SizedBox(height: 12),
          Text(
            kCroatiaAnnualLeaveLawSummaryHr,
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
