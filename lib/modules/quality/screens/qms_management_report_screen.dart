import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/qms_management_report_pdf.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_iatf_help.dart';

/// Korak 5 QMS: jedan strani pregled + PDF za vodstvo (NCR, CAPA, trend, PFMEA).
class QmsManagementReportScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const QmsManagementReportScreen({super.key, required this.companyData});

  @override
  State<QmsManagementReportScreen> createState() =>
      _QmsManagementReportScreenState();
}

class _QmsManagementReportScreenState extends State<QmsManagementReportScreen> {
  final _svc = QualityCallableService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;
  int _daysBack = 30;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _companyName =>
      (widget.companyData['companyName'] ?? widget.companyData['name'] ?? '')
          .toString()
          .trim();

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
      final r = await _svc.getQmsManagementReport(
        companyId: cid,
        daysBack: _daysBack,
      );
      if (!mounted) return;
      setState(() {
        _report = r;
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

  Future<void> _printPdf() async {
    final r = _report;
    if (r == null) return;
    try {
      final bytes = await QmsManagementReportPdf.buildPdfBytes(
        companyLabel: _companyName,
        companyId: _cid,
        report: r,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        name: 'qms_vodstvo_${_cid}_${_daysBack}d.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  int _i(dynamic x, [int d = 0]) {
    if (x is int) return x;
    return int.tryParse('$x') ?? d;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izvještaj za vodstvo'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Izvještaj za vodstvo',
            message: QmsIatfStrings.managementReport,
          ),
          if (_report != null && !_loading)
            IconButton(
              tooltip: 'PDF / štampa',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _printPdf,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _report == null
          ? const Center(child: Text('Nema podataka.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Razdoblje trenda inspekcija (OK/NOK)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 d')),
                      ButtonSegment(value: 30, label: Text('30 d')),
                      ButtonSegment(value: 90, label: Text('90 d')),
                    ],
                    selected: {_daysBack},
                    onSelectionChanged: (s) {
                      final v = s.first;
                      setState(() => _daysBack = v);
                      _load();
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sažetak',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _kv(
                    context,
                    'Kontrolni planovi',
                    '${_i(_report!['summary'] is Map ? (_report!['summary'] as Map)['controlPlanCount'] : 0)}',
                  ),
                  _kv(
                    context,
                    'Planovi inspekcije',
                    '${_i(_report!['summary'] is Map ? (_report!['summary'] as Map)['inspectionPlanCount'] : 0)}',
                  ),
                  _kv(
                    context,
                    'Otvoreni NCR',
                    '${_i(_report!['summary'] is Map ? (_report!['summary'] as Map)['openNcrCount'] : 0)}',
                  ),
                  _kv(
                    context,
                    'Otvorene CAPA',
                    '${_i(_report!['summary'] is Map ? (_report!['summary'] as Map)['openCapaCount'] : 0)}',
                  ),
                  _kv(
                    context,
                    'CAPA preko roka (otvorene)',
                    '${_i(_report!['capaOverdueCount'])}',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trend inspekcija (zadnjih $_daysBack dana)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _kv(
                    context,
                    'OK',
                    '${_i(_report!['inspectionTrend'] is Map ? (_report!['inspectionTrend'] as Map)['okCount'] : 0)}',
                  ),
                  _kv(
                    context,
                    'NOK',
                    '${_i(_report!['inspectionTrend'] is Map ? (_report!['inspectionTrend'] as Map)['nokCount'] : 0)}',
                  ),
                  _kv(
                    context,
                    'Ukupno u razdoblju',
                    '${_i(_report!['inspectionTrend'] is Map ? (_report!['inspectionTrend'] as Map)['totalInPeriod'] : 0)}',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Otvoreni NCR (pregled)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._ncrTiles(context, cs),
                  const SizedBox(height: 20),
                  Text(
                    'Otvorene CAPA (pregled)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._capaTiles(context, cs),
                  const SizedBox(height: 20),
                  Text(
                    'Top PFMEA po RPN',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._pfmeaTiles(context, cs),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _printPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Otvori PDF / štampu'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              k,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  List<Widget> _ncrTiles(BuildContext context, ColorScheme cs) {
    final raw = _report!['openNcrs'];
    if (raw is! List || raw.isEmpty) {
      return [
        Text(
          'Nema otvorenih NCR.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ];
    }
    return raw.map<Widget>((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          dense: true,
          title: Text(
            (m['ncrCode'] ?? m['id'] ?? '').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${m['status']} · ${m['severity']}\n${m['description'] ?? ''}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _capaTiles(BuildContext context, ColorScheme cs) {
    final raw = _report!['openCapas'];
    if (raw is! List || raw.isEmpty) {
      return [
        Text(
          'Nema otvorenih CAPA.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ];
    }
    return raw.map<Widget>((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final od = m['overdue'] == true;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: od ? cs.errorContainer.withOpacity(0.35) : null,
        child: ListTile(
          dense: true,
          title: Text(
            (m['title'] ?? m['id'] ?? '').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${m['status']} · rok: ${m['dueDate'] ?? '—'} · NCR: ${m['sourceRefId'] ?? '—'}'
            '${od ? ' · PREKORAČEN ROK' : ''}',
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _pfmeaTiles(BuildContext context, ColorScheme cs) {
    final raw = _report!['topPfmeaByRpn'];
    if (raw is! List || raw.isEmpty) {
      return [
        Text(
          'Nema PFMEA redova.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ];
    }
    return raw.map<Widget>((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          dense: true,
          title: Text('RPN ${m['rpn']} · AP ${m['ap']}'),
          subtitle: Text(
            '${m['processStep']} — ${m['failureMode']}\nproizvod: ${m['productId']}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList();
  }
}
