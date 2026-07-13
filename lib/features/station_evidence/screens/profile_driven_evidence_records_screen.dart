import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/screens/production_profile_station_launch_screen.dart';
import '../services/profile_driven_evidence_hub_access.dart';
import '../models/profile_driven_evidence_hub_entry.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import 'profile_driven_evidence_detail_screen.dart';

const _profileWastewaterTreatment = 'wastewater_treatment';
const _pageSizeOptions = [10, 20, 50, 100];

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
  late final ScrollController _horizontalHeaderController;
  late final ScrollController _horizontalBodyController;
  late final ScrollController _verticalBodyController;
  bool _syncingHorizontalScroll = false;

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

  double get _tableMinWidth =>
      _processProfileType == _profileWastewaterTreatment ? 2280 : 2040;

  @override
  void initState() {
    super.initState();
    _horizontalHeaderController = ScrollController();
    _horizontalBodyController = ScrollController();
    _verticalBodyController = ScrollController();
    _horizontalHeaderController.addListener(_syncHeaderToBody);
    _horizontalBodyController.addListener(_syncBodyToHeader);
    _load();
  }

  @override
  void dispose() {
    _horizontalHeaderController.removeListener(_syncHeaderToBody);
    _horizontalBodyController.removeListener(_syncBodyToHeader);
    _horizontalHeaderController.dispose();
    _horizontalBodyController.dispose();
    _verticalBodyController.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() {
    if (_syncingHorizontalScroll) return;
    if (!_horizontalBodyController.hasClients) return;
    _syncingHorizontalScroll = true;
    _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
    _syncingHorizontalScroll = false;
  }

  void _syncBodyToHeader() {
    if (_syncingHorizontalScroll) return;
    if (!_horizontalHeaderController.hasClients) return;
    _syncingHorizontalScroll = true;
    _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
    _syncingHorizontalScroll = false;
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

  Widget _statusCell(String status, {required double width}) {
    final label = _statusLabel(status);
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(
              alpha: 0.55,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }

  Widget _detailCell(ProfileDrivenEvidenceListItem item, {required double width}) {
    return SizedBox(
      width: width,
      child: Center(
        child: TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => _openDetail(item),
          child: const Text('Otvori'),
        ),
      ),
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

  TextStyle _cellStyle({bool header = false}) {
    final theme = Theme.of(context);
    return (header ? theme.textTheme.labelMedium : theme.textTheme.bodySmall)!
        .copyWith(fontWeight: header ? FontWeight.w600 : FontWeight.w400);
  }

  Widget _cell(
    String text, {
    required double width,
    TextAlign align = TextAlign.left,
    bool header = false,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _cellStyle(header: header),
      ),
    );
  }

  Widget _headerRow() {
    if (_processProfileType == _profileWastewaterTreatment) {
      return Row(
        children: [
          _cell('Datum', width: 88, header: true),
          _cell('Vrijeme', width: 56, header: true),
          _cell('Reaktor', width: 64, header: true, align: TextAlign.center),
          _cell('Procesna tačka', width: 160, header: true),
          _cell('Tretirana količina', width: 96, header: true, align: TextAlign.right),
          _cell('Jedinica', width: 72, header: true),
          _cell('Kreč', width: 64, header: true, align: TextAlign.right),
          _cell('Natrijum metabisulfit', width: 104, header: true, align: TextAlign.right),
          _cell('NaOH', width: 64, header: true, align: TextAlign.right),
          _cell('Teški metali', width: 88, header: true, align: TextAlign.center),
          _cell('pH', width: 48, header: true, align: TextAlign.center),
          _cell('Temperatura', width: 88, header: true, align: TextAlign.right),
          _cell('Operater', width: 120, header: true),
          _cell('Status', width: 88, header: true),
          _cell('Detalji', width: 88, header: true, align: TextAlign.center),
        ],
      );
    }
    return Row(
      children: [
        _cell('Datum', width: 88, header: true),
        _cell('Vrijeme', width: 56, header: true),
        _cell('Radna kada', width: 140, header: true),
        _cell('Hemikalija', width: 140, header: true),
        _cell('Količina', width: 72, header: true, align: TextAlign.right),
        _cell('Jedinica', width: 72, header: true),
        _cell('Procesno područje', width: 140, header: true),
        _cell('Koncentracija', width: 120, header: true),
        _cell('Lot / šarža', width: 120, header: true),
        _cell('Razlog', width: 120, header: true),
        _cell('Operater', width: 120, header: true),
        _cell('Status', width: 88, header: true),
        _cell('Detalji', width: 88, header: true, align: TextAlign.center),
      ],
    );
  }

  Widget _dataRow(ProfileDrivenEvidenceListItem item, int index) {
    final theme = Theme.of(context);
    final s = item.summaryFields;
    final bg = index.isEven
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);

    Widget rowContent;
    if (_processProfileType == _profileWastewaterTreatment) {
      rowContent = Row(
        children: [
          _cell(formatEvidenceDateShort(item.endedAt), width: 88),
          _cell(formatEvidenceTime(item.endedAt), width: 56),
          _cell(s.reactorNumber ?? '—', width: 64, align: TextAlign.center),
          _cell(s.treatmentPointName ?? '—', width: 160),
          _cell(formatFieldValue(s.quantity), width: 96, align: TextAlign.right),
          _cell(s.unit ?? '—', width: 72),
          _cell(formatFieldValue(s.limeQuantity), width: 64, align: TextAlign.right),
          _cell(
            formatFieldValue(s.sodiumMetabisulfiteQuantity),
            width: 104,
            align: TextAlign.right,
          ),
          _cell(
            formatFieldValue(s.sodiumHydroxideQuantity),
            width: 64,
            align: TextAlign.right,
          ),
          _cell(
            formatHeavyMetalsLabel(s.heavyMetalsPresent),
            width: 88,
            align: TextAlign.center,
          ),
          _cell(formatFieldValue(s.phValue), width: 48, align: TextAlign.center),
          _cell(
            s.temperatureC == null
                ? '—'
                : '${formatFieldValue(s.temperatureC)} °C',
            width: 88,
            align: TextAlign.right,
          ),
          _cell(_operatorLabel(item), width: 120),
          _statusCell(item.status, width: 88),
          _detailCell(item, width: 88),
        ],
      );
    } else {
      rowContent = Row(
        children: [
          _cell(formatEvidenceDateShort(item.endedAt), width: 88),
          _cell(formatEvidenceTime(item.endedAt), width: 56),
          _cell(s.workBathName ?? '—', width: 140),
          _cell(s.chemicalName ?? '—', width: 140),
          _cell(formatFieldValue(s.quantity), width: 72, align: TextAlign.right),
          _cell(s.unit ?? '—', width: 72),
          _cell(s.processAreaName ?? '—', width: 140),
          _cell(s.concentrationSnapshot ?? '—', width: 120),
          _cell(s.chemicalLot ?? '—', width: 120),
          _cell(s.dosingReason ?? '—', width: 120),
          _cell(_operatorLabel(item), width: 120),
          _statusCell(item.status, width: 88),
          _detailCell(item, width: 88),
        ],
      );
    }

    return Material(
      color: bg,
      child: InkWell(
        onTap: () => _openDetail(item),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: rowContent,
        ),
      ),
    );
  }

  Widget _buildTable() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '${_items.length} zapisa',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalHeaderController,
              child: SizedBox(
                width: _tableMinWidth,
                height: 46,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _headerRow(),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: Scrollbar(
              controller: _verticalBodyController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalBodyController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalBodyController,
                  child: SizedBox(
                    width: _tableMinWidth,
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          _dataRow(_items[i], i),
                      ],
                    ),
                  ),
                ),
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
