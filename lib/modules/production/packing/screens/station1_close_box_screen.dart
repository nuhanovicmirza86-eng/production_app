import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/user_display_label.dart';
import '../../products/services/product_lookup_service.dart';
import '../../station_pages/models/production_station_page.dart';
import '../../tracking/models/production_operator_tracking_entry.dart';
import '../../tracking/services/production_operator_tracking_service.dart';
import '../packing_box_label_pdf.dart';
import '../services/packing_box_service.dart';

/// Snimak trenutnog unosa na pripremnoj stanici (za „Dodaj u kutiju”).
class Station1DraftSnapshot {
  const Station1DraftSnapshot({
    required this.productCode,
    required this.productName,
    required this.qtyGood,
    required this.unit,
    this.productionOrderCode,
    this.productId,
    this.trackingEntryId,
  });

  final String productCode;
  final String productName;
  final double qtyGood;
  final String unit;
  final String? productionOrderCode;
  final String? productId;
  final String? trackingEntryId;
}

/// Lista stavki u kutiji → ispis etikete s QR-om za logistiku.
class Station1CloseBoxScreen extends StatefulWidget {
  const Station1CloseBoxScreen({
    super.key,
    required this.companyData,
    required this.classification,
    required this.workDateKey,
    this.initialDraft,
    this.stationSlot,
  });

  final Map<String, dynamic> companyData;
  final String classification;
  final String workDateKey;
  final Station1DraftSnapshot? initialDraft;

  /// Kanonski slot (1–3) za mapiranje na `production_station_pages` / magacin prijema.
  final int? stationSlot;

  @override
  State<Station1CloseBoxScreen> createState() => _Station1CloseBoxScreenState();
}

class _Station1CloseBoxScreenState extends State<Station1CloseBoxScreen> {
  final _svc = PackingBoxService();
  final _tracking = ProductionOperatorTrackingService();
  final List<PackingBoxLine> _lines = [];
  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String _operatorDisplay() =>
      UserDisplayLabel.fromSessionMap(widget.companyData);

