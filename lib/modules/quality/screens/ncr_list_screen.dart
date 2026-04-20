import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';

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
        _error = 'Nedostaje companyId.';
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
          IconButton(
            tooltip: _openOnly
                ? 'Prikaži sve (uzorkom do limita)'
                : 'Samo otvoreni statusi',
            icon: Icon(_openOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: _toggleOpenOnly,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
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
            '${r.description}'
            '${r.lotId != null ? "\nLOT: ${r.lotId}" : ""}'
            '${r.productionOrderId != null ? "\nNalog: ${r.productionOrderId}" : ""}'
            '${r.createdAtIso != null ? "\n${r.createdAtIso}" : ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
