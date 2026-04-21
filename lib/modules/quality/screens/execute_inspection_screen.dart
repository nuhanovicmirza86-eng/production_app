import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../production/products/services/product_service.dart';
import '../widgets/qms_display_formatters.dart';
import '../widgets/qms_iatf_help.dart';
import '../../production/qr/production_qr_resolver.dart';
import '../../production/qr/screens/production_qr_scan_screen.dart';
import '../models/qms_execution_models.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';

/// Odabir plana inspekcije → [getQmsInspectionExecutionContext] → unos mjerenja → [submitInspectionResult].
class ExecuteInspectionScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String? initialInspectionPlanId;

  /// Kad nema [initialInspectionPlanId], prvi se odabire plan s ovim tipom (npr. IN_PROCESS / FINAL).
  final String? preferredInspectionType;

  const ExecuteInspectionScreen({
    super.key,
    required this.companyData,
    this.initialInspectionPlanId,
    this.preferredInspectionType,
  });

  @override
  State<ExecuteInspectionScreen> createState() => _ExecuteInspectionScreenState();
}

class _ExecuteInspectionScreenState extends State<ExecuteInspectionScreen> {
  final _svc = QualityCallableService();
  final _productService = ProductService();
  final _lotId = TextEditingController();
  final _productionOrderId = TextEditingController();
  final _customerId = TextEditingController();
  final _supplierId = TextEditingController();

  bool _loadingPlans = true;
  String? _plansError;
  var _planRows = const <QmsInspectionPlanRow>[];
  final Map<String, String> _productLineById = {};

  String? _selectedPlanId;
  bool _loadingContext = false;
  String? _contextError;
  QmsInspectionExecutionContext? _ctx;
  String? _ctxProductLine;
  final Map<String, TextEditingController> _valueByRef = {};

