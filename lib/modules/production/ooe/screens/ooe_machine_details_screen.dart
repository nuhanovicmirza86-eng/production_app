import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../ooe_help_texts.dart';
import '../models/machine_state_event.dart';
import '../models/ooe_live_status.dart';
import '../services/machine_state_service.dart';
import '../services/ooe_live_service.dart';
import '../widgets/ooe_factor_card.dart';
import '../widgets/ooe_info_icon.dart';
import '../widgets/ooe_kpi_card.dart';
import '../widgets/ooe_timeline_widget.dart';

/// Detalj jedne mašine: KPI iz [ooe_live_status] (isti izvor kao dashboard) + traka segmenata.
class OoeMachineDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String machineId;

  const OoeMachineDetailsScreen({
    super.key,
    required this.companyData,
    required this.machineId,
  });

  @override
  State<OoeMachineDetailsScreen> createState() => _OoeMachineDetailsScreenState();
}

class _OoeMachineDetailsScreenState extends State<OoeMachineDetailsScreen> {
  late final Future<String?> _displayNameFuture;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _displayNameFuture = _loadDisplayName();
  }

  Future<String?> _loadDisplayName() async {
    final snap = await ProductionTrackingAssetsService().loadForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
      limit: 128,
    );
    for (final m in snap.machines) {
      if (m.id == widget.machineId) return m.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final eventsSvc = MachineStateService();
    final liveSvc = OoeLiveService();

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: _displayNameFuture,
          builder: (context, nameSnap) {
            if (nameSnap.connectionState == ConnectionState.waiting) {
              return Text(
                'OOE — stroj',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }
            final name = (nameSnap.data ?? '').trim();
            if (name.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Referenca: ${widget.machineId}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OOE — stroj',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  widget.machineId,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            );
          },
        ),
      ),
      body: StreamBuilder<OoeLiveStatus?>(
        stream: liveSvc.watchLiveStatusForMachine(
          companyId: _companyId,
          plantKey: _plantKey,
          machineId: widget.machineId,
        ),
        builder: (context, liveSnap) {
          return StreamBuilder<List<MachineStateEvent>>(
            stream: eventsSvc.watchEventsForMachine(
              companyId: _companyId,
              plantKey: _plantKey,
              machineId: widget.machineId,
              limit: 80,
            ),
            builder: (context, evSnap) {
              if (evSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppErrorMapper.toMessage(evSnap.error!),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!evSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final events = evSnap.data ?? const <MachineStateEvent>[];
              final livePending =
                  liveSnap.connectionState == ConnectionState.waiting &&
                  !liveSnap.hasData;

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (livePending)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else ...[
                    ..._buildKpiSection(context, liveSnap.data),
                    const SizedBox(height: 8),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Vremenska traka (zadnji segmenti)',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              OoeInfoIcon(
                                tooltip: OoeHelpTexts.timelineTooltip,
                                dialogTitle: OoeHelpTexts.timelineTitle,
                                dialogBody: OoeHelpTexts.timelineBody,
                                iconSize: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OoeTimelineWidget(events: events.take(25).toList()),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// KPI iz Firestore live dokumenta; ako ga još nema — jedan red + info.
  List<Widget> _buildKpiSection(BuildContext context, OoeLiveStatus? live) {
    if (live == null) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Live KPI još nisu u bazi.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                OoeInfoIcon(
                  tooltip: 'Zašto je prazno',
                  dialogTitle: 'Čekanje live snimka',
                  dialogBody:
                      'Agregat (OOE, A, P, Q) dolazi iz dokumenta ooe_live_status '
                      'nakon što izvršenje osvježi podatke za mašinu (isti izvor '
                      'kao kartice na OOE live pregledu).',
                  iconSize: 18,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      OoeKpiCard(
        title: 'OOE',
        valueLabel: '${(live.currentShiftOoe * 100).toStringAsFixed(1)} %',
        titleTrailing: OoeInfoIcon(
          tooltip: OoeHelpTexts.machineDetailsOoeTooltip,
          dialogTitle: OoeHelpTexts.machineDetailsOoeTitle,
          dialogBody: OoeHelpTexts.machineDetailsOoeBody,
          iconSize: 18,
        ),
      ),
      OoeFactorRow(
        availability: live.availability,
        performance: live.performance,
        quality: live.quality,
        headerTrailing: OoeInfoIcon(
          tooltip: OoeHelpTexts.machineDetailsApqTooltip,
          dialogTitle: OoeHelpTexts.machineDetailsApqTitle,
          dialogBody: OoeHelpTexts.machineDetailsApqBody,
          iconSize: 18,
        ),
      ),
    ];
  }
}
