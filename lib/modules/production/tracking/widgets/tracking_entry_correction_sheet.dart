import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/station_input.dart';
import '../config/platform_defect_codes.dart';
import '../models/production_operator_tracking_entry.dart';
import '../models/tracking_scrap_line.dart';
import '../services/production_operator_tracking_service.dart';
import 'tracking_quantity_editor_sheet.dart';

/// Jednokratna ispravka vlastitog zapisa (Callable + audit na serveru).
Future<void> showTrackingEntryCorrectionSheet({
  required BuildContext context,
  required ProductionOperatorTrackingEntry entry,
  required String companyId,
  required bool preparationPhase,
  required ProductionOperatorTrackingService service,
  required Map<String, dynamic> companyData,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TrackingEntryCorrectionBody(
      entry: entry,
      companyId: companyId,
      preparationPhase: preparationPhase,
      service: service,
      companyData: companyData,
    ),
  );
}

class _TrackingEntryCorrectionBody extends StatefulWidget {
  const _TrackingEntryCorrectionBody({
    required this.entry,
    required this.companyId,
    required this.preparationPhase,
    required this.service,
    required this.companyData,
  });

  final ProductionOperatorTrackingEntry entry;
  final String companyId;
  final bool preparationPhase;
  final ProductionOperatorTrackingService service;
  final Map<String, dynamic> companyData;

  @override
  State<_TrackingEntryCorrectionBody> createState() =>
      _TrackingEntryCorrectionBodyState();
}

class _TrackingEntryCorrectionBodyState extends State<_TrackingEntryCorrectionBody> {
  final _reasonCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _goodQtyCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _releaseCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _pnCtrl = TextEditingController();
  final _commercialCtrl = TextEditingController();
  final _rawOpCtrl = TextEditingController();
  final _preparedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _productIdCtrl = TextEditingController();

  final Map<String, double> _scrapByCode = {};
  final List<TrackingScrapLine> _extraScrap = [];

  bool _busy = false;

  List<ScrapTileDef> get _scrapDefs =>
      defectTilesFromDisplayMap(parseDefectDisplayNamesMap(widget.companyData));

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _codeCtrl.text = e.itemCode;
    _nameCtrl.text = e.itemName;
    _unitCtrl.text = e.unit;
    _goodQtyCtrl.text = _fmtQty(e.effectiveGoodQty);
    _batchCtrl.text = e.lineOrBatchRef ?? '';
    _releaseCtrl.text = e.releaseToolOrRodRef ?? '';
    _customerCtrl.text = e.customerName ?? '';
    _pnCtrl.text = e.displayRawMaterialOrder.isEmpty
        ? (e.productionOrderId ?? '')
        : e.displayRawMaterialOrder;
    _commercialCtrl.text = e.commercialOrderId ?? '';
    _rawOpCtrl.text = e.rawWorkOperatorName ?? '';
    _preparedCtrl.text = e.preparedByDisplayName ?? '';
    _notesCtrl.text = e.notes ?? '';
    _productIdCtrl.text = e.productId ?? '';

