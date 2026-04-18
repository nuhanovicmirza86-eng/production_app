import 'dart:async' show unawaited;
import 'dart:ui' show lerpDouble;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/branding/operonix_ai_branding.dart';
import '../../ai/models/production_ai_chat_message.dart';
import '../../ai/services/production_ai_chat_persistence.dart';
import '../models/production_operator_tracking_entry.dart';
import '../models/tracking_today_rollup.dart';
import '../services/production_ai_assistant_service.dart';
import '../services/production_operator_tracking_service.dart';
import '../services/production_tracking_analytics_service.dart';
import '../services/production_tracking_assets_service.dart';
import '../services/tracking_effective_plant_key.dart';

/// Tamni industrijski pregled: KPI i trendovi iz Firestore (`production_operator_tracking`, `assets`).
class ProductionTrackingOverviewTab extends StatefulWidget {
  const ProductionTrackingOverviewTab({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _card = Color(0xFF141418);
  static const Color _cardBorder = Color(0xFF2A2A32);
  static const Color _purple = Color(0xFFB855F7);
  static const Color _muted = Color(0xFF9CA3AF);

  @override
  State<ProductionTrackingOverviewTab> createState() =>
      _ProductionTrackingOverviewTabState();
}

class _ProductionTrackingOverviewTabState
    extends State<ProductionTrackingOverviewTab> {
  final _analytics = ProductionTrackingAnalyticsService();
  final _assetsSvc = ProductionTrackingAssetsService();
  final _trackingSvc = ProductionOperatorTrackingService();
  final _ai = ProductionAiAssistantService();

  bool _loading = true;
  Object? _error;
  ProductionTrackingRangeMode _rangeMode = ProductionTrackingRangeMode.thisWeek;
  ProductionTrackingAnalyticsSnapshot? _snap;
  ProductionPlantAssetsSnapshot? _assets;
  String? _plantKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductionTrackingOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyData != widget.companyData) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    try {
      final plantKey = await resolveEffectiveTrackingPlantKey(widget.companyData);
      if (plantKey == null || plantKey.isEmpty) {
        throw StateError('Nije odabran pogon (plantKey).');
      }

      final results = await Future.wait([
        _analytics.load(
          companyId: cid,
          plantKey: plantKey,
          mode: _rangeMode,
        ),
        _assetsSvc.loadForPlant(companyId: cid, plantKey: plantKey),
      ]);

      if (!mounted) return;
      setState(() {
        _snap = results[0] as ProductionTrackingAnalyticsSnapshot;
        _assets = results[1] as ProductionPlantAssetsSnapshot;
        _plantKey = plantKey;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _onRangeChanged(ProductionTrackingRangeMode mode) async {
    if (mode == _rangeMode) return;
    setState(() => _rangeMode = mode);
    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    try {
      final plantKey = await resolveEffectiveTrackingPlantKey(widget.companyData);
      if (plantKey == null || plantKey.isEmpty) {
        throw StateError('Nije odabran pogon (plantKey).');
      }
      final snap = await _analytics.load(
        companyId: cid,
        plantKey: plantKey,
        mode: mode,
      );
      if (!mounted) return;
      setState(() => _snap = snap);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const ColoredBox(
        color: ProductionTrackingOverviewTab._bg,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: ProductionTrackingOverviewTab._bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Učitavanje pregleda nije uspjelo.',
                  style: textTheme.titleMedium?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_error',
                  style: textTheme.bodySmall?.copyWith(
                    color: ProductionTrackingOverviewTab._muted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Pokušaj ponovno'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final snap = _snap ?? ProductionTrackingAnalyticsSnapshot.empty(_rangeMode);
    final assets = _assets ??
        const ProductionPlantAssetsSnapshot(
          machines: [],
          runningCount: 0,
          totalCount: 0,
        );

    final cid = (widget.companyData['companyId'] ?? '').toString();
    final pk = (_plantKey ?? '').trim();
    final todayKey = ProductionTrackingAnalyticsService.workDateKey(DateTime.now());
    final liveStream = pk.isNotEmpty
        ? _trackingSvc.watchDayAllPhasesMerged(
            companyId: cid,
            plantKey: pk,
            workDate: todayKey,
          )
        : Stream<List<ProductionOperatorTrackingEntry>>.value(
            const <ProductionOperatorTrackingEntry>[],
          );

    return ColoredBox(
      color: ProductionTrackingOverviewTab._bg,
      child: StreamBuilder<List<ProductionOperatorTrackingEntry>>(
        stream: liveStream,
        builder: (context, liveShot) {
          final entries = liveShot.data ?? const <ProductionOperatorTrackingEntry>[];
          final liveRollup = TrackingTodayRollup.fromEntries(entries);

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LiveDayHeader(
                      textTheme: textTheme,
                      workDateLabel: todayKey,
                      waiting: liveShot.connectionState == ConnectionState.waiting,
                    ),
                    const SizedBox(height: 12),
                    _KpiRow(
                      textTheme: textTheme,
                      liveToday: liveRollup,
                      assets: assets,
                    ),
                    const SizedBox(height: 14),
                    _Stations123LiveSection(
                      textTheme: textTheme,
                      rollup: liveRollup,
                    ),
                    const SizedBox(height: 14),
                    _RecentEntriesLiveStrip(
                      textTheme: textTheme,
                      entries: entries,
                    ),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 62,
                            child: _MainChartsColumn(
                              textTheme: textTheme,
                              snap: snap,
                              assets: assets,
                              rangeMode: _rangeMode,
                              onRangeChanged: _onRangeChanged,
                              onRefresh: _load,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 28,
                            child: _AiAssistantPanel(
                              textTheme: textTheme,
                              companyId: cid,
                              plantKey: _plantKey ?? '',
                              ai: _ai,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _MainChartsColumn(
                        textTheme: textTheme,
                        snap: snap,
                        assets: assets,
                        rangeMode: _rangeMode,
                        onRangeChanged: _onRangeChanged,
                        onRefresh: _load,
                      ),
                      const SizedBox(height: 16),
                      _AiAssistantPanel(
                        textTheme: textTheme,
                        companyId: cid,
                        plantKey: _plantKey ?? '',
                        ai: _ai,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'KPI „danas”: uživo sa stanica 1–3 (isti unosi kao u tabovima Pripremna / Prva / Završna kontrola). '
                      'Graf ispod: odabrano razdoblje (nije uživo).',
                      style: textTheme.bodySmall?.copyWith(
                        color: ProductionTrackingOverviewTab._muted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _fmtPct(num v) =>
    '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

String _fmtQtyEu(double v) {
  if (v >= 1000) {
    return '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')}k kom';
  }
  final n = v.round();
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${b.toString()} kom';
}

class _LiveDayHeader extends StatelessWidget {
  const _LiveDayHeader({
    required this.textTheme,
    required this.workDateLabel,
    required this.waiting,
  });

  final TextTheme textTheme;
  final String workDateLabel;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF14532D).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sensors,
                size: 18,
                color: waiting ? ProductionTrackingOverviewTab._muted : const Color(0xFF86EFAC),
              ),
              const SizedBox(width: 8),
              Text(
                waiting ? 'Učitavanje uživo…' : 'Stanice 1–3 · uživo',
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Radni dan: $workDateLabel · agregacija unosa u stvarnom vremenu',
            style: textTheme.bodySmall?.copyWith(color: ProductionTrackingOverviewTab._muted),
          ),
        ),
      ],
    );
  }
}

class _Stations123LiveSection extends StatelessWidget {
  const _Stations123LiveSection({
    required this.textTheme,
    required this.rollup,
  });

  final TextTheme textTheme;
  final TrackingTodayRollup rollup;

  @override
  Widget build(BuildContext context) {
    final phases = [rollup.station1, rollup.station2, rollup.station3];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pogon po stanicama (količina i kvalitet — škart)',
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 720;
                if (narrow) {
                  return Column(
                    children: [
                      for (var i = 0; i < phases.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _StationLiveCard(phase: phases[i], textTheme: textTheme),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _StationLiveCard(phase: phases[0], textTheme: textTheme)),
                    const SizedBox(width: 10),
                    Expanded(child: _StationLiveCard(phase: phases[1], textTheme: textTheme)),
                    const SizedBox(width: 10),
                    Expanded(child: _StationLiveCard(phase: phases[2], textTheme: textTheme)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StationLiveCard extends StatelessWidget {
  const _StationLiveCard({
    required this.phase,
    required this.textTheme,
  });

  final PhaseStationRollup phase;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phase.stationTitle,
            style: textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unosa: ${phase.entryCount}',
            style: textTheme.bodySmall?.copyWith(color: ProductionTrackingOverviewTab._muted),
          ),
          Text(
            'Dobro: ${_fmtQtyEu(phase.goodQty)}',
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          Text(
            'Škart (masa): ${_fmtQtyEu(phase.scrapMass)} · ${_fmtPct(phase.defectMassPct)}',
            style: textTheme.bodySmall?.copyWith(color: const Color(0xFFFDBA74)),
          ),
          if (phase.lastEntryAt != null)
            Text(
              'Zadnji: ${_fmtTime(phase.lastEntryAt!)}',
              style: textTheme.labelSmall?.copyWith(color: ProductionTrackingOverviewTab._muted),
            ),
        ],
      ),
    );
  }
}

String _fmtTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class _RecentEntriesLiveStrip extends StatelessWidget {
  const _RecentEntriesLiveStrip({
    required this.textTheme,
    required this.entries,
  });

  final TextTheme textTheme;
  final List<ProductionOperatorTrackingEntry> entries;

  String _stationTag(String phase) {
    if (phase == ProductionOperatorTrackingEntry.phasePreparation) return 'S1';
    if (phase == ProductionOperatorTrackingEntry.phaseFirstControl) return 'S2';
    if (phase == ProductionOperatorTrackingEntry.phaseFinalControl) return 'S3';
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final top = entries.take(14).toList();
    if (top.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zadnji unosi (uživo)',
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: top.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final e = top[i];
                  final tag = _stationTag(e.phase);
                  final scrap = e.scrapTotalQty > 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: scrap
                            ? const Color(0xFF7C2D12)
                            : ProductionTrackingOverviewTab._cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF93C5FD),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            e.itemCode,
                            style: textTheme.labelSmall?.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${e.effectiveGoodQty.toStringAsFixed(0)} ${e.unit}',
                          style: textTheme.labelSmall?.copyWith(
                            color: ProductionTrackingOverviewTab._muted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.textTheme,
    required this.liveToday,
    required this.assets,
  });

  final TextTheme textTheme;
  final TrackingTodayRollup liveToday;
  final ProductionPlantAssetsSnapshot assets;

  @override
  Widget build(BuildContext context) {
    final uptime = assets.totalCount > 0
        ? _fmtPct(assets.runningSharePct)
        : '—';
    final out = _fmtQtyEu(liveToday.total.goodQty);
    final flags = '${liveToday.total.scrapEntryCount}';
    final defect = liveToday.total.totalMass > 0
        ? _fmtPct(liveToday.total.defectMassPct)
        : '0,0%';

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 600;
        final gap = narrow ? 10.0 : 12.0;
        final children = [
          _KpiCard(
            icon: Icons.factory_outlined,
            iconBg: const Color(0xFF14532D),
            iconFg: const Color(0xFF86EFAC),
            label: 'Strojevi u radu (udio)',
            value: uptime,
            textTheme: textTheme,
          ),
          _KpiCard(
            icon: Icons.settings_suggest_outlined,
            iconBg: const Color(0xFF1E3A8A),
            iconFg: const Color(0xFF93C5FD),
            label: 'Dobro danas (S1+S2+S3)',
            value: out,
            textTheme: textTheme,
          ),
          _KpiCard(
            icon: Icons.warning_amber_rounded,
            iconBg: const Color(0xFF7C2D12),
            iconFg: const Color(0xFFFDBA74),
            label: 'Redovi sa škartom (danas)',
            value: flags,
            textTheme: textTheme,
          ),
          _KpiCard(
            icon: Icons.close_rounded,
            iconBg: const Color(0xFF7F1D1D),
            iconFg: const Color(0xFFFCA5A5),
            label: 'Stopa škarta — danas',
            value: defect,
            textTheme: textTheme,
          ),
        ];
        if (narrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: children[0]),
                  SizedBox(width: gap),
                  Expanded(child: children[1]),
                ],
              ),
              SizedBox(height: gap),
              Row(
                children: [
                  Expanded(child: children[2]),
                  SizedBox(width: gap),
                  Expanded(child: children[3]),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: children[0]),
            SizedBox(width: gap),
            Expanded(child: children[1]),
            SizedBox(width: gap),
            Expanded(child: children[2]),
            SizedBox(width: gap),
            Expanded(child: children[3]),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.value,
    required this.textTheme,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, color: iconFg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: ProductionTrackingOverviewTab._muted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainChartsColumn extends StatelessWidget {
  const _MainChartsColumn({
    required this.textTheme,
    required this.snap,
    required this.assets,
    required this.rangeMode,
    required this.onRangeChanged,
    required this.onRefresh,
  });

  final TextTheme textTheme;
  final ProductionTrackingAnalyticsSnapshot snap;
  final ProductionPlantAssetsSnapshot assets;
  final ProductionTrackingRangeMode rangeMode;
  final void Function(ProductionTrackingRangeMode mode) onRangeChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PerformanceCard(
          textTheme: textTheme,
          snap: snap,
          rangeMode: rangeMode,
          onRangeChanged: onRangeChanged,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 14),
        _MachineStatusStrip(textTheme: textTheme, assets: assets),
        const SizedBox(height: 14),
        _ActivityBarsCard(textTheme: textTheme, snap: snap),
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.textTheme,
    required this.snap,
    required this.rangeMode,
    required this.onRangeChanged,
    required this.onRefresh,
  });

  final TextTheme textTheme;
  final ProductionTrackingAnalyticsSnapshot snap;
  final ProductionTrackingRangeMode rangeMode;
  final void Function(ProductionTrackingRangeMode mode) onRangeChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final trend = snap.trend;
    final values = trend.map((e) => e.yieldPct).toList();
    final labels = trend.map((e) => _chartLabel(e, trend.length)).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Udio dobrog u odnosu na prijavljenu masu (%)',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Osvježi',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ProductionTrackingRangeMode>(
                    value: rangeMode,
                    dropdownColor: const Color(0xFF1F1F24),
                    style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    iconEnabledColor: ProductionTrackingOverviewTab._muted,
                    items: const [
                      DropdownMenuItem(
                        value: ProductionTrackingRangeMode.thisWeek,
                        child: Text('Ovaj tjedan'),
                      ),
                      DropdownMenuItem(
                        value: ProductionTrackingRangeMode.thisMonth,
                        child: Text('Ovaj mjesec'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) onRangeChanged(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (values.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Nema podataka u odabranom razdoblju.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: ProductionTrackingOverviewTab._muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 220,
                child: _EfficiencyLineChart(values: values, labels: labels),
              ),
          ],
        ),
      ),
    );
  }
}

String _chartLabel(DailyProductionMetric e, int n) {
  final parts = e.workDateKey.split('-');
  if (parts.length != 3) return e.workDateKey;
  final y = int.tryParse(parts[0]);
  final mo = int.tryParse(parts[1]);
  final da = int.tryParse(parts[2]);
  if (y == null || mo == null || da == null) return e.workDateKey;
  if (n <= 7) {
    const w = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
    final dt = DateTime(y, mo, da);
    return w[(dt.weekday - 1).clamp(0, 6)];
  }
  return '$da.';
}

class _EfficiencyLineChart extends StatelessWidget {
  const _EfficiencyLineChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(values: values, labels: labels),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    var minV = values.reduce((a, b) => a < b ? a : b) - 5;
    var maxV = values.reduce((a, b) => a > b ? a : b) + 5;
    if (maxV <= minV) {
      minV = 0;
      maxV = 100;
    }
    final n = values.length;
    final dx = n <= 1 ? 0.0 : size.width / (n - 1);
    final h = size.height - 28;

    double yFor(double v) {
      final t = (v - minV) / (maxV - minV);
      return h * (1 - t);
    }

    final linePaint = Paint()
      ..color = ProductionTrackingOverviewTab._purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

    final glowPaint = Paint()
      ..color = ProductionTrackingOverviewTab._purple.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final areaPath = Path();
    if (n == 1) {
      final y = yFor(values[0]);
      path
        ..moveTo(0, y)
        ..lineTo(size.width, y);
      areaPath
        ..moveTo(0, h)
        ..lineTo(0, y)
        ..lineTo(size.width, y)
        ..lineTo(size.width, h)
        ..close();
    } else {
      for (var i = 0; i < values.length; i++) {
        final x = i * dx;
        final y = yFor(values[i]);
        if (i == 0) {
          path.moveTo(x, y);
          areaPath.moveTo(x, h);
          areaPath.lineTo(x, y);
        } else {
          final px = (i - 1) * dx;
          final py = yFor(values[i - 1]);
          final cx = (px + x) / 2;
          path.cubicTo(cx, py, cx, y, x, y);
          areaPath.cubicTo(cx, py, cx, y, x, y);
        }
      }
      final lastX = (n - 1) * dx;
      areaPath.lineTo(lastX, h);
      areaPath.close();
    }

    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        ProductionTrackingOverviewTab._purple.withValues(alpha: 0.35),
        ProductionTrackingOverviewTab._purple.withValues(alpha: 0.0),
      ],
    );
    canvas.drawPath(
      areaPath,
      Paint()..shader = grad.createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    final labelStyle = TextStyle(
      color: ProductionTrackingOverviewTab._muted,
      fontSize: n > 14 ? 9 : 11,
    );
    for (var i = 0; i < labels.length; i++) {
      if (n > 14 && i % 2 == 1) continue;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (n <= 1 ? size.width / 2 : i * dx) - tp.width / 2;
      tp.paint(canvas, Offset(x.clamp(0.0, size.width - tp.width), h + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MachineStatusStrip extends StatelessWidget {
  const _MachineStatusStrip({
    required this.textTheme,
    required this.assets,
  });

  final TextTheme textTheme;
  final ProductionPlantAssetsSnapshot assets;

  @override
  Widget build(BuildContext context) {
    final items = assets.machines;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pregled stanja strojeva (assets)',
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'Nema aktivnih strojeva za ovaj pogon u kolekciji assets.',
                style: textTheme.bodySmall?.copyWith(
                  color: ProductionTrackingOverviewTab._muted,
                ),
              )
            else
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    return _MachineAssetCard(m: items[i], textTheme: textTheme);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MachineAssetCard extends StatelessWidget {
  const _MachineAssetCard({required this.m, required this.textTheme});

  final ProductionMachineOverview m;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    late final Color accent;
    late final String status;
    switch (m.status) {
      case ProductionMachineStatus.running:
        accent = const Color(0xFF14532D);
        status = 'U radu';
      case ProductionMachineStatus.stopped:
        accent = const Color(0xFF713F12);
        status = 'Zaustavljeno';
      case ProductionMachineStatus.unknown:
        accent = const Color(0xFF4B5563);
        status = 'Nepoznato';
    }

    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.title,
            style: textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            m.detail,
            style: textTheme.bodySmall?.copyWith(
              color: ProductionTrackingOverviewTab._muted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActivityBarsCard extends StatelessWidget {
  const _ActivityBarsCard({
    required this.textTheme,
    required this.snap,
  });

  final TextTheme textTheme;
  final ProductionTrackingAnalyticsSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final trend = snap.trend;
    final hMax = 100.0;
    final qty = trend.map((e) => e.goodQty).toList();
    final maxQ = qty.fold<double>(0, (a, b) => a > b ? a : b);
    final norm = maxQ > 0 ? maxQ : 1.0;

    final colors = [
      const Color(0xFFA855F7),
      const Color(0xFFF97316),
      const Color(0xFF14B8A6),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Dnevna proizvodnja (dobra količina)',
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (trend.isEmpty)
              Text(
                'Nema podataka.',
                style: textTheme.bodySmall?.copyWith(
                  color: ProductionTrackingOverviewTab._muted,
                ),
              )
            else
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(trend.length, (i) {
                    final q = qty[i];
                    final hh = lerpDouble(12, hMax, q / norm)!;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: hh,
                              decoration: BoxDecoration(
                                color: colors[i % colors.length],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _chartLabel(trend[i], trend.length),
                              style: textTheme.labelSmall?.copyWith(
                                color: ProductionTrackingOverviewTab._muted,
                                fontSize: trend.length > 14 ? 8 : 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Stubovi su skalirani prema najvećem danu u razdoblju.',
              style: textTheme.bodySmall?.copyWith(
                color: ProductionTrackingOverviewTab._muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAssistantPanel extends StatefulWidget {
  const _AiAssistantPanel({
    required this.textTheme,
    required this.companyId,
    required this.plantKey,
    required this.ai,
  });

  final TextTheme textTheme;
  final String companyId;
  final String plantKey;
  final ProductionAiAssistantService ai;

  @override
  State<_AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<_AiAssistantPanel>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<ProductionAiChatMessage> _messages = [];
  bool _sending = false;
  bool _restored = false;

  double _chatAreaHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1400) return 460;
    if (w >= 1100) return 400;
    if (w >= 900) return 360;
    return 300;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resyncFromCloud());
    }
  }

  Future<void> _resyncFromCloud() async {
    if (_sending) return;
    final list = await ProductionAiChatPersistence.reloadFromCloud(
      widget.companyId,
      widget.plantKey,
    );
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(list);
    });
    _scrollToEnd();
  }

  Future<void> _restore() async {
    final cid = widget.companyId.trim();
    final pk = widget.plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      if (mounted) setState(() => _restored = true);
      return;
    }
    final list = await ProductionAiChatPersistence.load(cid, pk);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(list);
      _restored = true;
    });
    _scrollToEnd();
  }

  void _schedulePersist() {
    final cid = widget.companyId.trim();
    final pk = widget.plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return;
    unawaited(ProductionAiChatPersistence.save(cid, pk, List.of(_messages)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clearChat() async {
    if (_sending) return;
    setState(_messages.clear);
    await ProductionAiChatPersistence.clear(
      widget.companyId,
      widget.plantKey,
    );
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending || !_restored) return;
    final cid = widget.companyId.trim();
    final pk = widget.plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje kontekst pogona (plantKey).'),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(ProductionAiChatMessage.user(text));
      if (_messages.length > 40) {
        _messages.removeRange(0, _messages.length - 40);
      }
      _sending = true;
    });
    _schedulePersist();
    _ctrl.clear();
    _scrollToEnd();

    try {
      final reply = await widget.ai.sendPrompt(
        companyId: cid,
        plantKey: pk,
        prompt: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ProductionAiChatMessage.assistant(reply));
        if (_messages.length > 40) {
          _messages.removeRange(0, _messages.length - 40);
        }
      });
      _schedulePersist();
      _scrollToEnd();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ProductionAiChatMessage.error(e.message ?? e.code),
        );
      });
      _schedulePersist();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ProductionAiChatMessage.error('$e'));
      });
      _schedulePersist();
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  MarkdownStyleSheet _markdownStyle() {
    final base = widget.textTheme.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.92),
      height: 1.38,
    );
    return MarkdownStyleSheet(
      p: base,
      h1: base?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h2: base?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      h3: base?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      strong: base?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      em: base?.copyWith(fontStyle: FontStyle.italic),
      listBullet: base,
      blockquote: base?.copyWith(color: Colors.white70),
      code: base?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: Colors.black26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'Zašto je stopa škarta viša ovaj tjedan?',
      'Sažmi stanje strojeva za ovaj pogon.',
      'Koji su dani imali najviše evidencija sa škartom?',
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ProductionTrackingOverviewTab._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProductionTrackingOverviewTab._cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: ProductionTrackingOverviewTab._purple,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kOperonixAiAssistantTitle,
                    style: widget.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_messages.isNotEmpty)
                  TextButton(
                    onPressed: (_sending || !_restored) ? null : _clearChat,
                    style: TextButton.styleFrom(
                      foregroundColor: ProductionTrackingOverviewTab._muted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Očisti'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: _chatAreaHeight(context),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ProductionTrackingOverviewTab._cardBorder,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: !_restored
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _messages.isEmpty && !_sending
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Postavite pitanje ili odaberite prijedlog ispod. '
                              'Povijest je na vašem računu u oblaku (isti pogon na svim uređajima) '
                              'i lokalno za rad offline.',
                              textAlign: TextAlign.center,
                              style: widget.textTheme.bodySmall?.copyWith(
                                color: ProductionTrackingOverviewTab._muted,
                              ),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, c) {
                            final maxBubble = c.maxWidth * 0.9;
                            return ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                              itemCount:
                                  _messages.length + (_sending ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == _messages.length && _sending) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color:
                                                ProductionTrackingOverviewTab
                                                    ._purple,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Asistent priprema odgovor…',
                                          style: widget.textTheme.bodySmall
                                              ?.copyWith(
                                            color: ProductionTrackingOverviewTab
                                                ._muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                final m = _messages[i];
                                final bubble = m.isUser
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ProductionTrackingOverviewTab
                                              ._purple
                                              .withValues(alpha: 0.22),
                                          borderRadius:
                                              const BorderRadius.only(
                                            topLeft: Radius.circular(14),
                                            topRight: Radius.circular(14),
                                            bottomLeft: Radius.circular(14),
                                            bottomRight: Radius.circular(4),
                                          ),
                                        ),
                                        child: SelectableText(
                                          m.text,
                                          style: widget.textTheme.bodyMedium
                                              ?.copyWith(color: Colors.white),
                                        ),
                                      )
                                    : m.isError
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(14),
                                                topRight: Radius.circular(14),
                                                bottomRight:
                                                    Radius.circular(14),
                                                bottomLeft: Radius.circular(4),
                                              ),
                                              border: Border.all(
                                                color: Colors.red
                                                    .withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: SelectableText(
                                              m.text,
                                              style: widget.textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                color: Colors.red.shade200,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1A1A22),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4),
                                                topRight: Radius.circular(14),
                                                bottomLeft: Radius.circular(14),
                                                bottomRight:
                                                    Radius.circular(14),
                                              ),
                                              border: Border.all(
                                                color: ProductionTrackingOverviewTab
                                                    ._cardBorder,
                                              ),
                                            ),
                                            child: MarkdownBody(
                                              data: m.text,
                                              selectable: true,
                                              styleSheet: _markdownStyle(),
                                            ),
                                          );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Align(
                                    alignment: m.isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: maxBubble,
                                      ),
                                      child: bubble,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Brzi prijedlozi',
              style: widget.textTheme.labelSmall?.copyWith(
                color: ProductionTrackingOverviewTab._muted,
              ),
            ),
            const SizedBox(height: 8),
            ...prompts.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0xFF1F1F26),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: (_sending || !_restored) ? null : () => _send(p),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        p,
                        style: widget.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !_sending && _restored,
                    style: widget.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Upišite poruku…',
                      hintStyle: TextStyle(
                        color: ProductionTrackingOverviewTab._muted,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0E0E12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: ProductionTrackingOverviewTab._cardBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: ProductionTrackingOverviewTab._cardBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: ProductionTrackingOverviewTab._purple
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: ProductionTrackingOverviewTab._purple,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: (_sending || !_restored) ? null : () => _send(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
