import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../screens/ncr_recheck_execution_evidence_screen.dart';
import '../services/quality_callable_service.dart';
import '../utils/qms_ncr_display_labels.dart';

/// M1-I12-D — scoped ekran ponovne kontrole za kontrolu kvaliteta.
class NcrRecheckTaskScreen extends StatefulWidget {
  const NcrRecheckTaskScreen({
    super.key,
    required this.companyData,
    required this.ncrId,
    this.expectedCheckedQty,
  });

  final Map<String, dynamic> companyData;
  final String ncrId;
  final int? expectedCheckedQty;

  @override
  State<NcrRecheckTaskScreen> createState() => _NcrRecheckTaskScreenState();
}

class _NcrRecheckTaskScreenState extends State<NcrRecheckTaskScreen> {
  final _svc = QualityCallableService();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _ncr;

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();

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
      final res = await _svc.getQmsNonConformanceMap(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      if (!mounted) return;
      setState(() {
        _ncr = res;
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

  int? _expectedQtyFromNcr() {
    final rework = _ncr?['executionRework'];
    if (rework is Map) {
      final n = int.tryParse('${rework['toRecheckQty']}');
      if (n != null && n > 0) return n;
    }
    return widget.expectedCheckedQty;
  }

  String _displayCode() {
    return QmsNcrDisplayLabels.displayDocumentNumber(
      ncrDocumentNo: _ncr?['ncrDocumentNo']?.toString(),
      ncrCode: _ncr?['ncrCode']?.toString(),
    );
  }

  Future<void> _runRecheck() async {
    final expected = _expectedQtyFromNcr();
    final draft = await openNcrRecheckExecutionEvidence(
      context,
      expectedCheckedQty: expected,
    );
    if (draft == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _svc.recordNcrRecheckResult(
        companyId: _cid,
        ncrId: widget.ncrId,
        checkedQty: draft.checkedQty,
        okQty: draft.okQty,
        rejectedQty: draft.rejectedQty,
        separatedQty: draft.separatedQty,
        checkDescription: draft.checkDescription,
        note: draft.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.rejectedQty > 0
                ? 'Ishod spremljen — potrebna je nova odluka'
                : 'Ponovna kontrola odobrena',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    if (!ProductionAccessHelper.canRunNcrQualityRecheckRole(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ponovna kontrola')),
        body: const Center(
          child: Text(
            'Ponovnu kontrolu može izvršiti samo kontrola kvaliteta.',
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final expected = _expectedQtyFromNcr();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ponovna kontrola'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayCode(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dorada je završena — potrebna je ponovna kontrola '
                              'kvaliteta.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (expected != null && expected > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Komada za kontrolu: $expected',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _runRecheck,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fact_check_outlined),
                      label: const Text('Izvrši ponovnu kontrolu'),
                    ),
                  ],
                ),
    );
  }
}