    final defCodes = PlatformDefectCodes.allCodes.toSet();
    for (final s in e.scrapBreakdown) {
      if (defCodes.contains(s.code)) {
        _scrapByCode[s.code] = s.qty;
      } else {
        _extraScrap.add(
          TrackingScrapLine(code: s.code, label: s.label, qty: s.qty),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _goodQtyCtrl.dispose();
    _batchCtrl.dispose();
    _releaseCtrl.dispose();
    _customerCtrl.dispose();
    _pnCtrl.dispose();
    _commercialCtrl.dispose();
    _rawOpCtrl.dispose();
    _preparedCtrl.dispose();
    _notesCtrl.dispose();
    _productIdCtrl.dispose();
    super.dispose();
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  List<TrackingScrapLine> _scrapLinesForSave() {
    final defs = _scrapDefs;
    final out = <TrackingScrapLine>[];
    for (final d in defs) {
      final q = _scrapByCode[d.code];
      if (q != null && q > 0) {
        out.add(TrackingScrapLine(code: d.code, label: d.label, qty: q));
      }
    }
    for (final x in _extraScrap) {
      if (x.qty > 0) out.add(x);
    }
    return out;
  }

  Future<void> _editScrapTile(ScrapTileDef def) async {
    final current = _scrapByCode[def.code] ?? 0;
    final v = await openTrackingQuantitySheet(
      context,
      title: def.label,
      hint: 'Škart · ${def.code}',
      initialValue: current > 0 ? current : null,
    );
    if (v != null && mounted) {
      setState(() {
        if (v == 0) {
          _scrapByCode.remove(def.code);
        } else {
          _scrapByCode[def.code] = v;
        }
      });
    }
  }

  Future<void> _editExtraScrap(int index) async {
    final x = _extraScrap[index];
    final v = await openTrackingQuantitySheet(
      context,
      title: x.label,
      hint: 'Škart · ${x.code}',
      initialValue: x.qty > 0 ? x.qty : null,
    );
    if (v != null && mounted) {
      setState(() {
        if (v <= 0) {
          _extraScrap.removeAt(index);
        } else {
          _extraScrap[index] = TrackingScrapLine(
            code: x.code,
            label: x.label,
            qty: v,
          );
        }
      });
    }
  }

  Future<void> _onSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || uid != widget.entry.createdByUid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Možeš ispraviti samo vlastiti zapis.'),
          ),
        );
      }
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upiši kratki razlog ispravka (audit).')),
      );
      return;
    }

    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Šifra i naziv su obavezni.')),
      );
      return;
    }

    final gRaw = _goodQtyCtrl.text.trim().replaceAll(',', '.');
    final goodQty = double.tryParse(gRaw);
    if (goodQty == null || goodQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nevaljana količina (dobro).')),
      );
      return;
    }

    final scrapLines = _scrapLinesForSave();
    final scrapSum = scrapLines.fold<double>(0, (a, b) => a + b.qty);
    if (goodQty + scrapSum <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zbroj dobra i škarta mora biti veći od nule.'),
        ),
      );
      return;
    }

    final unit = _unitCtrl.text.trim().isEmpty ? 'kom' : _unitCtrl.text.trim();
    final rawPn = _pnCtrl.text.trim();

    setState(() => _busy = true);
    try {
      await widget.service.correctEntry(
        companyId: widget.companyId,
        entry: widget.entry,
        itemCode: code,
        itemName: name,
        goodQty: goodQty,
        unit: unit,
        productId: _productIdCtrl.text.trim().isEmpty
            ? null
            : _productIdCtrl.text.trim(),
        productionOrderId: rawPn.isEmpty ? null : rawPn,
        commercialOrderId: _commercialCtrl.text.trim().isEmpty
            ? null
            : _commercialCtrl.text.trim(),
        rawMaterialOrderCode: rawPn.isEmpty ? null : rawPn,
        lineOrBatchRef: _batchCtrl.text.trim().isEmpty
            ? null
            : _batchCtrl.text.trim(),
        releaseToolOrRodRef: widget.preparationPhase &&
                _releaseCtrl.text.trim().isNotEmpty
            ? _releaseCtrl.text.trim()
            : null,
        customerName: _customerCtrl.text.trim().isEmpty
            ? null
            : _customerCtrl.text.trim(),
        rawWorkOperatorName:
            _rawOpCtrl.text.trim().isEmpty ? null : _rawOpCtrl.text.trim(),
        preparedByDisplayName: _preparedCtrl.text.trim().isEmpty
            ? null
            : _preparedCtrl.text.trim(),
        sourceQrPayload: widget.entry.sourceQrPayload,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        scrapBreakdown: scrapLines,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ispravak je spremljen (audit arhiviran).')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h * 0.92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Ispravak unosa (jednokratno)',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Datum i vrijeme evidencije ostaju kao pri prvom spremanju. '
                  'Izmjena se bilježi u audit zapisu.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StationTextField(
                        controller: _reasonCtrl,
                        maxLines: 2,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Razlog ispravka *',
                        ),
                      ),
                      const SizedBox(height: 12),
                      StationTextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Šifra *',
                        ),
                      ),
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _nameCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Naziv *',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: StationTextField(
                              controller: _goodQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: StationInputDecoration.formField(
                                context,
                                labelText: 'Dobro (količina) *',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StationTextField(
                              controller: _unitCtrl,
                              decoration: StationInputDecoration.formField(
                                context,
                                labelText: 'Jed.',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Škart (pločice)',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in _scrapDefs)
                            ActionChip(
                              label: Text(
                                '${d.label}: ${_fmtQty(_scrapByCode[d.code] ?? 0)}',
                                style: theme.textTheme.labelSmall,
                              ),
                              onPressed: _busy ? null : () => _editScrapTile(d),
                            ),
                        ],
                      ),
                      for (var i = 0; i < _extraScrap.length; i++) ...[
                        const SizedBox(height: 6),
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _extraScrap[i].label,
                            style: theme.textTheme.bodySmall,
                          ),
                          subtitle: Text(
                            _extraScrap[i].code,
                            style: theme.textTheme.labelSmall,
                          ),
                          trailing: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _editExtraScrap(i),
                            child: Text(_fmtQty(_extraScrap[i].qty)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      StationTextField(
                        controller: _batchCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Palica / šarž / lin.',
                        ),
                      ),
                      if (widget.preparationPhase) ...[
                        const SizedBox(height: 8),
                        StationTextField(
                          controller: _releaseCtrl,
                          decoration: StationInputDecoration.formField(
                            context,
                            labelText: 'Alat / palica (puštanje)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _customerCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Kupac',
                        ),
                      ),
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _pnCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Nalog sirov. / PN',
                        ),
                      ),
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _commercialCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Komercijalni nalog',
                        ),
                      ),
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _rawOpCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Operater izrade',
                        ),
                      ),
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _preparedCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Pripremio (prikaz)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _productIdCtrl,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'ID proizvoda (opcionalno)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      StationTextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: StationInputDecoration.formField(
                          context,
                          labelText: 'Napomena',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Odustani'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _busy ? null : _onSave,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Spremi ispravak'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
