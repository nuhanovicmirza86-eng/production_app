import 'package:flutter/material.dart';

import '../../tracking/services/production_asset_display_lookup.dart';
import '../models/planning_delivery_risk.dart';
import '../models/planning_engine_result.dart';
import '../planning_ui_formatters.dart';

/// Sažetak KPI iz rezultata motora — kompaktna traka (gornji red) + opcijski cijeli kartični prikaz.
class PlanningKpiStrip extends StatefulWidget {
  const PlanningKpiStrip({
    super.key,
    required this.r,
    required this.companyId,
    required this.plantKey,
    this.deliveryRisk,
    this.compact = true,
  });

  final PlanningEngineResult r;
  final String companyId;
  final String plantKey;
  final PlanningDeliveryRisk? deliveryRisk;
  final bool compact;

  @override
  State<PlanningKpiStrip> createState() => _PlanningKpiStripState();
}

class _PlanningKpiStripState extends State<PlanningKpiStrip> {
  String? _bottleneckLabel;

  @override
  void initState() {
    super.initState();
    _loadBottleneck();
  }

  @override
  void didUpdateWidget(covariant PlanningKpiStrip old) {
    super.didUpdateWidget(old);
    if (widget.r.kpi?.bottleneckMachineId != old.r.kpi?.bottleneckMachineId) {
      _loadBottleneck();
    }
  }

  Future<void> _loadBottleneck() async {
    final id = widget.r.kpi?.bottleneckMachineId;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _bottleneckLabel = null);
      return;
    }
    final cid = widget.companyId.trim();
    final pk = widget.plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      if (mounted) setState(() => _bottleneckLabel = null);
      return;
    }
    final look = await ProductionAssetDisplayLookup.loadForPlant(
      companyId: cid,
      plantKey: pk,
      limit: 500,
    );
    if (!mounted) return;
    setState(() => _bottleneckLabel = look.resolve(id));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactBar(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildCompactBar(BuildContext context) {
    final r = widget.r;
    final k = r.kpi;
    final p = r.plan;
    final t = Theme.of(context);
    final s = t.textTheme.labelMedium;
    String chip(String a, [String? b]) {
      return b == null || b.isEmpty ? a : '$a: $b';
    }

    final items = <String>[
      p.planCode,
      PlanningUiFormatters.engineStrategy(p.strategy),
      if (k != null) chip('Mogući', '${k.feasibleOrders}/${k.totalPlannedOrders}'),
      if (k != null) chip('Nemogući', '${k.infeasibleOrders}'),
      if (k?.onTimeRate01 != null)
        'U roku ${(k!.onTimeRate01! * 100).toStringAsFixed(0)}%',
      if (k != null && k.totalLatenessMinutes > 0) 'Kašnjenje ${k.totalLatenessMinutes} min',
      if (k != null && (k.bottleneckMachineId ?? '').isNotEmpty)
        'Bottleneck ${_bottleneckLabel ?? "…"}',
      if (p.estimatedUtilization01 != null)
        'Iskor. ${(p.estimatedUtilization01! * 100).toStringAsFixed(0)}%',
      'Operacija ${r.scheduledOperations.length} · upoz. ${r.conflicts.length}',
    ];

    return Material(
      color: t.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.deliveryRisk != null) _deliveryRiskBar(context, widget.deliveryRisk!),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Text('  ·  ', style: TextStyle(color: Colors.black38)),
                  Text(items[i], style: s),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryRiskBar(BuildContext context, PlanningDeliveryRisk d) {
    final t = Theme.of(context);
    final c = d.risk01;
    final fg = c < 0.25
        ? t.colorScheme.onPrimaryContainer
        : c < 0.55
            ? t.colorScheme.onTertiaryContainer
            : t.colorScheme.onErrorContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          Text('Rizik isporuke (F4):', style: t.textTheme.labelSmall?.copyWith(color: fg)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.clamp(0, 1),
                minHeight: 6,
                color: t.colorScheme.error,
                backgroundColor: t.colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(c * 100).toStringAsFixed(0)}% · ${d.labelHr}',
            style: t.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard(BuildContext context) {
    final r = widget.r;
    final k = r.kpi;
    final p = r.plan;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.deliveryRisk != null) ...[
              _deliveryRiskBar(context, widget.deliveryRisk!),
              const SizedBox(height: 8),
            ],
            Text(
              'Rezultat: ${p.planCode}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Strategija: ${PlanningUiFormatters.engineStrategy(p.strategy)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (k != null) ...[
              const SizedBox(height: 6),
              Text('Mogući nalozi: ${k.feasibleOrders} / obuhvaćeno ${k.totalPlannedOrders}'),
              Text('Nemogući: ${k.infeasibleOrders}'),
              if (k.onTimeRate01 != null)
                Text('U roku: ${(k.onTimeRate01! * 100).toStringAsFixed(0)} %'),
              if (k.totalLatenessMinutes > 0)
                Text('Zbir kašnjenja: ${k.totalLatenessMinutes} min'),
              if (k.bottleneckMachineId != null && k.bottleneckMachineId!.isNotEmpty)
                Text('Bottleneck: ${_bottleneckLabel ?? "…"}'),
            ],
            if (p.estimatedUtilization01 != null)
              Text('Gruba iskoristivost: ${(p.estimatedUtilization01! * 100).toStringAsFixed(0)} %'),
            const SizedBox(height: 4),
            Text(
              'Operacija: ${r.scheduledOperations.length} · upozorenja: ${r.conflicts.length}',
            ),
            if (r.conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Upozorenja (prvih 5)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ...r.conflicts.take(5).map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${PlanningUiFormatters.conflictTypeLabel(c.type.name)}: ${c.message}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
