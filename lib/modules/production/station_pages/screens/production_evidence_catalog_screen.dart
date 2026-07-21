import 'package:flutter/material.dart';

import '../models/production_station_config.dart';
import '../models/production_station_profile_catalog_entry.dart';

/// M1-G6 — read-only pregled platformskog kataloga obrazaca evidencije.
class ProductionEvidenceCatalogScreen extends StatelessWidget {
  final ProductionStationProfileCatalogResult catalog;

  const ProductionEvidenceCatalogScreen({
    super.key,
    required this.catalog,
  });

  static const String _standardProductionProfileKey = 'standard_production';

  List<ProductionStationProfileCatalogEntry> get _evidenceProfiles {
    return catalog.profiles
        .where(
          (p) =>
              p.stationType == ProductionStationConfig.stationTypeProduction &&
              p.profileKey != _standardProductionProfileKey,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _evidenceProfiles;
    final readyCount = profiles.where((p) => p.isComplete).length;
    final inPrepCount = profiles.where((p) => p.isSkeleton).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog evidencija'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Obrazci evidencije',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Evidencije iz kataloga ne ulaze u limit proizvodnih ni mašinskih '
                    'stanica. Kompanija aktivira odabrani obrazac po pogonu i procesu '
                    '— ista evidencija može postojati više puta, nezavisno.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text('Spremno: $readyCount'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.hourglass_empty, size: 18),
                        label: Text('U pripremi: $inPrepCount'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text('Katalog v${catalog.catalogVersion}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Katalog obrazaca evidencije trenutno nije dostupan.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...profiles.map(
              (profile) => _EvidenceCatalogProfileCard(profile: profile),
            ),
        ],
      ),
    );
  }
}

class _EvidenceCatalogProfileCard extends StatelessWidget {
  final ProductionStationProfileCatalogEntry profile;

  const _EvidenceCatalogProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = profile.isComplete
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    profile.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(profile.definitionStatusLabelText),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            if (profile.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                profile.description,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (profile.fields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Polja u obrascu: ${profile.fields.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
