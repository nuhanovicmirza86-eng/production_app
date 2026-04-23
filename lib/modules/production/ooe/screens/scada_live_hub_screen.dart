import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../models/ooe_alert.dart';
import '../models/ooe_live_status.dart';
import '../services/ooe_alert_list_service.dart';
import '../services/ooe_live_service.dart';
import '../theme/scada_theme.dart';

/// SCADA stil: pregled pogona (mreža strojeva) + tab performanse (OEE, A/P/Q).
/// Podaci isključivo iz [ooe_live_status] i [ooe_alerts] (nema lažnih KPI).
class ScadaLiveHubScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ScadaLiveHubScreen({super.key, required this.companyData});

  @override
  State<ScadaLiveHubScreen> createState() => _ScadaLiveHubScreenState();
}

class _ScadaLiveHubScreenState extends State<ScadaLiveHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _live = OoeLiveService();
  final _alerts = OoeAlertListService();

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk => (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _canView {
    final r = ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    return ProductionAccessHelper.canView(role: r, card: ProductionDashboardCard.ooe);
  }

  static Color _statusColor(String state) {
    final s = state.toLowerCase();
    if (s.isEmpty) return ScadaTheme.standby;
    if (s.contains('run') || s.contains('rad') || s.contains('product')) {
      return ScadaTheme.run;
    }
    if (s.contains('stop') || s.contains('zaust')) return ScadaTheme.stop;
    if (s.contains('pause') || s.contains('pauz')) return ScadaTheme.pause;
    if (s.contains('maint') || s.contains('održ')) return ScadaTheme.maintenance;
    if (s.contains('standby') || s.contains('ček')) return ScadaTheme.standby;
    return ScadaTheme.accentBlue;
  }

  static String _statusLabel(String state) {
    final s = state.trim();
    if (s.isEmpty) return 'NEPOZNATO';
    return s.length > 14 ? '${s.substring(0, 14)}…' : s.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('SCADA')),
        body: const Center(child: Text('Nemate pristup OOE / SCADA prikazu.')),
      );
    }

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ScadaTheme.bg,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ScadaTheme.accentBlue,
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SCADA — pogon'),
          backgroundColor: ScadaTheme.card,
          bottom: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: ScadaTheme.textDim,
            indicatorColor: ScadaTheme.accentBlue,
            tabs: const [
              Tab(text: 'PREGLED POGONA'),
              Tab(text: 'PERFORMANSE'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _PlantOverviewTab(
              companyId: _cid,
              plantKey: _pk,
              live: _live,
              alerts: _alerts,
              statusColor: _statusColor,
              statusLabel: _statusLabel,
            ),
            _PerformanceTab(
              companyId: _cid,
              plantKey: _pk,
              live: _live,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantOverviewTab extends StatelessWidget {
  const _PlantOverviewTab({
    required this.companyId,
    required this.plantKey,
    required this.live,
    required this.alerts,
    required this.statusColor,
    required this.statusLabel,
  });

  final String companyId;
  final String plantKey;
  final OoeLiveService live;
  final OoeAlertListService alerts;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OoeLiveStatus>>(
      stream: live.watchLiveForPlant(companyId: companyId, plantKey: plantKey),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Greška: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        return FutureBuilder<ProductionPlantAssetsSnapshot>(
          future: ProductionTrackingAssetsService().loadForPlant(
            companyId: companyId,
            plantKey: plantKey,
            limit: 128,
          ),
          builder: (context, assetSnap) {
            final assets = assetSnap.data;
            final labelMap = <String, String>{
              if (assets != null)
                for (final m in assets.machines) m.id: m.title,
            };
            final cross = MediaQuery.sizeOf(context).width > 1000 ? 4 : 2;
            final factoryOee = _avgOee(list);
            final totalUnits = _sumGoodScrap(list);
            final footer = _FactoryFooter(
              factoryOee: factoryOee,
              totalUnits: totalUnits,
              machineCount: list.length,
            );

            return LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 1100;
                final grid = GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 4 : cross,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final st = list[i];
                    final name = (labelMap[st.machineId] ?? st.machineId).trim();
                    final sc = statusColor(st.currentState);
                    return _MachineCard(
                      title: name.isEmpty ? st.machineId : name,
                      subtitle: st.machineId,
                      oee: st.currentShiftOoe,
                      availability: st.availability,
                      performance: st.performance,
                      quality: st.quality,
                      good: st.goodCount,
                      scrap: st.scrapCount,
                      stateColor: sc,
                      stateLabel: statusLabel(st.currentState),
                    );
                  },
                );

                if (!wide) {
                  return Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<List<OoeAlert>>(
                          stream: alerts.watchRecentForPlant(
                            companyId: companyId,
                            plantKey: plantKey,
                            limit: 20,
                          ),
                          builder: (ctx, as) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AlarmsStrip(alerts: as.data ?? const []),
                                Expanded(child: grid),
                              ],
                            );
                          },
                        ),
                      ),
                      footer,
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 280,
                            child: _AlarmsPanel(
                              companyId: companyId,
                              plantKey: plantKey,
                              alerts: alerts,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: grid),
                        ],
                      ),
                    ),
                    footer,
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AlarmsStrip extends StatelessWidget {
  const _AlarmsStrip({required this.alerts});

  final List<OoeAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final open = alerts
        .where((a) => a.status == OoeAlert.statusOpen)
        .take(3)
        .toList();
    if (open.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: ScadaTheme.card,
        child: const Text(
          'Nema otvorenih OOE alarma',
          style: TextStyle(color: ScadaTheme.textDim, fontSize: 12),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      color: ScadaTheme.card,
      child: Row(
        children: open
            .map(
              (a) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A1616),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ScadaTheme.stop.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    a.message ?? a.ruleType,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AlarmsPanel extends StatelessWidget {
  const _AlarmsPanel({
    required this.companyId,
    required this.plantKey,
    required this.alerts,
  });

  final String companyId;
  final String plantKey;
  final OoeAlertListService alerts;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OoeAlert>>(
      stream: alerts.watchRecentForPlant(
        companyId: companyId,
        plantKey: plantKey,
        limit: 30,
      ),
      builder: (context, snap) {
        final all = snap.data ?? const <OoeAlert>[];
        final open = all
            .where((a) => a.status == OoeAlert.statusOpen)
            .take(8)
            .toList();
        return ColoredBox(
          color: ScadaTheme.card,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                'AKTIVNI ALARMI',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (open.isEmpty)
                const Text(
                  'Nema otvorenih alarma',
                  style: TextStyle(color: ScadaTheme.textDim, fontSize: 12),
                )
              else
                ...open.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1E16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ScadaTheme.maintenance),
                      ),
                      child: Text(
                        a.message ?? '${a.machineId} · ${a.ruleType}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({
    required this.title,
    required this.subtitle,
    required this.oee,
    required this.availability,
    required this.performance,
    required this.quality,
    required this.good,
    required this.scrap,
    required this.stateColor,
    required this.stateLabel,
  });

  final String title;
  final String subtitle;
  final double oee;
  final double availability;
  final double performance;
  final double quality;
  final double good;
  final double scrap;
  final Color stateColor;
  final String stateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ScadaTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ScadaTheme.border),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.precision_manufacturing, size: 16, color: stateColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${(oee * 100).toStringAsFixed(1)}% OEE',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ScadaTheme.textDim,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: ScadaTheme.textDim),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'STANJE',
                style: TextStyle(fontSize: 9, color: ScadaTheme.textDim),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: stateColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'A ${(availability * 100).toStringAsFixed(0)}% · '
            'P ${(performance * 100).toStringAsFixed(0)}% · '
            'Q ${(quality * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10, color: ScadaTheme.textDim),
          ),
          const SizedBox(height: 4),
          Text(
            'Dobro: ${good.toStringAsFixed(0)}   Škart: ${scrap.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oee.clamp(0, 1),
              minHeight: 4,
              backgroundColor: ScadaTheme.border,
              color: stateColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryFooter extends StatelessWidget {
  const _FactoryFooter({
    required this.factoryOee,
    required this.totalUnits,
    required this.machineCount,
  });

  final double factoryOee;
  final double totalUnits;
  final int machineCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1116),
        border: Border(top: BorderSide(color: ScadaTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _foot('OEE (prosjek)', '${(factoryOee * 100).toStringAsFixed(1)}%'),
          _foot('Ukupno kom.', totalUnits.toStringAsFixed(0)),
          _foot('Strojeva u prikazu', '$machineCount'),
        ],
      ),
    );
  }

  static Widget _foot(String a, String b) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          a,
          style: const TextStyle(
            color: ScadaTheme.textDim,
            fontSize: 10,
          ),
        ),
        Text(
          b,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

double _avgOee(List<OoeLiveStatus> list) {
  if (list.isEmpty) return 0;
  return list.map((e) => e.currentShiftOoe).reduce((a, b) => a + b) / list.length;
}

double _sumGoodScrap(List<OoeLiveStatus> list) {
  double s = 0;
  for (final e in list) {
    s += e.goodCount + e.scrapCount;
  }
  return s;
}

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({
    required this.companyId,
    required this.plantKey,
    required this.live,
  });

  final String companyId;
  final String plantKey;
  final OoeLiveService live;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OoeLiveStatus>>(
      stream: live.watchLiveForPlant(companyId: companyId, plantKey: plantKey),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Text('Nema live podataka za pogon (ooe_live_status).'),
          );
        }
        final oee = _avgOee(list);
        final av = _avgOf(list, (e) => e.availability);
        final pr = _avgOf(list, (e) => e.performance);
        final qu = _avgOf(list, (e) => e.quality);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'UKUPNA EFEKTIVNOST OPREME (OEE) — prosjek live strojeva u pogone',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ScadaTheme.textDim,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                height: 160,
                width: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: CircularProgressIndicator(
                        value: oee.clamp(0, 1),
                        strokeWidth: 14,
                        backgroundColor: ScadaTheme.border,
                        color: ScadaTheme.run,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(oee * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text('OEE', style: TextStyle(color: ScadaTheme.textDim)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _KpiPillar(
                    label: 'Dostupnost (A)',
                    value: av,
                    color: const Color(0xFF00BCD4),
                    icon: Icons.settings_suggest,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiPillar(
                    label: 'Performanse (P)',
                    value: pr,
                    color: const Color(0xFF9C27B0),
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiPillar(
                    label: 'Kvalitet (Q)',
                    value: qu,
                    color: const Color(0xFFFF9800),
                    icon: Icons.verified,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Podaci su aritmetički prosjek A/P/Q preko svih mašina koje trenutno imaju zapis u ooe_live_status.',
              style: TextStyle(fontSize: 11, color: ScadaTheme.textDim),
            ),
          ],
        );
      },
    );
  }
}

double _avgOf(
  List<OoeLiveStatus> list,
  double Function(OoeLiveStatus) f,
) {
  if (list.isEmpty) return 0;
  return list.map(f).reduce((a, b) => a + b) / list.length;
}

class _KpiPillar extends StatelessWidget {
  const _KpiPillar({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScadaTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ScadaTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '${(value * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: ScadaTheme.textDim,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 6,
              backgroundColor: ScadaTheme.border,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
