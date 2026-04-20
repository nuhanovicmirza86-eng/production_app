import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';
import 'capa_detail_screen.dart';

class _NcrAttRow {
  _NcrAttRow({String label = '', String url = ''})
    : label = TextEditingController(text: label),
      url = TextEditingController(text: url);

  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}

/// Detalj NCR-a + povezane CAPA + prilozi (https — obavezni pri zatvaranju/odbacivanju).
class NcrDetailScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String ncrId;

  const NcrDetailScreen({
    super.key,
    required this.companyData,
    required this.ncrId,
  });

  @override
  State<NcrDetailScreen> createState() => _NcrDetailScreenState();
}

class _NcrDetailScreenState extends State<NcrDetailScreen> {
  final _svc = QualityCallableService();
  final _description = TextEditingController();
  final _containment = TextEditingController();

  final List<_NcrAttRow> _attachmentRows = [];

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ncr;
  var _capaRows = const <QmsCapaRow>[];

  String _status = 'OPEN';
  String _severity = 'MEDIUM';
  bool _saving = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  static const _statuses = [
    'OPEN',
    'UNDER_REVIEW',
    'CONTAINED',
    'CLOSED',
    'DISMISSED',
  ];

  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    _containment.dispose();
    for (final r in _attachmentRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _disposeAttachmentRows() {
    for (final r in _attachmentRows) {
      r.dispose();
    }
    _attachmentRows.clear();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final n = await _svc.getQmsNonConformanceMap(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      final caps = await _svc.listCapaForNcr(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      if (!mounted) return;
      _description.text = (n['description'] ?? '').toString();
      _containment.text = (n['containmentAction'] ?? '').toString();
      final st = (n['status'] ?? 'OPEN').toString().toUpperCase();
      _status = _statuses.contains(st) ? st : 'OPEN';
      final sev = (n['severity'] ?? 'MEDIUM').toString().toUpperCase();
      _severity = _severities.contains(sev) ? sev : 'MEDIUM';

      _disposeAttachmentRows();
      final raw = n['attachments'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            _attachmentRows.add(
              _NcrAttRow(
                label: (m['label'] ?? '').toString(),
                url: (m['url'] ?? '').toString(),
              ),
            );
          }
        }
      }

      setState(() {
        _ncr = n;
        _capaRows = caps;
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

  List<Map<String, String>> _buildAttachmentsPayload() {
    final out = <Map<String, String>>[];
    for (final r in _attachmentRows) {
      final label = r.label.text.trim();
      final url = r.url.text.trim();
      if (label.isEmpty && url.isEmpty) continue;
      if (label.isEmpty || url.isEmpty) {
        throw StateError('Svaki prilog mora imati naziv i https URL.');
      }
      if (!url.toLowerCase().startsWith('https://')) {
        throw StateError('URL mora početi s https://');
      }
      out.add({'label': label, 'url': url});
    }
    return out;
  }

  Future<void> _save() async {
    late final List<Map<String, String>> att;
    try {
      att = _buildAttachmentsPayload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return;
    }
    if ((_status == 'CLOSED' || _status == 'DISMISSED') && att.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Za status Zatvoreno / Odbačeno potreban je barem jedan prilog (https).',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _svc.updateQmsNonConformance(
        companyId: _cid,
        ncrId: widget.ncrId,
        status: _status,
        containmentAction: _containment.text,
        description: _description.text,
        severity: _severity,
        attachments: att,
      );
      if (!mounted) return;
      final auto = res['capaAutoCreated'] == true;
      final idCapa = res['actionPlanId']?.toString();
      if (auto && idCapa != null && idCapa.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'NCR spremljen. Automatski je otvorena CAPA za ovaj NCR.',
            ),
            action: SnackBarAction(
              label: 'Otvori CAPA',
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CapaDetailScreen(
                      companyData: widget.companyData,
                      actionPlanId: idCapa,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NCR je spremljen.')),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url.trim());
    if (u == null) return;
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _createCapa() async {
    final titleCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova CAPA za ovaj NCR'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Naslov CAPA *',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kreiraj')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    try {
      final id = await _svc.createQmsCapaForNcr(
        companyId: _cid,
        ncrId: widget.ncrId,
        title: title,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CapaDetailScreen(
            companyData: widget.companyData,
            actionPlanId: id,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _ncr == null
        ? widget.ncrId
        : ((_ncr!['ncrCode'] ?? widget.ncrId).toString());
    return Scaffold(
      appBar: AppBar(title: Text('NCR $code')),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _createCapa,
              icon: const Icon(Icons.add_task),
              label: const Text('Nova CAPA'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_ncr != null) ...[
                    Text(
                      'Izvor: ${_ncr!['source'] ?? ''} · ref: ${_ncr!['referenceType'] ?? ''} ${_ncr!['referenceId'] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ncr_st_$_status'),
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: _statuses
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ncr_sev_$_severity'),
                      initialValue: _severity,
                      decoration: const InputDecoration(
                        labelText: 'Ozbiljnost',
                        border: OutlineInputBorder(),
                      ),
                      items: _severities
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _severity = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _containment,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Containment / privremena mjera',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LOT: ${_ncr!['lotId'] ?? '—'} · Nalog: ${_ncr!['productionOrderId'] ?? '—'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Prilozi (naziv + https URL)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Za Zatvoreno ili Odbačeno potreban je barem jedan prilog. '
                      'Učitaj datoteku u Storage ili drugi sustav i zalijepi javni https link.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _attachmentRows.add(_NcrAttRow()));
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Dodaj red priloga'),
                    ),
                    ..._attachmentRows.asMap().entries.map((e) {
                      final i = e.key;
                      final r = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: r.label,
                                decoration: const InputDecoration(
                                  labelText: 'Naziv',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: r.url,
                                decoration: const InputDecoration(
                                  labelText: 'https://…',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Otvori u pregledniku',
                              onPressed: () {
                                final u = r.url.text.trim();
                                if (u.isNotEmpty) _openUrl(u);
                              },
                              icon: const Icon(Icons.open_in_new),
                            ),
                            IconButton(
                              tooltip: 'Ukloni',
                              onPressed: () {
                                setState(() {
                                  r.dispose();
                                  _attachmentRows.removeAt(i);
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Spremanje…' : 'Spremi NCR'),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Povezane CAPA',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_capaRows.isEmpty)
                      Text(
                        'Nema CAPA zapisa. Koristi „Nova CAPA” ili prijelaz u status Pregled / Contained za automatsko otvaranje.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ..._capaRows.map((r) {
                        return Card(
                          child: ListTile(
                            title: Text(r.title.isEmpty ? r.id : r.title),
                            subtitle: Text('${r.status} · ${r.id}'),
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
                              await _load();
                            },
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
    );
  }
}
