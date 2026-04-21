import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../ooe_help_texts.dart';
import '../models/machine_state_event.dart';
import '../services/machine_state_service.dart';
import '../services/ooe_loss_reason_service.dart';
import '../widgets/ooe_info_icon.dart';
import '../widgets/ooe_loss_pareto_card.dart';

/// Analiza gubitaka — jednostavan Pareto razloga u recentnim segmentima.
class OoeLossAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const OoeLossAnalysisScreen({super.key, required this.companyData});

  @override
  State<OoeLossAnalysisScreen> createState() => _OoeLossAnalysisScreenState();
}

class _OoeLossAnalysisScreenState extends State<OoeLossAnalysisScreen> {
  final _machineCtrl = TextEditingController();
  final _reasonSvc = OoeLossReasonService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  Stream<Map<String, String>> get _ooeReasonLabelStream => _reasonSvc
      .watchAllReasonsForPlant(companyId: _companyId, plantKey: _plantKey)
      .map((list) => {for (final r in list) r.code: r.name});

  @override
  void dispose() {
    _machineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = MachineStateService();
    final mid = _machineCtrl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiza gubitaka'),
        actions: [
          OoeInfoIcon(
            tooltip: OoeHelpTexts.lossAnalysisTooltip,
            dialogTitle: OoeHelpTexts.lossAnalysisTitle,
            dialogBody: OoeHelpTexts.lossAnalysisBody,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  TextField(
                    controller: _machineCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Šifra stroja',
                      helperText:
                          'Ista šifra kao na OOE live kartici i u imovini pogona.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          if (mid.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _LossAnalysisEmpty(
                icon: Icons.bar_chart_outlined,
                title: 'Odaberi stroj',
                subtitle:
                    'Upiši šifru da se iz zadnjih segmenata stanja izgradi Pareto.',
              ),
            )
          else
            SliverFillRemaining(
              child: StreamBuilder<Map<String, String>>(
                stream: _ooeReasonLabelStream,
                builder: (context, reasonSnap) {
                  final ooeReasonLabels =
                      reasonSnap.hasData ? reasonSnap.data : null;
                  return StreamBuilder(
                    stream: svc.watchEventsForMachine(
                      companyId: _companyId,
                      plantKey: _plantKey,
                      machineId: mid,
                      limit: 200,
                    ),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              AppErrorMapper.toMessage(snap.error!),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final agg = <String, int>{};
                      for (final e in snap.data!) {
                        if ((e.durationSeconds ?? 0) <= 0) continue;
                        if (e.state == MachineStateEvent.stateRunning) {
                          continue;
                        }
                        final k = (e.reasonCode ?? e.state).trim();
                        if (k.isEmpty) continue;
                        agg[k] = (agg[k] ?? 0) + (e.durationSeconds ?? 0);
                      }
                      final losses = agg.entries
                          .map(
                            (e) => {
                              'reasonKey': e.key,
                              'seconds': e.value,
                            },
                          )
                          .toList()
                        ..sort(
                          (a, b) => (b['seconds'] as int).compareTo(
                            a['seconds'] as int,
                          ),
                        );
                      if (losses.isEmpty) {
                        return const _LossAnalysisEmpty(
                          icon: Icons.check_circle_outline,
                          title: 'Nema gubitaka u uzorku',
                          subtitle:
                              'U zadnjim segmentima nema zastoja s trajanjem ili su svi u radu.',
                        );
                      }
                      return ListView(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        children: [
                          OoeLossParetoCard(
                            losses: losses.take(12).toList(),
                            reasonLabels: ooeReasonLabels,
                            titleTrailing: OoeInfoIcon(
                              tooltip: OoeHelpTexts.paretoTooltip,
                              dialogTitle: OoeHelpTexts.paretoTitle,
                              dialogBody: OoeHelpTexts.paretoBody,
                              iconSize: 18,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LossAnalysisEmpty extends StatelessWidget {
  const _LossAnalysisEmpty({
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
