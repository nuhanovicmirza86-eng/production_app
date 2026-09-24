import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../widgets/ncr_list_status_card.dart';
import '../widgets/qms_iatf_help.dart';
import '../services/quality_callable_service.dart';
import 'ncr_detail_screen.dart';

/// NCR lista — Callable [listQmsNonConformances].
class NcrListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const NcrListScreen({super.key, required this.companyData});

  @override
  State<NcrListScreen> createState() => _NcrListScreenState();
}

class _NcrListScreenState extends State<NcrListScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  var _rows = const <QmsNcrRow>[];

  /// Prazno = svi; `customer` | `supplier` | `internal`.
  String _sourceFilter = '';

  /// `open` | `closed` | `dismissed` | `all` — default otvoreni.
  String _statusFilter = 'open';

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _svc.listNonConformances(
        companyId: cid,
        statusFilter: _statusFilter,
        sourceFilter: _sourceFilter.isEmpty ? null : _sourceFilter,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  void _setSourceFilter(String value) {
    if (_sourceFilter == value) return;
    setState(() => _sourceFilter = value);
    _load();
  }

  void _setStatusFilter(String value) {
    if (_statusFilter == value) return;
    setState(() => _statusFilter = value);
    _load();
  }

  String _emptyMessage() {
    switch (_statusFilter) {
      case 'closed':
        return 'Nema zatvorenih NCR zapisa.';
      case 'dismissed':
        return 'Nema odbačenih NCR zapisa.';
      case 'all':
        return 'Nema NCR zapisa u uzorku.';
      case 'open':
      default:
        return 'Nema otvorenih NCR zapisa.';
    }
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelect,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        if (!v) return;
        onSelect();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NCR - Neusklađenosti'),
        actions: [
          QmsIatfInfoIcon(
            title: 'NCR',
            message: QmsIatfStrings.listNcr,
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'Izvor',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip(
                  label: 'Svi izvori',
                  selected: _sourceFilter.isEmpty,
                  onSelect: () => _setSourceFilter(''),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Kupac',
                  selected: _sourceFilter == 'customer',
                  onSelect: () => _setSourceFilter('customer'),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Dobavljač',
                  selected: _sourceFilter == 'supplier',
                  onSelect: () => _setSourceFilter('supplier'),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Kontrola',
                  selected: _sourceFilter == 'internal',
                  onSelect: () => _setSourceFilter('internal'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Text(
              'Status',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip(
                  label: 'Otvoreno',
                  selected: _statusFilter == 'open',
                  onSelect: () => _setStatusFilter('open'),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Zatvoreno',
                  selected: _statusFilter == 'closed',
                  onSelect: () => _setStatusFilter('closed'),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Odbačeno',
                  selected: _statusFilter == 'dismissed',
                  onSelect: () => _setStatusFilter('dismissed'),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'Svi statusi',
                  selected: _statusFilter == 'all',
                  onSelect: () => _setStatusFilter('all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      );
    }
    if (_rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _emptyMessage(),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _rows.length,
      itemBuilder: (context, i) {
        final r = _rows[i];
        return NcrListStatusCard(
          row: r,
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => NcrDetailScreen(
                  companyData: widget.companyData,
                  ncrId: r.id,
                ),
              ),
            );
            if (mounted) await _load();
          },
        );
      },
    );
  }
}
