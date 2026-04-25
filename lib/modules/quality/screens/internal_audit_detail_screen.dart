import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/internal_audit_models.dart';
import '../services/internal_audit_callable_service.dart';

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

String _findingTypeHr(String t) {
  switch (t) {
    case 'minor':
      return 'Manji';
    case 'major':
      return 'Veći';
    case 'critical':
      return 'Kritičan';
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
      return s.isEmpty ? 'Otvoren' : s;
  }
}

/// Detalj audita + nalazi.
class InternalAuditDetailScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String auditId;

  const InternalAuditDetailScreen({
    super.key,
    required this.companyData,
    required this.auditId,
  });

  @override
  State<InternalAuditDetailScreen> createState() =>
      _InternalAuditDetailScreenState();
}

class _InternalAuditDetailScreenState extends State<InternalAuditDetailScreen> {
  final _svc = InternalAuditCallableService();
  bool _loading = true;
  String? _error;
  InternalAuditBundle? _bundle;

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
        _error = 'Nedostaje podatak o kompaniji.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await _svc.getInternalAuditBundle(
        companyId: cid,
        auditId: widget.auditId,
      );
      if (!mounted) return;
      setState(() {
        _bundle = b;
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

  Future<void> _addFinding() async {
    final b = _bundle;
    if (b == null) return;
    if (!_isAuditOpen(b.audit)) return;
    final cid = _cid;
    var findingType = 'minor';
    final desc = TextEditingController();
    final capa = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novi nalaz'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, setSt) {
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ozbiljnost',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: findingType,
                        items: const [
                          DropdownMenuItem(
                            value: 'minor',
                            child: Text('Manji'),
                          ),
                          DropdownMenuItem(
                            value: 'major',
                            child: Text('Veći'),
                          ),
                          DropdownMenuItem(
                            value: 'critical',
                            child: Text('Kritičan'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setSt(() => findingType = v);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capa,
                decoration: const InputDecoration(
                  labelText: 'ID CAPA (opcionalno)',
                  border: OutlineInputBorder(),
                  helperText: 'Za sljedivost prema postojećem akcijskom planu',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      desc.dispose();
      capa.dispose();
      return;
    }
    if (desc.text.trim().isEmpty) {
      desc.dispose();
      capa.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opis je obavezan.')),
        );
      }
      return;
    }
    try {
      await _svc.addInternalAuditFinding(
        companyId: cid,
        auditId: widget.auditId,
        findingType: findingType,
        description: desc.text.trim(),
        linkedCapaId: capa.text.trim().isEmpty ? null : capa.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      desc.dispose();
      capa.dispose();
    }
    if (mounted) await _load();
  }

  bool _isAuditOpen(InternalAuditHeader a) {
    final s = a.status.trim().toLowerCase();
    return s.isEmpty || s == 'open';
  }

  Future<void> _setAuditStatus(String next) async {
    final cid = _cid;
    if (cid.isEmpty) return;
    try {
      await _svc.updateInternalAuditStatus(
        companyId: cid,
        auditId: widget.auditId,
        status: next,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next == 'closed' ? 'Audit je zatvoren.' : 'Audit je ponovo otvoren.',
            ),
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  Future<void> _confirmClose() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zatvori audit?'),
        content: const Text(
          'Nakon zatvaranja nije moguće dodavati nove nalaze dok audit ponovo ne otvoriš.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _setAuditStatus('closed');
    }
  }

  Future<void> _confirmReopen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ponovo otvori audit?'),
        content: const Text('Moći ćeš ponovo dodavati nalaze.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Otvori'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _setAuditStatus('open');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _bundle?.audit;
    final canAdd = a != null && _isAuditOpen(a);
    return Scaffold(
      appBar: AppBar(
        title: Text(a == null || a.auditCode.isEmpty ? 'Interni audit' : a.auditCode),
        actions: [
          if (!_loading && _error == null && canAdd)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'Dodaj nalaz',
              onPressed: _addFinding,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final b = _bundle!;
    final a = b.audit;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            a.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${_auditTypeHr(a.auditType)} · ${a.auditDate} · ${_auditStatusHr(a.status)}\n'
            'Auditor: ${a.auditorName}\nOdjel: ${a.department}'
            '${a.plantKey != null && a.plantKey!.isNotEmpty ? "\nPogon: ${a.plantKey}" : ""}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          if (_isAuditOpen(a))
            FilledButton.tonalIcon(
              onPressed: _confirmClose,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Zatvori audit'),
            )
          else
            OutlinedButton.icon(
              onPressed: _confirmReopen,
              icon: const Icon(Icons.unarchive_outlined),
              label: const Text('Ponovo otvori audit'),
            ),
          if (a.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Napomene', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(a.notes),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Nalazi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (_isAuditOpen(a))
                TextButton.icon(
                  onPressed: _addFinding,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj'),
                ),
            ],
          ),
          if (!_isAuditOpen(a))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Audit je zatvoren — nema novih nalaza dok se ne otvori.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
          if (b.findings.isEmpty)
            Text(
              'Još nema nalaza.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            ...b.findings.map((f) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${f.findingCode} · ${_findingTypeHr(f.findingType)} · ${f.status}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(f.description),
                      if (f.linkedCapaId != null &&
                          f.linkedCapaId!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Povezana CAPA: ${f.linkedCapaId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
