import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/internal_audit_models.dart';
import '../services/internal_audit_callable_service.dart';
import '../widgets/qms_iatf_help.dart';
import 'internal_audit_create_screen.dart';
import 'internal_audit_detail_screen.dart';

String _auditTypeHr(String t) {
  switch (t) {
    case 'process':
      return 'Proces';
    case 'product':
      return 'Proizvod';
    case 'system':
      return 'Sustav';
    default:
      return t;
  }
}

String _auditStatusHr(String s) {
  switch (s) {
    case 'open':
      return 'Otvoren';
    case 'closed':
      return 'Zatvoren';
    default:
      return s;
  }
}

/// Lista internih auditâ (Callable [listInternalAudits]).
class InternalAuditListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const InternalAuditListScreen({super.key, required this.companyData});

  @override
  State<InternalAuditListScreen> createState() => _InternalAuditListScreenState();
}

class _InternalAuditListScreenState extends State<InternalAuditListScreen> {
  final _svc = InternalAuditCallableService();
  bool _loading = true;
  String? _error;
  var _rows = const <InternalAuditListRow>[];
  /// Prazan string = svi; `open` / `closed`.
  String _statusFilter = '';

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
      final rows = await _svc.listInternalAudits(
        companyId: cid,
        statusFilter: _statusFilter.isEmpty ? null : _statusFilter,
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

  Future<void> _openCreate() async {
    final r = await Navigator.push<({String auditId, String auditCode})?>(
      context,
      MaterialPageRoute(
        builder: (_) => InternalAuditCreateScreen(companyData: widget.companyData),
      ),
    );
    if (r != null && mounted) {
      await _load();
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => InternalAuditDetailScreen(
            companyData: widget.companyData,
            auditId: r.auditId,
          ),
        ),
      );
      if (mounted) await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interni audit'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Interni audit (IATF 9.2)',
            message: QmsIatfStrings.listInternalAudits,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Svi'),
                    selected: _statusFilter.isEmpty,
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _statusFilter = '');
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Otvoreni'),
                    selected: _statusFilter == 'open',
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _statusFilter = 'open');
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Zatvoreni'),
                    selected: _statusFilter == 'closed',
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _statusFilter = 'closed');
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Novi audit'),
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
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      );
    }
    if (_rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _statusFilter.isEmpty
                ? 'Nema internih auditâ. Započni s „Novi audit”.'
                : 'Nema auditâ s odabranim statusom (uzorkom do limita).',
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
            r.auditCode.isNotEmpty ? r.auditCode : r.id,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${_auditTypeHr(r.auditType)} · ${r.auditDate} · ${_auditStatusHr(r.status)}\n'
            '${r.title}\n'
            'Auditor: ${r.auditorName} · ${r.department}'
            '${r.plantKey != null && r.plantKey!.isNotEmpty ? "\nPogon: ${r.plantKey}" : ""}'
            '${r.updatedAt != null && r.updatedAt!.isNotEmpty ? "\nAžurirano: ${r.updatedAt}" : ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => InternalAuditDetailScreen(
                  companyData: widget.companyData,
                  auditId: r.id,
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
