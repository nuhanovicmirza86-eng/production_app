import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/quality_callable_service.dart';

/// KPI preko Callable-a [getQmsDashboardSummary] (bez direktnog pisanja u Firestore s klijenta).
class QualityDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const QualityDashboardScreen({super.key, required this.companyData});

  @override
  State<QualityDashboardScreen> createState() => _QualityDashboardScreenState();
}

class _QualityDashboardScreenState extends State<QualityDashboardScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  int _cp = 0;
  int _ip = 0;
  int _ncr = 0;
  int _capa = 0;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cid = _cid;
    if (cid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final s = await _svc.getQmsDashboardSummary(companyId: cid);
      if (!mounted) return;
      setState(() {
        _cp = s.controlPlanCount;
        _ip = s.inspectionPlanCount;
        _ncr = s.openNcrCount;
        _capa = s.openCapaCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QMS dashboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const LinearProgressIndicator()
            else ...[
              _KpiCard(
                title: 'Kontrolni planovi',
                value: '$_cp',
                subtitle: 'Podaci samo preko Callable (klijent nema read na kolekciju)',
              ),
              const SizedBox(height: 12),
              _KpiCard(
                title: 'Planovi inspekcije',
                value: '$_ip',
                subtitle: 'Ulaz / u procesu / finalno',
              ),
              const SizedBox(height: 12),
              _KpiCard(
                title: 'Otvoreni NCR',
                value: '$_ncr',
                subtitle: 'Statusi OPEN / UNDER_REVIEW / CONTAINED',
              ),
              const SizedBox(height: 12),
              _KpiCard(
                title: 'Otvoreni CAPA',
                value: '$_capa',
                subtitle: 'action_plans · sourceType = non_conformance',
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Trendovi (scrap/defect), Pareto i IATF izvještaji — sljedeća faza.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