  String? get _operatorUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    if (d != null &&
        d.productCode.isNotEmpty &&
        d.productName.isNotEmpty &&
        d.qtyGood > 0) {
      _lines.add(
        PackingBoxLine(
          productCode: d.productCode,
          productName: d.productName,
          qtyGood: d.qtyGood,
          unit: d.unit.isEmpty ? 'kom' : d.unit,
          productionOrderCode: d.productionOrderCode,
          productId: d.productId,
          trackingEntryId: d.trackingEntryId,
          preparedByDisplayName: _operatorDisplay(),
          preparedByUid: _operatorUid,
        ),
      );
    }
  }

  void _addFromDraft() {
    final d = widget.initialDraft;
    if (d == null) return;
    if (d.productCode.isEmpty || d.productName.isEmpty || d.qtyGood <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Popuni šifru, naziv i količinu u glavnom unosu pa pokušaj opet.'),
        ),
      );
      return;
    }
    setState(() {
      _lines.add(
        PackingBoxLine(
          productCode: d.productCode,
          productName: d.productName,
          qtyGood: d.qtyGood,
          unit: d.unit.isEmpty ? 'kom' : d.unit,
          productionOrderCode: d.productionOrderCode,
          productId: d.productId,
          trackingEntryId: d.trackingEntryId,
          preparedByDisplayName: _operatorDisplay(),
          preparedByUid: _operatorUid,
        ),
      );
    });
  }

  Future<void> _addManual() async {
    final line = await showDialog<PackingBoxLine>(
      context: context,
      builder: (ctx) => _AddManualBoxLineDialog(
        companyId: _companyId,
        preparedByDisplayName: _operatorDisplay(),
        preparedByUid: _operatorUid,
      ),
    );
    if (line == null || !mounted) return;
    setState(() => _lines.add(line));
  }

  Future<void> _printAndClose() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodaj barem jednu stavku u kutiju.')),
      );
      return;
    }
    final uid = _operatorUid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema prijavljenog korisnika.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final slot = widget.stationSlot ??
          ProductionStationPage.stationSlotForPhase(
            ProductionOperatorTrackingEntry.phasePreparation,
          );
      final boxId = await _svc.createBox(
        companyId: _companyId,
        plantKey: _plantKey,
        classification: widget.classification,
        lines: List<PackingBoxLine>.from(_lines),
        stationSlot: slot,
      );

      final entryIds = _lines
          .map((e) => e.trackingEntryId)
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
      if (entryIds.isNotEmpty) {
        await _tracking.setPackedBoxIdForEntries(
          companyId: _companyId,
          plantKey: _plantKey,
          entryIds: entryIds,
          packedBoxId: boxId,
        );
      }

      await PackingBoxLabelPdf.printLabel(
        boxId: boxId,
        companyId: _companyId,
        plantKey: _plantKey,
        stationKey: ProductionOperatorTrackingEntry.phasePreparation,
        classification: widget.classification,
        lines: _lines,
      );

      if (!mounted) return;
      setState(() => _lines.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kutija je zabilježena, etiketa poslana na ispis. Kutija je u '
            'listu „čekaju logistiku“ dolje dok se ne potvrdi prijem.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upakovane kutije — Stanica 1'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Dodaj stavke koje idu u ovu kutiju, zatim ispisi etiketu. '
              'Logistika skenira QR za prijem u magacin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.initialDraft != null)
                  OutlinedButton.icon(
                    onPressed: _addFromDraft,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Dodaj trenutni unos'),
                  ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addManual,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Dodaj ručno'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  'Stavke u ovoj kutiji',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Nema stavki. Dodaj iz unosa ili ručno.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  )
                else
                  ...List.generate(_lines.length, (i) {
                    final l = _lines[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${l.productCode} · ${l.productName}'),
                      subtitle: Text(
                        '${l.qtyGood} ${l.unit}'
                        '${l.productionOrderCode != null ? ' · PN: ${l.productionOrderCode}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _lines.removeAt(i)),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kutije koje čekaju logistiku',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nakon ispisa etikete kutija ostaje ovdje dok logistika ne potvrdi prijem skeniranjem. '
                  'Tada nestaje s ove liste i knjiži se u odabrani magacin.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<PackingBoxRecord>>(
                  stream: _svc.watchClosedPendingReceipt(
                    companyId: _companyId,
                    plantKey: _plantKey,
                  ),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text(
                        'Lista: ${snap.error}',
                        style: TextStyle(color: theme.colorScheme.error),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final boxes = snap.data ?? [];
                    if (boxes.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Nema kutija u redu čekanja.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: boxes.map((b) {
                        final short =
                            b.id.length > 8 ? b.id.substring(b.id.length - 8) : b.id;
                        final t = b.createdAt;
                        final timeStr = t != null
                            ? '${t.day.toString().padLeft(2, '0')}.'
                                '${t.month.toString().padLeft(2, '0')}. '
                                '${t.hour.toString().padLeft(2, '0')}:'
                                '${t.minute.toString().padLeft(2, '0')}'
                            : '—';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.local_shipping_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text('Kutija …$short'),
                            subtitle: Text(
                              '${b.lines.length} stavki · $timeStr · ${b.classification}',
                            ),
                            trailing: Chip(
                              label: const Text('Čeka prijem'),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme.colorScheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _printAndClose,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.label_outline),
                label: Text(_saving ? 'Spremanje…' : 'Ispiši etiketu kutije'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ručni unos stavke s pretragom šifrarnika (isti obrazac kao pripremna tablica).
class _AddManualBoxLineDialog extends StatefulWidget {
  const _AddManualBoxLineDialog({
    required this.companyId,
    required this.preparedByDisplayName,
    this.preparedByUid,
  });

  final String companyId;
  final String preparedByDisplayName;
  final String? preparedByUid;

  @override
  State<_AddManualBoxLineDialog> createState() =>
      _AddManualBoxLineDialogState();
}

class _AddManualBoxLineDialogState extends State<_AddManualBoxLineDialog> {
  final _lookup = ProductLookupService();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _pnCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _qtyFocus = FocusNode();
  final _pnFocus = FocusNode();

  Timer? _catalogDebounce;
  List<ProductLookupItem> _catalogHits = [];
  bool _catalogSearching = false;
  String? _linkedProductId;
  String _unitVal = 'kom';

  static const _units = ['kom', 'kg', 'm', 'l'];

  List<String> get _unitChoices {
    final s = <String>{..._units};
    if (_unitVal.isNotEmpty && !s.contains(_unitVal)) s.add(_unitVal);
    return s.toList();
  }

  void _onCatalogFocusChanged() {
    if (_codeFocus.hasFocus || _nameFocus.hasFocus) {
      _scheduleCatalogSearch();
    }
  }

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(_onCatalogFocusChanged);
    _nameFocus.addListener(_onCatalogFocusChanged);
  }

  @override
  void dispose() {
    _codeFocus.removeListener(_onCatalogFocusChanged);
    _nameFocus.removeListener(_onCatalogFocusChanged);
    _catalogDebounce?.cancel();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _pnCtrl.dispose();
    _codeFocus.dispose();
    _nameFocus.dispose();
    _qtyFocus.dispose();
    _pnFocus.dispose();
    super.dispose();
  }

  String _catalogQueryFromFields() {
    final c = _codeCtrl.text.trim();
    final n = _nameCtrl.text.trim();
    if (_codeFocus.hasFocus) return c;
    if (_nameFocus.hasFocus) return n;
    if (c.isNotEmpty && n.isNotEmpty) {
      return c.length >= n.length ? c : n;
    }
    return c.isNotEmpty ? c : n;
  }

  void _scheduleCatalogSearch() {
    _catalogDebounce?.cancel();
    _catalogDebounce = Timer(const Duration(milliseconds: 280), _runCatalogSearch);
  }

  Future<void> _runCatalogSearch() async {
    final cid = widget.companyId.trim();
    final q = _catalogQueryFromFields();
    if (cid.isEmpty || q.isEmpty) {
      if (mounted) {
        setState(() {
          _catalogHits = [];
          _catalogSearching = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _catalogSearching = true);
    final firedFor = q.trim();
    try {
      final hits = await _lookup.searchProducts(
        companyId: cid,
        query: firedFor,
        limit: 12,
      );
      if (!mounted) return;
      if (_catalogQueryFromFields().trim() != firedFor) return;
      setState(() {
        _catalogHits = hits;
        _catalogSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogHits = [];
        _catalogSearching = false;
      });
    }
  }

  void _applyCatalogProduct(
    ProductLookupItem hit, {
    bool focusQuantityAfter = true,
  }) {
    _codeCtrl.text = hit.productCode;
    _nameCtrl.text = hit.productName;
    _linkedProductId = hit.productId;
    final u = hit.unit?.trim();
    if (u != null && u.isNotEmpty) {
      _unitVal = u;
    }
    setState(() {
      _catalogHits = [];
      _catalogSearching = false;
    });
    if (focusQuantityAfter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _qtyFocus.requestFocus();
      });
    }
  }

  /// Enter na šifri/nazivu: prvi prijedlog bez klika mišem (kad postoji).
  void _onCodeFieldSubmitted(String _) {
    if (_catalogSearching) {
      _nameFocus.requestFocus();
      return;
    }
    if (_catalogHits.isNotEmpty) {
      _applyCatalogProduct(_catalogHits.first);
      return;
    }
    _nameFocus.requestFocus();
  }

  void _onNameFieldSubmitted(String _) {
    if (_catalogSearching) {
      _qtyFocus.requestFocus();
      return;
    }
    if (_catalogHits.isNotEmpty) {
      _applyCatalogProduct(_catalogHits.first);
      return;
    }
    _qtyFocus.requestFocus();
  }

  void _submit() {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final q = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final pn = _pnCtrl.text.trim();
    if (code.isEmpty || name.isEmpty || q <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Šifra, naziv i količina su obavezni.')),
      );
      return;
    }
    Navigator.of(context).pop(
      PackingBoxLine(
        productCode: code,
        productName: name,
        qtyGood: q,
        unit: _unitVal,
        productionOrderCode: pn.isEmpty ? null : pn,
        productId: _linkedProductId,
        preparedByDisplayName: widget.preparedByDisplayName,
        preparedByUid: widget.preparedByUid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: const Text('Stavka u kutiju'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _codeCtrl,
                focusNode: _codeFocus,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Šifra',
                  hintText: 'Upiši — Enter = prvi prijedlog',
                ),
                onChanged: (_) {
                  _linkedProductId = null;
                  _scheduleCatalogSearch();
                },
                onSubmitted: _onCodeFieldSubmitted,
              ),
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Naziv',
                  hintText: 'Ili traži po nazivu — Enter = prvi prijedlog',
                ),
                onChanged: (_) {
                  _linkedProductId = null;
                  _scheduleCatalogSearch();
                },
                onSubmitted: _onNameFieldSubmitted,
              ),
              if (_catalogSearching || _catalogHits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Šifrarnik',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (!_catalogSearching && _catalogHits.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Enter uzima prvi u listi — suzi šifru/naziv ako treba drugi proizvod.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: _catalogSearching
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _catalogHits.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                            ),
                            itemBuilder: (ctx, i) {
                              final h = _catalogHits[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  h.productCode,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  h.productName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _applyCatalogProduct(h),
                              );
                            },
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _qtyCtrl,
                focusNode: _qtyFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Količina (dobro)',
                ),
                onSubmitted: (_) => _pnFocus.requestFocus(),
              ),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Jedinica'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unitVal,
                    isExpanded: true,
                    items: _unitChoices
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u,
                            child: Text(u),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _unitVal = v);
                    },
                  ),
                ),
              ),
              TextField(
                controller: _pnCtrl,
                focusNode: _pnFocus,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nalog (PN, opciono)',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Dodaj'),
        ),
      ],
    );
  }
}
