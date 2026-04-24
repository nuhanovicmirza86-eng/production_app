import 'package:flutter/material.dart';

import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../../downtime/analytics/downtime_analytics_engine.dart';
import '../../downtime/screens/downtimes_screen.dart';

/// Drill-down: jedan radni centar (agregat zastoja u periodu).
class AnalyticsWorkCenterDetailsScreen extends StatelessWidget {
  const AnalyticsWorkCenterDetailsScreen({
    super.key,
    required this.group,
    required this.rangeLabel,
    required this.rangeStart,
    required this.rangeEndExclusive,
    required this.companyData,
    this.includeRejectedForDowntimeLinks = false,
  });

  final DowntimeGroupStats group;
  final String rangeLabel;
  final DateTime rangeStart;
  final DateTime rangeEndExclusive;
  final Map<String, dynamic> companyData;
  final bool includeRejectedForDowntimeLinks;

  String get _role =>
      ProductionAccessHelper.normalizeRole(companyData['role']);

  bool get _canOpenDowntimeList => ProductionAccessHelper.canView(
    role: _role,
    card: ProductionDashboardCard.downtime,
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          group.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Period: $rangeLabel',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: operonixProductionCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(t, 'Dogadjaja (zastoja)', '${group.events}'),
                  _kv(t, 'Ukupno minuta', '${group.minutesClipped}'),
                  _kv(t, 'Gubitak povezan s OEE', '${group.minutesOee} min'),
                  _kv(t, 'Gubitak povezan s OOE', '${group.minutesOoe} min'),
                  _kv(t, 'Gubitak povezan s TEEP', '${group.minutesTeep} min'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kako dalje (drill-down u sustavu)',
            style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_canOpenDowntimeList) ...[
            FilledButton.tonalIcon(
              onPressed: () {
                final key = group.key.trim();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => DowntimesScreen(
                      companyData: companyData,
                      openOperativeFiltersOnOpen: true,
                      initialOperativeWorkCenterIdOrCode: key.isEmpty || key == '—' ? null : key,
                      initialEventRangeStart: rangeStart,
                      initialEventRangeEndExclusive: rangeEndExclusive,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Otvori modul Zastoji — filtrirano (RC + period)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => DowntimesScreen(
                      companyData: companyData,
                      initialTabIndex: 1,
                      initialAnalyticsRangeStart: rangeStart,
                      initialAnalyticsRangeEndExclusive: rangeEndExclusive,
                      initialAnalyticsIncludeRejected: includeRejectedForDowntimeLinks,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Zastoji — puna analitika (isti period)'),
            ),
            const SizedBox(height: 8),
            Text(
              'Lista (operativa) filtrirana po RC; tab Analitika prikazuje cijeli pogon u istom periodu (za dubinu po RC koristi ove ekrane). '
              'Kad postoji povezani nalog, na retku je ikonica naloga ili u detalju zastoja gumb „Otvori nalo“.',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ] else
            Text(
              'Nemaš pristup modulu Zastoji; kontaktiraj administratora za ulogu s pregledom zastoja.',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  static Widget _kv(ThemeData theme, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
