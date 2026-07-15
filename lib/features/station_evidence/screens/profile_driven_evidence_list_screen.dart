import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/services/production_station_config_callable_service.dart';
import '../models/profile_driven_evidence_hub_entry.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import '../services/profile_driven_evidence_hub_access.dart';
import 'profile_driven_evidence_records_screen.dart';

/// M2-C hub — dostupne evidencije po pogonu/ulozi (ne pojedinačni zapisi).
class ProfileDrivenEvidenceListScreen extends StatefulWidget {
  const ProfileDrivenEvidenceListScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<ProfileDrivenEvidenceListScreen> createState() =>
      _ProfileDrivenEvidenceListScreenState();
}

class _ProfileDrivenEvidenceListScreenState
    extends State<ProfileDrivenEvidenceListScreen> {
  final _configService = ProductionStationConfigCallableService();
  final _evidenceService = ProfileDrivenEvidenceCallableService();

  bool _loading = true;
  Object? _error;
  List<ProfileDrivenEvidenceHubEntry> _entries = const [];
  Map<String, ProductionStationProfileCatalogEntry> _profilesByKey = const {};

  String? _plantFilterKey;

  List<({String plantKey, String label})> _plantOptions = const [];
  bool _plantsLoading = false;

  final Map<String, String> _plantLabelCache = {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String get _userPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canPickPlant =>
      ProductionAccessHelper.canPickPlantFilterForProfileDrivenEvidence(
        _userRole,
      );

  @override
  void initState() {
    super.initState();
    if (_canPickPlant) {
      _loadPlantOptions();
    } else if (_userPlantKey.isNotEmpty) {
      _loadPlantLabel(_userPlantKey);
    }
    _load();
  }

  Future<void> _loadPlantOptions() async {
    setState(() => _plantsLoading = true);
    try {
      final plants = await CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
      if (!mounted) return;
      setState(() {
        _plantOptions = plants;
        _plantsLoading = false;
        for (final p in plants) {
          _plantLabelCache[p.plantKey] = p.label;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _plantsLoading = false);
    }
  }

  Future<void> _loadPlantLabel(String plantKey) async {
    if (plantKey.isEmpty) return;
    final label = await CompanyPlantDisplayName.resolve(
      companyId: _companyId,
      plantKey: plantKey,
    );
    if (!mounted) return;
    setState(() => _plantLabelCache[plantKey] = label);
  }

  String _plantLabel(String plantKey) {
    if (plantKey.isEmpty) return '—';
    return _plantLabelCache[plantKey] ?? plantKey;
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje kontekst kompanije.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final configsFuture = _configService.listProductionStationConfigs(
        companyId: _companyId,
      );
      final profilesFuture = _configService.listProductionStationProfiles(
        companyId: _companyId,
      );
      final configsResult = await configsFuture;
      final profilesResult = await profilesFuture;

      final profilesByKey = <String, ProductionStationProfileCatalogEntry>{};
      for (final p in profilesResult.profiles) {
        profilesByKey[p.profileKey] = p;
      }

      final visibleConfigs = configsResult.configs;
      final groupedKeys = <String>{};
      for (final c in visibleConfigs) {
        if (ProfileDrivenEvidenceHubAccess.isHubEntryVisibleToUser(
          config: c,
          role: _userRole,
          userPlantKey: _userPlantKey,
          selectedPlantKey: _canPickPlant ? _plantFilterKey : null,
        )) {
          groupedKeys.add(profileDrivenEvidenceHubGroupKey(c));
        }
      }

      final lastEndedAtByGroupKey = <String, DateTime?>{};
      final recordCountByGroupKey = <String, int>{};
      if (groupedKeys.isNotEmpty) {
        final items = await _evidenceService.listProfileDrivenEvidenceSessions(
          companyId: _companyId,
          plantKey: _canPickPlant
              ? (_plantFilterKey?.trim().isEmpty ?? true
                    ? null
                    : _plantFilterKey)
              : (_userPlantKey.trim().isEmpty ? null : _userPlantKey),
          limit: 100,
        );
        for (final item in items) {
          final gKey = '${item.processProfileType}|${item.plantKey}';
          if (!groupedKeys.contains(gKey)) continue;
          recordCountByGroupKey[gKey] = (recordCountByGroupKey[gKey] ?? 0) + 1;
          final ended = item.endedAt;
          if (ended == null) continue;
          final prev = lastEndedAtByGroupKey[gKey];
          if (prev == null || ended.isAfter(prev)) {
            lastEndedAtByGroupKey[gKey] = ended;
          }
        }
      }

      final plantKeys = visibleConfigs
          .map((c) => c.assignedPlantKey)
          .where((k) => k.trim().isNotEmpty);
      for (final pk in plantKeys) {
        if (!_plantLabelCache.containsKey(pk)) {
          await _loadPlantLabel(pk);
        }
      }

      final entries = ProfileDrivenEvidenceHubAccess.buildHubEntries(
        configs: visibleConfigs,
        profilesByKey: profilesByKey,
        role: _userRole,
        userPlantKey: _userPlantKey,
        selectedPlantKey: _canPickPlant ? _plantFilterKey : null,
        lastEndedAtByGroupKey: lastEndedAtByGroupKey,
        recordCountByGroupKey: recordCountByGroupKey,
      );

      if (!mounted) return;
      setState(() {
        _profilesByKey = profilesByKey;
        _entries = entries;
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

  Future<void> _openRecords(ProfileDrivenEvidenceHubEntry entry) async {
    if (!entry.supportsRecordsView) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pregled zapisa za „${entry.profileDisplayName}“ još nije dostupan.',
          ),
        ),
      );
      return;
    }
    final profile = _profilesByKey[entry.processProfileType];
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil evidencije nije dostupan u katalogu.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDrivenEvidenceRecordsScreen(
          companyData: widget.companyData,
          hubEntry: entry,
          profile: profile,
          plantDisplayName: _plantLabel(entry.plantKey),
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Widget _buildFilters() {
    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.35,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_canPickPlant && _userPlantKey.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.factory_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pogon: ${_plantLabel(_userPlantKey)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_canPickPlant)
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _plantFilterKey,
                      decoration: InputDecoration(
                        labelText: 'Pogon',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: _plantsLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi pogoni'),
                        ),
                        ..._plantOptions.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.plantKey,
                            child: Text(p.label),
                          ),
                        ),
                      ],
                      onChanged: _plantsLoading
                          ? null
                          : (v) async {
                              setState(() => _plantFilterKey = v);
                              await _load();
                            },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _profileIcon(String processProfileType) {
    switch (processProfileType) {
      case 'chemical_dosing':
        return Icons.science_outlined;
      case 'wastewater_treatment':
        return Icons.water_drop_outlined;
      case 'rework_and_painting':
        return Icons.format_paint_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _profileAccentColor(String processProfileType, ColorScheme cs) {
    switch (processProfileType) {
      case 'chemical_dosing':
        return cs.tertiary;
      case 'wastewater_treatment':
        return cs.primary;
      case 'rework_and_painting':
        return cs.secondary;
      default:
        return cs.secondary;
    }
  }

  Widget _infoChip({
    required String label,
    required ColorScheme cs,
    Color? background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _cardMetaLine(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(ProfileDrivenEvidenceHubEntry entry) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _profileAccentColor(entry.processProfileType, cs);
    final lastLabel = entry.lastEndedAt == null
        ? '—'
        : formatEvidenceDateOnly(entry.lastEndedAt);
    final countLabel = entry.supportsRecordsView
        ? '${entry.recordCount}'
        : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: entry.supportsRecordsView ? () => _openRecords(entry) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              color: accent.withValues(alpha: 0.85),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _profileIcon(entry.processProfileType),
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.profileDisplayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _infoChip(
                                  label: entry.profileDisplayName,
                                  cs: cs,
                                  background: accent.withValues(alpha: 0.12),
                                ),
                                _infoChip(
                                  label: _plantLabel(entry.plantKey),
                                  cs: cs,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (entry.stationDisplayLabel.trim().isNotEmpty)
                    _cardMetaLine(
                      Icons.precision_manufacturing_outlined,
                      'Stanica: ${entry.stationDisplayLabel}',
                    ),
                  _cardMetaLine(
                    Icons.event_outlined,
                    'Zadnji zapis: $lastLabel',
                  ),
                  _cardMetaLine(
                    Icons.format_list_numbered_outlined,
                    'Broj zapisa: $countLabel',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.45)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _openRecords(entry),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Otvori'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCards() {
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 440,
                mainAxisExtent: 340,
                crossAxisSpacing: 8,
                mainAxisSpacing: 4,
              ),
              itemCount: _entries.length,
              itemBuilder: (_, i) => _buildEvidenceCard(_entries[i]),
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _entries.length,
            itemBuilder: (_, i) => _buildEvidenceCard(_entries[i]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidencije procesa'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profileDrivenEvidenceErrorMessage(_error!),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Pokušaj ponovo'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _entries.isEmpty
                ? Center(
                    child: Text(
                      'Nema evidencija dostupnih za vaš pogon i ulogu.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildEvidenceCards(),
          ),
        ],
      ),
    );
  }
}
