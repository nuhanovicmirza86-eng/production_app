import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/screens/production_profile_station_launch_screen.dart';
import '../services/profile_driven_evidence_hub_access.dart';
import '../models/profile_driven_evidence_hub_entry.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import '../../../core/ui/standard_table_components.dart';
import '../widgets/profile_driven_evidence_grid.dart';
import 'profile_driven_evidence_detail_screen.dart';

const _profileWastewaterTreatment = 'wastewater_treatment';
const _pageSizeOptions = [10, 20, 50, 100];

const _wastewaterColumns = [
  ProfileDrivenEvidenceGridColumn(id: 'date', label: 'Datum', flex: 8),
  ProfileDrivenEvidenceGridColumn(id: 'time', label: 'Vrijeme', flex: 7),
  ProfileDrivenEvidenceGridColumn(
    id: 'reactor',
    label: 'Reaktor',
    flex: 7,
    align: TextAlign.center,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'treatment_point',
    label: 'Procesna tačka',
    flex: 12,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'quantity',
    label: 'Tretirana\nkoličina',
    flex: 9,
    align: TextAlign.right,
    numeric: true,
  ),
  ProfileDrivenEvidenceGridColumn(id: 'unit', label: 'Jedinica', flex: 7),
  ProfileDrivenEvidenceGridColumn(
    id: 'lime',
    label: 'Kreč',
    flex: 6,
    align: TextAlign.right,
    numeric: true,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'metabisulfite',
    label: 'Metabisulfit',
    flex: 8,
    align: TextAlign.right,
    numeric: true,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'naoh',
    label: 'NaOH',
    flex: 6,
    align: TextAlign.right,
    numeric: true,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'heavy_metals',
    label: 'Teški\nmetali',
    flex: 8,
    align: TextAlign.center,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'ph',
    label: 'pH',
    flex: 5,
    align: TextAlign.right,
    numeric: true,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'temperature',
    label: 'Temperatura',
    flex: 8,
    align: TextAlign.right,
    numeric: true,
  ),
  ProfileDrivenEvidenceGridColumn(id: 'operator', label: 'Operater', flex: 10),
  ProfileDrivenEvidenceGridColumn(id: 'status', label: 'Status', flex: 8),
  ProfileDrivenEvidenceGridColumn(
    id: 'details',
    label: 'Detalji',
    flex: 8,
    align: TextAlign.center,
  ),
];

const _chemicalColumns = [
  ProfileDrivenEvidenceGridColumn(id: 'date', label: 'Datum', flex: 7),
  ProfileDrivenEvidenceGridColumn(id: 'time', label: 'Vrijeme', flex: 6),
  ProfileDrivenEvidenceGridColumn(id: 'work_bath', label: 'Radna kada', flex: 10),
  ProfileDrivenEvidenceGridColumn(id: 'chemical', label: 'Hemikalija', flex: 10),
  ProfileDrivenEvidenceGridColumn(
    id: 'quantity',
    label: 'Količina',
    flex: 7,
    align: TextAlign.right,
    numeric: true,
  ),
  ProfileDrivenEvidenceGridColumn(id: 'unit', label: 'Jedinica', flex: 6),
  ProfileDrivenEvidenceGridColumn(
    id: 'process_area',
    label: 'Procesno\npodručje',
    flex: 10,
  ),
  ProfileDrivenEvidenceGridColumn(
    id: 'concentration',
    label: 'Koncentracija',
    flex: 8,
  ),
  ProfileDrivenEvidenceGridColumn(id: 'lot', label: 'Lot / šarža', flex: 8),
  ProfileDrivenEvidenceGridColumn(id: 'reason', label: 'Razlog', flex: 10),
  ProfileDrivenEvidenceGridColumn(id: 'operator', label: 'Operater', flex: 10),
  ProfileDrivenEvidenceGridColumn(id: 'status', label: 'Status', flex: 7),
  ProfileDrivenEvidenceGridColumn(
    id: 'details',
    label: 'Detalji',
    flex: 7,
    align: TextAlign.center,
  ),
];

/// M2-C — tabelarni pregled zapisa jedne evidencije (profil + pogon).
class ProfileDrivenEvidenceRecordsScreen extends StatefulWidget {
  const ProfileDrivenEvidenceRecordsScreen({
    super.key,
    required this.companyData,
    required this.hubEntry,
    required this.profile,
    required this.plantDisplayName,
  });

  final Map<String, dynamic> companyData;
  final ProfileDrivenEvidenceHubEntry hubEntry;
  final ProductionStationProfileCatalogEntry profile;
  final String plantDisplayName;

  @override
  State<ProfileDrivenEvidenceRecordsScreen> createState() =>
      _ProfileDrivenEvidenceRecordsScreenState();
}

