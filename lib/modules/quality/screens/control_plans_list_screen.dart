import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../widgets/qms_iatf_help.dart';
import '../services/quality_callable_service.dart';
import 'control_plan_edit_screen.dart';

/// Kontrolni planovi — lista preko Callable-a [listQmsControlPlans].
class ControlPlansListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ControlPlansListScreen({super.key, required this.companyData});

  @override
  State<ControlPlansListScreen> createState() => _ControlPlansListScreenState();
}

class _ControlPlansListScreenState extends State<ControlPlansListScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  var _rows = const <QmsControlPlanRow>[];

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
      final rows = await _svc.listControlPlans(companyId: cid);
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
      appBar: AppBar(
        title: const Text('Kontrolni planovi'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Kontrolni plan',
            message: QmsIatfStrings.listControlPlans,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => ControlPlanEditScreen(companyData: widget.companyData),
            ),
          );
          if (ok == true && mounted) await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Novi'),
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
            'Nema kontrolnih planova. Dodaj ih preko Callable-a (admin / menadžer / supervizor).',
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
        final code = (r.controlPlanCode ?? r.id).toString();
        final subtitle = '${r.status} · proizvod ${r.productId}'
            '${r.plantKey != null ? " · ${r.plantKey}" : ""}'
            '${r.updatedAtIso != null ? "\n${r.updatedAtIso}" : ""}';
        return ListTile(
          title: Text(r.title.isEmpty ? code : r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          isThreeLine: true,
          onTap: () async {
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => ControlPlanEditScreen(
                  companyData: widget.companyData,
                  controlPlanId: r.id,
                ),
              ),
            );
            if (ok == true && mounted) await _load();
          },
        );
      },
    );
  }
}
