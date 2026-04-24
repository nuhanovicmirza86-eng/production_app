import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../models/ooe_shift_summary.dart';
import '../ooe_help_texts.dart';
import '../services/ooe_loss_reason_service.dart';
import '../services/ooe_summary_service.dart';
import '../widgets/ooe_info_icon.dart';
import '../widgets/ooe_loss_pareto_card.dart';

enum _DailyScope { oneMachine, wholePlant }

/// Sažeci za jedan kalendarski dan — jedan stroj ili cijeli pogon (`shiftDate` kao na serveru).
class OoeDailyOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// Početni dan (npr. iz analitike zastoja — isti vremenski rez).
  final DateTime? initialDay;

  const OoeDailyOverviewScreen({
    super.key,
    required this.companyData,
    this.initialDay,
  });

  @override
  State<OoeDailyOverviewScreen> createState() => _OoeDailyOverviewScreenState();
}

class _OoeDailyOverviewScreenState extends State<OoeDailyOverviewScreen> {
  final _machineCtrl = TextEditingController();
  final _summary = OoeSummaryService();
  final _reasonSvc = OoeLossReasonService();
  late DateTime _day;
  late final Future<ProductionPlantAssetsSnapshot> _assetsFuture;
  _DailyScope _scope = _DailyScope.oneMachine;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  Stream<Map<String, String>> get _ooeReasonLabelStream =>
      _reasonSvc
          .watchAllReasonsForPlant(companyId: _companyId, plantKey: _plantKey)
          .map(
            (list) => {for (final r in list) r.code: r.name},
          );

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final init = widget.initialDay;
    if (init != null) {
      _day = DateTime(init.year, init.month, init.day);
    } else {
      _day = DateTime(n.year, n.month, n.day);
    }
    _assetsFuture = ProductionTrackingAssetsService().loadForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
      limit: 128,
    );
  }

  @override
  void dispose() {
    _machineCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 2),
      lastDate: DateTime(_day.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    }
  }

  static String _formatDay(DateTime d) {
    final l = d.toLocal();
    return '${l.day}.${l.month}.${l.year}.';
  }

  static String? _weightedOoePct(List<OoeShiftSummary> list) {
    var totalOp = 0;
    double sum = 0;
    for (final s in list) {
      final op = s.operatingTimeSeconds;
      if (op <= 0) continue;
      totalOp += op;
      sum += s.ooe * op;
    }
    if (totalOp <= 0) return null;
    return (sum / totalOp * 100).toStringAsFixed(1);
  }

  static String _shiftTitle(OoeShiftSummary s) {
    final sid = (s.shiftId ?? '').trim();
    return sid.isEmpty ? 'Smjena' : sid;
  }

  static List<MapEntry<String, List<OoeShiftSummary>>> _groupByMachine(
    List<OoeShiftSummary> list,
  ) {
    final map = <String, List<OoeShiftSummary>>{};
    for (final s in list) {
      map.putIfAbsent(s.machineId, () => []).add(s);
    }
    for (final v in map.values) {
      v.sort(
        (a, b) => (a.shiftId ?? '').toLowerCase().compareTo(
              (b.shiftId ?? '').toLowerCase(),
            ),
      );
    }
    final keys = map.keys.toList()..sort();
    return [for (final k in keys) MapEntry(k, map[k]!)];
  }

  static Widget _shiftExpansionCard(
    OoeShiftSummary s,
    Map<String, String>? ooeReasonLabels,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ExpansionTile(
          leading: const Icon(Icons.schedule),
          title: Text(_shiftTitle(s)),
          subtitle: Text(
            'OOE ${(s.ooe * 100).toStringAsFixed(1)} % · '
            'A ${(s.availability * 100).toStringAsFixed(0)} % · '
            'P ${(s.performance * 100).toStringAsFixed(0)} % · '
            'Q ${(s.quality * 100).toStringAsFixed(0)} %',
          ),
          children: [
            ListTile(
              dense: true,
              title: const Text('Operativno / rad / stop (s)'),
              subtitle: Text(
                '${s.operatingTimeSeconds} · ${s.runTimeSeconds} · ${s.stopTimeSeconds}',
              ),
            ),
            ListTile(
              dense: true,
              title: const Text('Good / scrap'),
              subtitle: Text(
                '${s.goodCount.toStringAsFixed(0)} · ${s.scrapCount.toStringAsFixed(0)}',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: OoeLossParetoCard(
                losses: s.topLosses,
                reasonLabels: ooeReasonLabels,
                titleTrailing: OoeInfoIcon(
                  tooltip: OoeHelpTexts.paretoTooltip,
                  dialogTitle: OoeHelpTexts.paretoTitle,
                  dialogBody: OoeHelpTexts.paretoBody,
                  iconSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResultBody(
    BuildContext context,
    List<OoeShiftSummary> list,
    Map<String, String> machineTitles,
    Map<String, String>? ooeReasonLabels,
  ) {
    if (list.isEmpty) {
      return [
        _EmptyHint(
          icon: Icons.event_busy_outlined,
          title: 'Nema zapisa za taj dan',
          subtitle: _scope == _DailyScope.wholePlant
              ? 'Na ovaj dan nema sažetka u ovom pogonu. Koristi „Sažetak smjene“ i preračun po smjeni.'
              : 'Na ovaj dan nema sažetka za ovaj stroj. Koristi „Sažetak smjene“ i preračun po smjeni.',
        ),
      ];
    }

    final out = <Widget>[];

    if (_scope == _DailyScope.wholePlant) {
      final plantWide = _weightedOoePct(list);
      if (plantWide != null && list.length > 1) {
        out.add(
          Card(
            child: ListTile(
              title: const Text(
                'Ponderirani OOE (cijeli pogon)',
              ),
              subtitle: Text('$plantWide %'),
            ),
          ),
        );
        out.add(const SizedBox(height: 8));
      }

      final grouped = _groupByMachine(list);
      for (final e in grouped) {
        final mid = e.key;
        final rows = e.value;
        final disp = machineTitles[mid];
        final heading = (disp != null && disp.isNotEmpty) ? disp : mid;

        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              heading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );

        final wMach = _weightedOoePct(rows);
        if (wMach != null && rows.length > 1) {
          out.add(
            Card(
              child: ListTile(
                title: const Text('Ponderirani OOE (ovaj stroj)'),
                subtitle: Text('$wMach %'),
              ),
            ),
          );
          out.add(const SizedBox(height: 6));
        }

        for (final s in rows) {
          out.add(_shiftExpansionCard(s, ooeReasonLabels));
        }
      }
    } else {
      final mid = _machineCtrl.text.trim();
      final disp = machineTitles[mid];
      if (disp != null && disp.isNotEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              disp,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      }

      final weighted = _weightedOoePct(list);
      if (weighted != null && list.length > 1) {
        out.add(
          Card(
            child: ListTile(
              title: const Text(
                'Ponderirani OOE (po operativnom vremenu)',
              ),
              subtitle: Text('$weighted %'),
            ),
          ),
        );
        out.add(const SizedBox(height: 8));
      }

      for (final s in list) {
        out.add(_shiftExpansionCard(s, ooeReasonLabels));
      }
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final mid = _machineCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dnevni pregled OOE'),
        actions: [
          OoeInfoIcon(
            tooltip: OoeHelpTexts.dailyOverviewTooltip,
            dialogTitle: OoeHelpTexts.dailyOverviewTitle,
            dialogBody: OoeHelpTexts.dailyOverviewBody,
          ),
        ],
      ),
      body: FutureBuilder<ProductionPlantAssetsSnapshot>(
        future: _assetsFuture,
        builder: (context, assetSnap) {
          if (assetSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppErrorMapper.toMessage(assetSnap.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!assetSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final labelMap = <String, String>{};
          for (final m in assetSnap.data!.machines) {
            labelMap[m.id] = m.title;
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CompanyPlantLabelText(
                        companyId: _companyId,
                        plantKey: _plantKey,
                        prefix: '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<_DailyScope>(
                        segments: const [
                          ButtonSegment(
                            value: _DailyScope.oneMachine,
                            label: Text('Jedan stroj'),
                            icon: Icon(Icons.precision_manufacturing_outlined),
                          ),
                          ButtonSegment(
                            value: _DailyScope.wholePlant,
                            label: Text('Sav pogon'),
                            icon: Icon(Icons.factory_outlined),
                          ),
                        ],
                        selected: {_scope},
                        onSelectionChanged: (s) {
                          setState(() {
                            _scope = s.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_scope == _DailyScope.oneMachine) ...[
                        TextField(
                          controller: _machineCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Šifra stroja',
                            helperText:
                                'Isti stroj kao u izvršenju i u imovini pogona (assets).',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ] else
                        Text(
                          'Prikaz svih mašina za koje postoji sažetak na odabrani dan.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      const SizedBox(height: 12),
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: _pickDay,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Dan',
                              suffixIcon: Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                            ),
                            child: Text(_formatDay(_day)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_scope == _DailyScope.oneMachine && mid.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHint(
                    icon: Icons.precision_manufacturing_outlined,
                    title: 'Odaberi stroj',
                    subtitle:
                        'Upiši šifru stroja ili prebaci na „Sav pogon“ za cijeli pogon.',
                  ),
                )
              else
                SliverFillRemaining(
                  child: StreamBuilder<Map<String, String>>(
                    stream: _ooeReasonLabelStream,
                    builder: (context, reasonSnap) {
                      final ooeReasonLabels =
                          reasonSnap.hasData ? reasonSnap.data : null;
                      return StreamBuilder<List<OoeShiftSummary>>(
                        stream: _scope == _DailyScope.wholePlant
                            ? _summary.watchSummariesForPlantOnCalendarDay(
                                companyId: _companyId,
                                plantKey: _plantKey,
                                calendarDay: _day,
                              )
                            : _summary.watchSummariesForMachineOnCalendarDay(
                                companyId: _companyId,
                                plantKey: _plantKey,
                                machineId: mid,
                                calendarDay: _day,
                              ),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  AppErrorMapper.toMessage(snap.error!),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final list = snap.data ?? const [];
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            children: _buildResultBody(
                              context,
                              list,
                              labelMap,
                              ooeReasonLabels,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