class _ProfileDrivenEvidenceRecordsScreenState
    extends State<ProfileDrivenEvidenceRecordsScreen> {
  final _service = ProfileDrivenEvidenceCallableService();
  late final ScrollController _verticalBodyController;

  bool _loading = true;
  Object? _error;
  List<ProfileDrivenEvidenceListItem> _items = const [];

  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _pageSize = 20;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _processProfileType => widget.hubEntry.processProfileType;

  String get _plantKey => widget.hubEntry.plantKey;

  List<ProfileDrivenEvidenceGridColumn> get _columns =>
      _processProfileType == _profileWastewaterTreatment
      ? _wastewaterColumns
      : _chemicalColumns;

  @override
  void initState() {
    super.initState();
    _verticalBodyController = ScrollController();
    _load();
  }

  @override
  void dispose() {
    _verticalBodyController.dispose();
    super.dispose();
  }

  String _formatApiDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_dateFrom ?? _dateTo ?? DateTime.now())
        : (_dateTo ?? _dateFrom ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
          _dateTo = _dateFrom;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(_dateTo!)) {
          _dateFrom = _dateTo;
        }
      }
    });
    await _load();
  }

  Future<void> _clearDates() async {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listProfileDrivenEvidenceSessions(
        companyId: _companyId,
        plantKey: _plantKey,
        processProfileType: _processProfileType,
        dateFrom: _dateFrom != null ? _formatApiDate(_dateFrom!) : null,
        dateTo: _dateTo != null ? _formatApiDate(_dateTo!) : null,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _openDetail(ProfileDrivenEvidenceListItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDrivenEvidenceDetailScreen(
          companyData: widget.companyData,
          sessionId: item.sessionId,
        ),
      ),
    );
  }

  Future<void> _openExistingInput() async {
    final userPlantKey =
        (widget.companyData['plantKey'] ?? '').toString().trim();
    final role =
        ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    ProductionStationConfig? launchConfig;
    for (final config in widget.hubEntry.stationConfigs) {
      if (ProfileDrivenEvidenceHubAccess.canCreateEntryOnStation(
        config: config,
        role: role,
        userPlantKey: userPlantKey,
        entryPlantKey: widget.hubEntry.plantKey,
      )) {
        launchConfig = config;
        break;
      }
    }
    if (launchConfig == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionProfileStationLaunchScreen(
          companyData: widget.companyData,
          stationConfig: launchConfig!,
          profile: widget.profile,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  String _operatorLabel(ProfileDrivenEvidenceListItem item) {
    final name = (item.operatorDisplayName ?? '').trim();
    if (name.isNotEmpty) return name;
    return (item.operatorEmail ?? '—').trim();
  }

  String _statusLabel(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'closed') return 'Završeno';
    if (s.isEmpty) return '—';
    return status;
  }

  Widget _statusBadge(String status) {
    return StandardTableStatusBadge(label: _statusLabel(status));
  }

  Widget _detailButton(ProfileDrivenEvidenceListItem item) {
    return StandardTableOpenLink(onPressed: () => _openDetail(item));
  }

  List<Widget> _buildDataCells({
    required ProfileDrivenEvidenceListItem item,
    required List<ProfileDrivenEvidenceGridColumn> cols,
    required Color borderColor,
    required Color rowBackground,
    required TextStyle cellStyle,
    required String? Function(String columnId) valueFor,
  }) {
    final cells = <Widget>[];
    for (var i = 0; i < cols.length; i++) {
      final col = cols[i];
      final isLast = i == cols.length - 1;
      if (col.id == 'status') {
        cells.add(
          profileEvidenceGridWidgetCell(
            column: col,
            borderColor: borderColor,
            rowBackground: rowBackground,
            isLast: isLast,
            child: _statusBadge(item.status),
          ),
        );
      } else if (col.id == 'details') {
        cells.add(
          profileEvidenceGridWidgetCell(
            column: col,
            borderColor: borderColor,
            rowBackground: rowBackground,
            isLast: isLast,
            child: _detailButton(item),
          ),
        );
      } else {
        cells.add(
          profileEvidenceGridTextCell(
            column: col,
            text: valueFor(col.id) ?? '—',
            borderColor: borderColor,
            rowBackground: rowBackground,
            cellStyle: cellStyle,
            isLast: isLast,
          ),
        );
      }
    }
    return cells;
  }

  List<Widget> _wastewaterCells(
    ProfileDrivenEvidenceListItem item,
    List<ProfileDrivenEvidenceGridColumn> cols,
    Color borderColor,
    Color rowBackground,
    TextStyle cellStyle,
  ) {
    final s = item.summaryFields;
    return _buildDataCells(
      item: item,
      cols: cols,
      borderColor: borderColor,
      rowBackground: rowBackground,
      cellStyle: cellStyle,
      valueFor: (id) {
        switch (id) {
          case 'date':
            return formatEvidenceDateShort(item.endedAt);
          case 'time':
            return formatEvidenceTime(item.endedAt);
          case 'reactor':
            return s.reactorNumber;
          case 'treatment_point':
            return s.treatmentPointName;
          case 'quantity':
            return formatFieldValue(s.quantity);
          case 'unit':
            return s.unit;
          case 'lime':
            return formatFieldValue(s.limeQuantity);
          case 'metabisulfite':
            return formatFieldValue(s.sodiumMetabisulfiteQuantity);
          case 'naoh':
            return formatFieldValue(s.sodiumHydroxideQuantity);
          case 'heavy_metals':
            return formatHeavyMetalsLabel(s.heavyMetalsPresent);
          case 'ph':
            return formatFieldValue(s.phValue);
          case 'temperature':
            return s.temperatureC == null
                ? null
                : '${formatFieldValue(s.temperatureC)} °C';
          case 'operator':
            return _operatorLabel(item);
          default:
            return null;
        }
      },
    );
  }

  List<Widget> _chemicalCells(
    ProfileDrivenEvidenceListItem item,
    List<ProfileDrivenEvidenceGridColumn> cols,
    Color borderColor,
    Color rowBackground,
    TextStyle cellStyle,
  ) {
    final s = item.summaryFields;
    return _buildDataCells(
      item: item,
      cols: cols,
      borderColor: borderColor,
      rowBackground: rowBackground,
      cellStyle: cellStyle,
      valueFor: (id) {
        switch (id) {
          case 'date':
            return formatEvidenceDateShort(item.endedAt);
          case 'time':
            return formatEvidenceTime(item.endedAt);
          case 'work_bath':
            return s.workBathName;
          case 'chemical':
            return s.chemicalName;
          case 'quantity':
            return formatFieldValue(s.quantity);
          case 'unit':
            return s.unit;
          case 'process_area':
            return s.processAreaName;
          case 'concentration':
            return s.concentrationSnapshot;
          case 'lot':
            return s.chemicalLot;
          case 'reason':
            return s.dosingReason;
          case 'operator':
            return _operatorLabel(item);
          default:
            return null;
        }
      },
    );
  }

  Widget _buildFilters() {
    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.35,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Pogon: ${widget.plantDisplayName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: true),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                _dateFrom == null
                    ? 'Datum od'
                    : 'Od: ${formatEvidenceDateOnly(_dateFrom)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(isFrom: false),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _dateTo == null
                    ? 'Datum do'
                    : 'Do: ${formatEvidenceDateOnly(_dateTo)}',
              ),
            ),
            if (_dateFrom != null || _dateTo != null)
              TextButton(
                onPressed: _clearDates,
                child: const Text('Očisti datume'),
              ),
            DropdownButton<int>(
              value: _pageSize,
              underline: const SizedBox.shrink(),
              items: _pageSizeOptions
                  .map(
                    (n) => DropdownMenuItem<int>(
                      value: n,
                      child: Text('Prikaži: $n'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _loading
                  ? null
                  : (value) async {
                      if (value == null || value == _pageSize) return;
                      setState(() => _pageSize = value);
                      await _load();
                    },
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Osvježi'),
            ),
            if (widget.hubEntry.canCreateEntry)
              FilledButton.icon(
                onPressed: _openExistingInput,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novi unos'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final borderColor = StandardTableMetrics.borderColor(cs);
    final rowBackground = StandardTableMetrics.rowBackground(cs);
    final cellStyle = StandardTableMetrics.cellStyle(cs);
    final cols = _columns;
    final isWastewater = _processProfileType == _profileWastewaterTreatment;

    Widget dataRow(int index) {
      final item = _items[index];
      final cells = isWastewater
          ? _wastewaterCells(
              item,
              cols,
              borderColor,
              rowBackground,
              cellStyle,
            )
          : _chemicalCells(
              item,
              cols,
              borderColor,
              rowBackground,
              cellStyle,
            );

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '${_items.length} zapisa',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: StandardTableShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileDrivenEvidenceGridTable(columns: cols),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: Scrollbar(
                        controller: _verticalBodyController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _verticalBodyController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length,
                          itemBuilder: (_, index) => dataRow(index),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.hubEntry.profileDisplayName;
    return Scaffold(
      appBar: AppBar(
        title: Text('Evidencija: $title'),
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
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'Nema zatvorenih zapisa za odabrane filtere.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildTable(),
          ),
        ],
      ),
    );
  }
}
