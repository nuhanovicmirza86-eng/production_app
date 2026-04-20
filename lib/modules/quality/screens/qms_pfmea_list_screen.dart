import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_iatf_help.dart';
import '../widgets/qms_pickers.dart';
import 'qms_pfmea_edit_screen.dart';

/// Lista PFMEA redova (kolekcija `qms_pfmea_rows`, Callable).
class QmsPfmeaListScreen extends StatefulWidget {
  const QmsPfmeaListScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<QmsPfmeaListScreen> createState() => _QmsPfmeaListScreenState();
}

class _QmsPfmeaListScreenState extends State<QmsPfmeaListScreen> {
  final _svc = QualityCallableService();

  bool _loading = true;
  String? _error;
  var _rows = const <QmsPfmeaRow>[];
  String? _filterProductId;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _svc.listQmsPfmeaRows(
        companyId: _cid,
        productId: _filterProductId,
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

  Future<void> _pickProductFilter() async {
    final id = await showQmsProductPicker(
      context: context,
      companyId: _cid,
    );
    if (!mounted) return;
    setState(() {
      _filterProductId =
          (id == null || id.trim().isEmpty) ? null : id.trim();
    });
    await _load();
  }

  void _clearProductFilter() {
    setState(() => _filterProductId = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PFMEA (proces)'),
        actions: [
          QmsIatfInfoIcon(
            title: 'PFMEA u QMS-u',
            message: QmsIatfStrings.listPfmea,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => QmsPfmeaEditScreen(
                companyData: widget.companyData,
              ),
            ),
          );
          if (mounted) await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Novi red'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickProductFilter,
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text(
                    _filterProductId == null
                        ? 'Filtar: proizvod'
                        : 'Filtar: ${_filterProductId!.length > 12 ? "${_filterProductId!.substring(0, 12)}…" : _filterProductId}',
                  ),
                ),
                if (_filterProductId != null)
                  TextButton(
                    onPressed: _clearProductFilter,
                    child: const Text('Poništi filtar'),
                  ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              ),
            )
          else if (_rows.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Nema PFMEA redova. Dodaj novi ili promijeni filtar proizvoda.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          r.failureMode.isEmpty ? '(bez načina otkazivanja)' : r.failureMode,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            r.processStep,
                            'RPN ${r.rpn} · AP ${r.ap} · ${r.rowStatus}',
                            if (r.productId.isNotEmpty) 'Proizvod: ${r.productId}',
                          ].join('\n'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => QmsPfmeaEditScreen(
                                companyData: widget.companyData,
                                pfmeaRowId: r.id,
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