  bool _submitting = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _defaultPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.initialInspectionPlanId;
    _loadPlans();
  }

  @override
  void dispose() {
    _lotId.dispose();
    _productionOrderId.dispose();
    _customerId.dispose();
    _supplierId.dispose();
    for (final c in _valueByRef.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _disposeMeasureControllers() {
    for (final c in _valueByRef.values) {
      c.dispose();
    }
    _valueByRef.clear();
  }

  /// Preferirani tip (npr. stanica prva/završna kontrola), inače prvi plan u listi.
  String? _firstMatchingPlanId(List<QmsInspectionPlanRow> rows) {
    if (rows.isEmpty) return null;
    final pref = widget.preferredInspectionType?.trim().toUpperCase();
    if (pref != null && pref.isNotEmpty) {
      for (final r in rows) {
        if (r.inspectionType.toUpperCase() == pref) return r.id;
      }
    }
    return rows.first.id;
  }

  /// Sken naloga (`po:v1`) ili WMS lota (`wmslot:v1`) → puni polja konteksta inspekcije.
  Future<void> _scanQr() async {
    final resolution = await Navigator.push<ProductionQrScanResolution>(
      context,
      MaterialPageRoute<ProductionQrScanResolution>(
        fullscreenDialog: true,
        builder: (_) => ProductionQrScanScreen(companyData: widget.companyData),
      ),
    );
    if (!mounted || resolution == null) return;
    switch (resolution.intent) {
      case ProductionQrIntent.productionOrderReferenceV1:
        final id = resolution.productionOrderId?.trim();
        if (id != null && id.isNotEmpty) {
          _productionOrderId.text = id;
        }
        break;
      case ProductionQrIntent.wmsLotDocV1:
        final lot = resolution.wmsLotDocId?.trim();
        if (lot != null && lot.isNotEmpty) {
          _lotId.text = lot;
        }
        break;
      default:
        break;
    }
    setState(() {});
  }

  Future<void> _loadPlans() async {
    final cid = _cid;
    if (cid.isEmpty) {
      setState(() {
        _loadingPlans = false;
        _plansError = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
      });
      return;
    }
    setState(() {
      _loadingPlans = true;
      _plansError = null;
    });
    try {
      final rows = await _svc.listInspectionPlans(companyId: cid);
      final products = await _productService.getProducts(
        companyId: cid,
        limit: 500,
      );
      _productLineById.clear();
      for (final m in products) {
        final pid = (m['productId'] ?? '').toString().trim();
        if (pid.isEmpty) continue;
        _productLineById[pid] = QmsDisplayFormatters.productLine(m);
      }
      if (!mounted) return;
      String? sel = _selectedPlanId;
      if (sel != null && sel.isNotEmpty && !rows.any((r) => r.id == sel)) {
        sel = _firstMatchingPlanId(rows);
      } else if ((sel == null || sel.isEmpty) && rows.isNotEmpty) {
        sel = _firstMatchingPlanId(rows);
      }
      setState(() {
        _planRows = rows;
        _selectedPlanId = sel;
        _loadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plansError = AppErrorMapper.toMessage(e);
        _loadingPlans = false;
      });
    }
  }

  Future<void> _loadExecutionContext() async {
    final planId = _selectedPlanId;
    final cid = _cid;
    if (planId == null || planId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi plan inspekcije.')),
      );
      return;
    }
    setState(() {
      _loadingContext = true;
      _contextError = null;
      _ctx = null;
      _ctxProductLine = null;
      _disposeMeasureControllers();
    });
    try {
      final ctx = await _svc.getInspectionExecutionContext(
        companyId: cid,
        inspectionPlanId: planId,
      );
      if (!mounted) return;
      for (final s in ctx.measureSlots) {
        _valueByRef[s.characteristicRef] = TextEditingController();
      }
      setState(() {
        _ctx = ctx;
        _loadingContext = false;
      });
      await _loadCtxProductLine(ctx);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contextError = AppErrorMapper.toMessage(e);
        _loadingContext = false;
      });
    }
  }

  Future<void> _loadCtxProductLine(QmsInspectionExecutionContext ctx) async {
    final pid = ctx.productId.trim();
    if (pid.isEmpty) {
      if (mounted) setState(() => _ctxProductLine = null);
      return;
    }
    try {
      final p = await _productService.getProductById(
        companyId: _cid,
        productId: pid,
      );
      if (!mounted) return;
      if (p == null) {
        setState(() => _ctxProductLine = null);
        return;
      }
      setState(() => _ctxProductLine = QmsDisplayFormatters.productLine(p));
    } catch (_) {
      if (mounted) setState(() => _ctxProductLine = null);
    }
  }

  String _submitResultLabel(String r) {
    final u = r.trim().toUpperCase();
    if (u == 'OK') return 'U redu';
    if (u == 'NOK') return 'Nije u redu';
    return r;
  }

  Future<void> _submit() async {
    final ctx = _ctx;
    final planId = _selectedPlanId;
    if (ctx == null || planId == null || planId.isEmpty) return;

    final measurements = <Map<String, dynamic>>[];
    for (final slot in ctx.measureSlots) {
      final c = _valueByRef[slot.characteristicRef];
      final raw = (c?.text ?? '').trim();
      if (raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unesi vrijednost za: ${slot.name}')),
        );
        return;
      }
      final v = double.tryParse(raw.replaceAll(',', '.'));
      if (v == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Neispravan broj za: ${slot.name}')),
        );
        return;
      }
      measurements.add({
        'characteristicRef': slot.characteristicRef,
        'measuredValue': v,
      });
    }
    if (measurements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema mjernih mjesta u planu.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await _svc.submitInspectionResult(
        companyId: _cid,
        plantKey: _defaultPlantKey.isEmpty ? null : _defaultPlantKey,
        inspectionPlanId: planId,
        measurements: measurements,
        lotId: _lotId.text.trim().isEmpty ? null : _lotId.text.trim(),
        productionOrderId: _productionOrderId.text.trim().isEmpty
            ? null
            : _productionOrderId.text.trim(),
        customerId:
            _customerId.text.trim().isEmpty ? null : _customerId.text.trim(),
        supplierId:
            _supplierId.text.trim().isEmpty ? null : _supplierId.text.trim(),
      );
      if (!mounted) return;
      var msg =
          'Spremljeno. Rezultat: ${_submitResultLabel(res.overallResult)}.';
      if (res.overallResult.toUpperCase() == 'NOK') {
        if (res.lotHoldApplied) {
          msg += ' Lot je označen kao zadržan (hold) u skladištu.';
        } else if ((res.lotHoldSkipReason ?? '').isNotEmpty) {
          msg +=
              ' Skladišni hold nije primijenjen (${res.lotHoldSkipReason}).';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _planLabel(QmsInspectionPlanRow r) {
    final code = (r.inspectionPlanCode ?? '').trim();
    final product = _productLineById[r.productId] ?? '';
    final type = QmsDisplayFormatters.inspectionType(r.inspectionType);
    final status = QmsDisplayFormatters.qmsDocStatus(r.status);
    final parts = <String>[
      if (code.isNotEmpty) code,
      if (product.isNotEmpty) product,
      type,
      status,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izvrši inspekciju'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Izvršenje inspekcije',
            message:
                '${QmsIatfStrings.executeInspection}\n\n'
                '${QmsIatfStrings.termPartnerIdsInspection}\n\n'
                '${QmsIatfStrings.termLot}',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Skeniraj LOT (wmslot) ili nalog (po:v1)'),
            onPressed: _scanQr,
          ),
          const SizedBox(height: 8),
          Text(
            'Skeniraj lot ili proizvodni nalog da se popune polja. Zatim odaberi plan inspekcije, učitaj mjerenja i unesi vrijednosti.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (_loadingPlans)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (_plansError != null)
            Text(_plansError!, style: TextStyle(color: cs.error))
          else if (_planRows.isEmpty)
            Text(
              'Nema planova inspekcije. U „Planovi inspekcije“ kreiraj plan (Callable).',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey<String?>('plan_${_selectedPlanId ?? "none"}'),
              initialValue: _selectedPlanId != null &&
                      _planRows.any((r) => r.id == _selectedPlanId)
                  ? _selectedPlanId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Plan inspekcije',
                border: OutlineInputBorder(),
              ),
              items: _planRows
                  .map(
                    (r) => DropdownMenuItem<String>(
                      value: r.id,
                      child: Text(
                        _planLabel(r),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedPlanId = v;
                  _ctx = null;
                  _contextError = null;
                  _disposeMeasureControllers();
                });
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadingContext ? null : _loadExecutionContext,
              icon: _loadingContext
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_loadingContext ? 'Učitavanje…' : 'Učitaj mjerna mjesta'),
            ),
          ],
          if (_contextError != null) ...[
            const SizedBox(height: 16),
            Text(_contextError!, style: TextStyle(color: cs.error)),
          ],
          if (_ctx != null) ...[
            const SizedBox(height: 20),
            if (!_ctx!.executionReady) ...[
              Material(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.block, color: cs.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _executionBlockedMessage(_ctx!),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _ctx!.controlPlanTitle.isNotEmpty
                  ? _ctx!.controlPlanTitle
                  : 'Kontrolni plan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tip: ${QmsDisplayFormatters.inspectionType(_ctx!.inspectionType)} · '
              'plan inspekcije: ${QmsDisplayFormatters.qmsDocStatus(_ctx!.inspectionPlanStatus)} · '
              'kontrolni plan: ${_ctx!.controlPlanStatus.isEmpty ? "—" : QmsDisplayFormatters.qmsDocStatus(_ctx!.controlPlanStatus)} · '
              'proizvod: ${_ctxProductLine ?? "…"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lotId,
              decoration: const InputDecoration(
                labelText: 'Lot (opcionalno)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _productionOrderId,
              decoration: const InputDecoration(
                labelText: 'Proizvodni nalog (opcionalno)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerId,
              decoration: InputDecoration(
                labelText: 'Kupac (opcionalno)',
                border: const OutlineInputBorder(),
                helperText: 'Za segment / automatski NCR pri NOK',
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierId,
              decoration: InputDecoration(
                labelText: 'Dobavljač (opcionalno)',
                border: const OutlineInputBorder(),
                helperText: 'Za segment / automatski NCR pri NOK',
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Mjerenja', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._ctx!.measureSlots.map((slot) {
              final ctrl = _valueByRef[slot.characteristicRef];
              final tol = _tolHint(slot);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: slot.name.isEmpty ? slot.characteristicRef : slot.name,
                    helperText: tol,
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_submitting || !_ctx!.executionReady) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_submitting ? 'Slanje…' : 'Pošalji rezultat inspekcije'),
            ),
          ],
        ],
      ),
    );
  }

  String _executionBlockedMessage(QmsInspectionExecutionContext ctx) {
    final r = ctx.executionBlockedReason?.trim().toLowerCase();
    if (r == 'obsolete') {
      return 'Plan inspekcije ili kontrolni plan je zastarjel; unos rezultata nije dopušten.';
    }
    return 'Kontrolni plan i plan inspekcije moraju biti u statusu „approved“ prije unosa rezultata.';
  }

  String? _tolHint(QmsMeasureSlot slot) {
    final parts = <String>[];
    if (slot.nominal != null) parts.add('nom. ${slot.nominal}');
    if (slot.toleranceMin != null || slot.toleranceMax != null) {
      parts.add(
        '${slot.toleranceMin ?? "—"} … ${slot.toleranceMax ?? "—"}'
        '${slot.unit != null ? " ${slot.unit}" : ""}',
      );
    } else if (slot.unit != null && slot.unit!.isNotEmpty) {
      parts.add(slot.unit!);
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}
