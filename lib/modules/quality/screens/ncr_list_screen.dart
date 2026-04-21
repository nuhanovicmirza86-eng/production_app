import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../widgets/qms_iatf_help.dart';
import '../services/quality_callable_service.dart';
import 'ncr_detail_screen.dart';

/// NCR lista — Callable [listQmsNonConformances] (default: samo otvoreni).
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
  bool _openOnly = true;

  /// Prazno = svi; `customer` | `supplier` | `internal` (PROCESS/INCOMING).
  String _sourceFilter = '';

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
        openOnly: _openOnly,
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

  Future<void> _toggleOpenOnly() async {
    setState(() => _openOnly = !_openOnly);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NCR — neskladi'),
        actions: [
          QmsIatfInfoIcon(
            title: 'NCR',
            message: QmsIatfStrings.listNcr,
          ),
          IconButton(
            tooltip: _openOnly
                ? 'Prikaži sve (uzorkom do limita)'
                : 'Samo otvoreni statusi',
            icon: Icon(_openOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: _toggleOpenOnly,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Svi izvori'),
                  selected: _sourceFilter.isEmpty,
                  onSelected: (v) {
                    if (!v) return;
                    setState(() => _sourceFilter = '');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Kupac'),
                  selected: _sourceFilter == 'customer',
                  onSelected: (v) {
                    if (!v) return;
                    setState(() => _sourceFilter = 'customer');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Dobavljač'),
                  selected: _sourceFilter == 'supplier',
                  onSelected: (v) {
                    if (!v) return;
                    setState(() => _sourceFilter = 'supplier');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Inspekcija'),
                  selected: _sourceFilter == 'internal',
                  onSelected: (v) {
                    if (!v) return;
                    setState(() => _sourceFilter = 'internal');
                    _load();
                  },
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
            _openOnly
                ? 'Nema otvorenih NCR zapisa.'
                : 'Nema NCR zapisa u uzorku.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _rows.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = _rows[i];
        return ListTile(
          title: Text(
            r.ncrCode.isNotEmpty ? r.ncrCode : r.id,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${r.status} · ${r.severity} · ${r.source}\n'
            '${r.partnerDisplayName != null && r.partnerDisplayName!.trim().isNotEmpty ? "Partner: ${r.partnerDisplayName}\n" : ""}'
            '${r.externalClaimRef != null && r.externalClaimRef!.trim().isNotEmpty ? "Vanjski br.: ${r.externalClaimRef}\n" : ""}'
            '${r.description}'
            '${r.lotId != null ? "\nLOT: ${r.lotId}" : ""}'
            '${r.productionOrderId != null ? "\nNalog: ${r.productionOrderId}" : ""}'
            '${r.createdAtIso != null ? "\n${r.createdAtIso}" : ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
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
