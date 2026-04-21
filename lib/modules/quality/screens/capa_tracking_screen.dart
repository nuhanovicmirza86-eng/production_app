import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../widgets/qms_iatf_help.dart';
import '../services/quality_callable_service.dart';
import 'capa_detail_screen.dart';

/// CAPA — action_plans s sourceType = non_conformance (Callable [listQmsOpenCapa]).
class CapaTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const CapaTrackingScreen({super.key, required this.companyData});

  @override
  State<CapaTrackingScreen> createState() => _CapaTrackingScreenState();
}

class _CapaTrackingScreenState extends State<CapaTrackingScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  var _rows = const <QmsCapaRow>[];

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
      final rows = await _svc.listOpenCapa(companyId: cid);
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
        title: const Text('CAPA — praćenje'),
        actions: [
          QmsIatfInfoIcon(
            title: 'CAPA',
            message: QmsIatfStrings.listCapa,
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
            'Nema otvorenih CAPA zapisa (action_plans · non_conformance).',
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
            r.title.isNotEmpty ? r.title : r.id,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Status: ${r.status}\n'
            'NCR ref: ${r.sourceRefId}'
            '${r.dueDateIso != null ? "\nRok: ${r.dueDateIso}" : ""}'
            '${r.responsibleUserId != null ? "\nOdgovoran: ${r.responsibleUserId}" : ""}'
            '${r.rootCause != null ? "\n${r.rootCause}" : ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CapaDetailScreen(
                  companyData: widget.companyData,
                  actionPlanId: r.id,
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
