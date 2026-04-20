import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';

class InspectionPlansListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const InspectionPlansListScreen({super.key, required this.companyData});

  @override
  State<InspectionPlansListScreen> createState() =>
      _InspectionPlansListScreenState();
}

class _InspectionPlansListScreenState extends State<InspectionPlansListScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  var _rows = const <QmsInspectionPlanRow>[];

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
      final rows = await _svc.listInspectionPlans(companyId: cid);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planovi inspekcije')),
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
            'Nema planova inspekcije.',
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
            r.inspectionType,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Status: ${r.status}\n'
            'Proizvod: ${r.productId}\n'
            'Kontrolni plan: ${r.controlPlanId}'
            '${r.updatedAtIso != null ? "\n${r.updatedAtIso}" : ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
