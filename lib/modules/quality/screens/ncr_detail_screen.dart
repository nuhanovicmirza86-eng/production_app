import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_iatf_help.dart';
import 'capa_detail_screen.dart';
import 'qms_methodology_reference_screen.dart';

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
  final _reactionPlan = TextEditingController();
  final _capaWaiverReason = TextEditingController();

  final List<_NcrAttRow> _attachmentRows = [];

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ncr;
  var _capaRows = const <QmsCapaRow>[];

  String _status = 'OPEN';
  String _severity = 'MEDIUM';
  bool _saving = false;
  bool _holdingLot = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool _hasLogisticsModule() {
    final raw = widget.companyData['enabledModules'];
    if (raw is List) {
      final list =
          raw.map((e) => e.toString().trim().toLowerCase()).toList();
      if (list.isEmpty) return false;
      return list.contains('logistics');
    }
    return false;
  }

  String? get _ncrLotIdForHold {
    final v = _ncr?['lotId']?.toString().trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

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
    _reactionPlan.dispose();
    _capaWaiverReason.dispose();
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
      _reactionPlan.text = (n['reactionPlan'] ?? '').toString();
      final st = (n['status'] ?? 'OPEN').toString().toUpperCase();
      _status = _statuses.contains(st) ? st : 'OPEN';
      final sev = (n['severity'] ?? 'MEDIUM').toString().toUpperCase();
      _severity = _severities.contains(sev) ? sev : 'MEDIUM';
      _capaWaiverReason.text = (n['capaWaiverReason'] ?? '').toString();

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

  Future<void> _applyWmsHoldOnLot() async {
    final lot = _ncrLotIdForHold;
    if (lot == null || _holdingLot) return;
    setState(() => _holdingLot = true);
    try {
      final refId = _ncr?['referenceId']?.toString().trim();
      final refType = _ncr?['referenceType']?.toString().trim().toLowerCase();
      final insId = refType == 'inspection_result' ? refId : null;
      final r = await _svc.applyQmsHoldOnInventoryLot(
        companyId: _cid,
        lotId: lot,
        ncrId: widget.ncrId,
        inspectionResultId: insId,
        sourceType: 'ncr',
      );
      if (!mounted) return;
      if (r.applied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lot zadržan u WMS (${r.lotDocId}).')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'WMS hold nije primijenjen: ${r.skipReason ?? "nepoznato"}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _holdingLot = false);
    }
  }

  bool _isPartnerClaimNcr(Map<String, dynamic> n) {
    final s = (n['source'] ?? '').toString().toUpperCase();
    return s == 'CUSTOMER' || s == 'SUPPLIER';
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

  /// Otvorena CAPA u smislu backend pravila (OPEN_CAPA_STATUSES).
  bool _hasOpenCapaLinked() {
    const open = {'open', 'in_progress', 'waiting_verification'};
    for (final r in _capaRows) {
      if (open.contains(r.status.toLowerCase())) return true;
    }
    return false;
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
    if ((_status == 'CLOSED' || _status == 'DISMISSED') &&
        (_severity == 'HIGH' || _severity == 'CRITICAL') &&
        !_hasOpenCapaLinked() &&
        _capaWaiverReason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Za HIGH/CRITICAL: potrebna je otvorena CAPA ili odstupanje (razlog) prije zatvaranja.',
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
        reactionPlan: _reactionPlan.text,
        description: _description.text,
        severity: _severity,
        attachments: att,
        capaWaiverReason: (_severity == 'HIGH' || _severity == 'CRITICAL')
            ? _capaWaiverReason.text.trim()
            : '',
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
      appBar: AppBar(
        title: Text('NCR $code'),
        actions: [
          IconButton(
            tooltip: 'Metodologija · IATF',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const QmsMethodologyReferenceScreen(),
                ),
              );
            },
          ),
          QmsIatfInfoIcon(
            title: 'NCR',
            message: QmsIatfStrings.detailNcr,
          ),
        ],
      ),
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
                    if (_isPartnerClaimNcr(_ncr!)) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_ncr!['source'] ?? '').toString().toUpperCase() ==
                                        'CUSTOMER'
                                    ? 'Kupac'
                                    : 'Dobavljač',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (_ncr!['partnerDisplayName'] ?? '').toString().isEmpty
                                    ? (_ncr!['partnerId'] ?? '').toString()
                                    : (_ncr!['partnerDisplayName'] ?? '').toString(),
                              ),
                              if ((_ncr!['externalClaimRef'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Vanjski broj: ${_ncr!['externalClaimRef']}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if ((_ncr!['supplierId'] ?? '').toString().trim().isNotEmpty ||
                        (_ncr!['customerId'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        [
                          'Sljedljivost (kontrola)',
                          if ((_ncr!['customerId'] ?? '').toString().trim().isNotEmpty)
                            'kupac: ${_ncr!['customerId']}',
                          if ((_ncr!['supplierId'] ?? '').toString().trim().isNotEmpty)
                            'dobavljač: ${_ncr!['supplierId']}',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
                      decoration: InputDecoration(
                        labelText: 'Ozbiljnost',
                        border: const OutlineInputBorder(),
                        suffixIcon: QmsIatfInfoIcon(
                          title: 'Ozbiljnost',
                          message: QmsIatfStrings.termSeverity,
                          size: 20,
                        ),
                      ),
                      items: _severities
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _severity = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_severity == 'HIGH' || _severity == 'CRITICAL') ...[
                      TextFormField(
                        controller: _capaWaiverReason,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Odstupanje od CAPA (razlog, ako nije otvorena CAPA)',
                          hintText:
                              'Obavezno pri zatvaranju/odbacivanju ako nema otvorene CAPA',
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          suffixIcon: QmsIatfInfoIcon(
                            title: 'HIGH / CRITICAL',
                            message: QmsIatfStrings.termCapaGateHighSeverity,
                            size: 20,
                          ),
                        ),
                      ),
                      if (!_hasOpenCapaLinked() &&
                          _capaWaiverReason.text.trim().isEmpty &&
                          (_status == 'CLOSED' || _status == 'DISMISSED'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Nema otvorene CAPA — unesi odstupanje ili otvori CAPA prije spremanja.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    QmsIatfSectionTitle(
                      label: 'Containment / privremena mjera',
                      iatfTitle: 'Containment',
                      iatfMessage: QmsIatfStrings.termContainment,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _containment,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QmsIatfSectionTitle(
                      label: 'Reakcijski plan (brzi odgovor)',
                      iatfTitle: 'Reakcijski plan',
                      iatfMessage: QmsIatfStrings.termReactionPlan,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reactionPlan,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'LOT: ${_ncr!['lotId'] ?? '—'} · Nalog: ${_ncr!['productionOrderId'] ?? '—'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        QmsIatfInfoIcon(
                          title: 'LOT i sljedljivost',
                          message:
                              '${QmsIatfStrings.termLot}\n\n${QmsIatfStrings.termTraceability}',
                          size: 20,
                        ),
                      ],
                    ),
                    if (_hasLogisticsModule() &&
                        (_ncrLotIdForHold ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: _holdingLot ? null : _applyWmsHoldOnLot,
                          icon: _holdingLot
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.pause_circle_outline),
                          label: const Text('Zadrži lot u WMS (hold)'),
                        ),
                      ),
                    ],
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
