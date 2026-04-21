import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../production/products/services/product_service.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_display_formatters.dart';
import '../widgets/qms_iatf_help.dart';

/// Povijest rezultata kontrola — Callable [listQmsInspectionResults].
class InspectionResultsListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const InspectionResultsListScreen({super.key, required this.companyData});

  @override
  State<InspectionResultsListScreen> createState() =>
      _InspectionResultsListScreenState();
}

class _InspectionResultsListScreenState extends State<InspectionResultsListScreen> {
  final _svc = QualityCallableService();
  final _productService = ProductService();
  bool _loading = true;
  String? _error;
  var _rows = const <QmsInspectionResultRow>[];
  final Map<String, String> _productLineById = {};
  final Map<String, String> _planTitleById = {};

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
      final rows = await _svc.listInspectionResults(companyId: cid);
      final products = await _productService.getProducts(companyId: cid, limit: 500);
      final plans = await _svc.listInspectionPlans(companyId: cid);
      final pl = <String, String>{};
      for (final m in products) {
        final id = (m['productId'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        pl[id] = QmsDisplayFormatters.productLine(m);
      }
      final pm = <String, String>{};
      for (final p in plans) {
        final code = (p.inspectionPlanCode ?? '').trim();
        pm[p.id] = code.isNotEmpty ? code : 'Plan kontrole';
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _productLineById
          ..clear()
          ..addAll(pl);
        _planTitleById
          ..clear()
          ..addAll(pm);
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

  bool _isNok(String r) => r.trim().toUpperCase() == 'NOK';

  String _resultLabel(String r) {
    final u = r.trim().toUpperCase();
    if (u == 'OK') return 'U redu';
    if (u == 'NOK') return 'Nije u redu';
    return r;
  }

  /// Ne prikazuj dugačke interne ID-eve (npr. Firestore dokument).
  String _traceForDisplay(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return '—';
    if (t.length >= 22 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(t)) {
      return '—';
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Povijest kontrola'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Povijest kontrola',
            message: QmsIatfStrings.listInspectionResults,
          ),
          IconButton(
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            )
          : _rows.isEmpty
          ? Center(
              child: Text(
                'Nema zapisanih rezultata kontrola.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rows.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = _rows[i];
                final nok = _isNok(r.overallResult);
                final when = r.inspectedAtIso ?? '—';
                final planLine =
                    _planTitleById[r.inspectionPlanId] ?? 'Plan kontrole';
                final prodLine = _productLineById[r.productId] ??
                    'Proizvod (nije u šifarniku)';
                final lot = _traceForDisplay(r.lotId);
                final po = _traceForDisplay(r.productionOrderId);
                return Card(
                  child: ListTile(
                    title: Text(
                      '${_resultLabel(r.overallResult)} · ${QmsDisplayFormatters.inspectionType(r.inspectionType)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: nok ? cs.error : cs.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Plan: $planLine\n'
                      'Proizvod: $prodLine\n'
                      'LOT: $lot · Nalog: $po\n'
                      '$when',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
