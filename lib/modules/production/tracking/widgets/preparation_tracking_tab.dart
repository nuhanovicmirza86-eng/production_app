import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../production_orders/printing/classification_label_print_qr.dart';
import '../../products/services/product_lookup_service.dart';
import '../../qr/production_qr_resolver.dart';
import '../../qr/screens/production_qr_scan_screen.dart';
import '../config/platform_defect_codes.dart';
import '../models/production_operator_tracking_entry.dart';
import '../models/tracking_scrap_line.dart';
import '../export/tracking_station_label_pdf.dart';
import '../services/company_defect_display_names_service.dart';
import '../services/production_operator_tracking_service.dart';
import 'tracking_quantity_editor_sheet.dart';

/// Operativni unos po fazi: tablica + pločice (dobro + škart) + **QR skener** + **ispis etikete** (isti JSON kao klasifikacijska etiketa).
///
/// QR: otisnuta etiketa klasifikacije (`production_classification_label`, JSON) — vidi
/// `classification_label_print_qr.dart`. Sken puni polja.
///
/// Tipovi škarta: fiksni kanonski kodovi [PlatformDefectCodes] (DEF_001 … DEF_015).
/// Kompanija u sesiji (`companyData`) šalje mapu [defectDisplayNamesKey] kod → prikazni naziv;
/// kodovi se ne mijenjaju (vidi `QUALITY_ARCHITECTURE.md`).
class PreparationTrackingTab extends StatefulWidget {
  final Map<String, dynamic> companyData;
  /// [ProductionOperatorTrackingEntry.phasePreparation] / `first_control` / `final_control`.
  final String phase;

  const PreparationTrackingTab({
    super.key,
    required this.companyData,
    this.phase = ProductionOperatorTrackingEntry.phasePreparation,
  });

  @override
  State<PreparationTrackingTab> createState() => _PreparationTrackingTabState();
}

class _PreparationTrackingTabState extends State<PreparationTrackingTab> {
  final _service = ProductionOperatorTrackingService();
  final _lookup = ProductLookupService();

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pnCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _rawOperatorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();

  Timer? _catalogDebounce;
  List<ProductLookupItem> _catalogHits = [];
  bool _catalogSearching = false;
  bool _muteCatalogFieldListeners = false;

  String _unit = 'kom';
  DateTime _workDay = DateTime.now();
  String? _linkedProductId;
  bool _saving = false;

  double _goodQty = 0;
  final Map<String, double> _scrapByCode = {};

  /// Zadnji sirovi sadržaj skenirane etikete (audit u Firestore `sourceQrPayload`).
  String? _sourceQrPayload;

  /// Nakon uređivanja naziva škarta (Firestore); [widget.companyData] se može osvježiti kasnije.
  Map<String, String> _defectNamesSessionOverlay = {};

  @override
  void initState() {
    super.initState();
    void onDraftTextChanged() {
      if (_muteCatalogFieldListeners) return;
      setState(() => _linkedProductId = null);
      _scheduleCatalogSearch();
    }

    _codeCtrl.addListener(onDraftTextChanged);
    _nameCtrl.addListener(onDraftTextChanged);
    _codeFocus.addListener(_scheduleCatalogSearch);
    _nameFocus.addListener(_scheduleCatalogSearch);
  }

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String _workDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Klasifikacija u JSON etiketi (usklađeno s BOM katalogom).
  String _classificationForLabels() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'SECONDARY';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'PRIMARY';
      default:
        return 'TRANSPORT';
    }
  }

  String _phaseHumanShort() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prva kontrola';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Završna kontrola';
      default:
        return 'Pripremna';
    }
  }

  String _goodQtyTileTitle() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Dobro\n(poluproizvod)';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Dobro\n(gotov proizvod)';
      default:
        return 'Pripremljeno\n(dobro)';
    }
  }

  /// Naslov u sheetu za uređivanje „dobrog“ (pločica iznad tablice).
  String _goodQtyEditorTitle() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Dobro (poluproizvod)';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Dobro (gotov proizvod)';
      default:
        return 'Pripremljeno (dobro)';
    }
  }

  String _goodQtyEditorHint() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Količina prihvaćenog poluproizvoda nakon prve kontrole ($_unit).';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Količina prihvaćenog gotovog proizvoda nakon završne kontrole ($_unit).';
      default:
        return 'Količina pripremljena za daljnji rad ($_unit).';
    }
  }

  /// Uvod ispod naslova „Količine“.
  String _qtySectionIntro() {
    final base =
        'Kodovi su fiksni (${PlatformDefectCodes.count} tipova: '
        '${PlatformDefectCodes.codeAt1Based(1)} … ${PlatformDefectCodes.codeAt1Based(PlatformDefectCodes.count)}); '
        'administrator kompanije u sesiji postavlja mapu `$defectDisplayNamesKey` (kod → prikazni naziv).';
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Odaberi pločicu (dobro poluproizvod ili škart), zatim unesi količinu. $base';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Odaberi pločicu (dobro gotov proizvod ili škart), zatim unesi količinu. $base';
      default:
        return 'Odaberi pločicu (pripremljeno ili škart), zatim unesi količinu. $base';
    }
  }

  String _submitNeedPositiveQtyMessage() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Unesi količinu dobrog poluproizvoda i/ili škarta.';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Unesi količinu dobrog gotovog proizvoda i/ili škarta.';
      default:
        return 'Odaberi pločicu i unesi pripremljenu količinu i/ili škart.';
    }
  }

  String _saveSuccessMessage() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Unos prve kontrole je spremljen.';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Unos završne kontrole je spremljen.';
      default:
        return 'Unos pripreme je spremljen.';
    }
  }

  String _tableGoodColumnHeader() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Dobro ($_unit)';
      default:
        return 'Pripr. ($_unit)';
    }
  }

  String _tableGoodColumnTooltip() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prihvaćena količina poluproizvoda (pločica iznad)';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Prihvaćena količina gotovog proizvoda (pločica iznad)';
      default:
        return 'Količina pripremljenih (odabir pločicom iznad)';
    }
  }

  String _labelPrintNeedCodeNameMessage() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Za etiketu prve kontrole unesi šifru i naziv poluproizvoda u tablici.';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Za etiketu završne kontrole unesi šifru i naziv gotovog proizvoda u tablici.';
      default:
        return 'Za etiketu unesi šifru i naziv komada u tablici.';
    }
  }

  String _scanLabelLoadedSnack() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Podaci s etikete su učitani. Provjeri količine za prvu kontrolu i spremi.';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Podaci s etikete su učitani. Provjeri količine za završnu kontrolu i spremi.';
      default:
        return 'Podaci s etikete su učitani. Provjeri količine i spremi.';
    }
  }

  String _scanOrderQrSnack() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Učitan je proizvodni nalog iz QR. Unesi šifru poluproizvoda pa spremi.';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Učitan je proizvodni nalog iz QR. Unesi šifru gotovog proizvoda pa spremi.';
      default:
        return 'Učitan je proizvodni nalog iz QR. Unesi šifru sirovine pa spremi.';
    }
  }

  String _scanUnknownExpectedHint() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Za prvu kontrolu očekuje se etiketa klasifikacije (JSON) s poljima pcode / piece (poluproizvod). ';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Za završnu kontrolu očekuje se etiketa klasifikacije (JSON) s poljima pcode / piece (gotov proizvod). ';
      default:
        return 'Očekuje se etiketa klasifikacije (JSON) s poljima pcode / piece. ';
    }
  }

  String _emptyDayHint() {
    switch (widget.phase) {
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Još nema redova prve kontrole za ovaj dan.';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Još nema redova završne kontrole za ovaj dan.';
      default:
        return 'Još nema spremljenih redova pripreme za ovaj dan.';
    }
  }

  String _labelQtyLine() {
    final g = _fmtQty(_goodQty);
    final sc = _scrapSum();
    if (sc > 0) {
      return '$g $_unit + škart ${_fmtQty(sc)} $_unit';
    }
    return '$g $_unit';
  }

  Future<void> _printDraftLabel() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_labelPrintNeedCodeNameMessage())),
      );
      return;
    }
    final rawPn = _pnCtrl.text.trim();
    final pn = rawPn.isEmpty ? 'RUČNO-${_workDateKey(_workDay)}' : rawPn;
    final op = _preparedBySnapshot().trim().isEmpty ? '—' : _preparedBySnapshot().trim();
    final json = buildClassificationLabelPrintQrJson(
      productionOrderCode: pn,
      productCode: code,
      pieceName: name,
      quantityText: _labelQtyLine(),
      operatorName: op,
      printedAt: DateTime.now(),
      classification: _classificationForLabels(),
    );
    try {
      await TrackingStationLabelPdf.printLabel(
        phaseTitle: _phaseHumanShort(),
        qrJson: json,
        classification: _classificationForLabels(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ispis etikete: $e')),
      );
    }
  }

  Map<String, String> _mergedDefectNames() => {
    ...parseDefectDisplayNamesMap(widget.companyData),
    ..._defectNamesSessionOverlay,
  };

  List<ScrapTileDef> _scrapTiles() =>
      defectTilesFromDisplayMap(_mergedDefectNames());

  bool _canEditCompanyDefectNames() {
    final r = ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    return r == ProductionAccessHelper.roleAdmin ||
        r == 'administrator' ||
        r == 'company_admin' ||
        r == ProductionAccessHelper.roleProductionManager ||
        r == ProductionAccessHelper.roleSupervisor;
  }

  Future<void> _openDefectLabelsEditor() async {
    if (!_canEditCompanyDefectNames() || _companyId.isEmpty) return;
    final merged = _mergedDefectNames();
    final seed = <String, String>{
      for (final c in PlatformDefectCodes.allCodes) c: merged[c] ?? c,
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _DefectDisplayNamesEditorDialog(
        companyId: _companyId,
        seedByCode: seed,
      ),
    );
    if (result != null && mounted) {
      setState(() => _defectNamesSessionOverlay = result);
    }
  }

  double _scrapSum() {
    var s = 0.0;
    for (final v in _scrapByCode.values) {
      s += v;
    }
    return s;
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  String _preparedBySnapshot() {
    final d = (widget.companyData['userDisplayName'] ?? '').toString().trim();
    if (d.isNotEmpty) return d;
    final n = (widget.companyData['nickname'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    return (widget.companyData['userEmail'] ?? '').toString().trim();
  }

  String _formatPrepDateTime(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// R.br. 1 = najnoviji unos (isti redoslijed kao stream: `createdAt` desc).
  Map<String, int> _sequenceByEntryId(List<ProductionOperatorTrackingEntry> rows) {
    final sorted = [...rows]..sort((a, b) {
      final ta = a.createdAt;
      final tb = b.createdAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    final map = <String, int>{};
    for (var i = 0; i < sorted.length; i++) {
      map[sorted[i].id] = i + 1;
    }
    return map;
  }

  /// Širine kolona (kartična tablica + horizontalni scroll).
  static const double _pwRb = 42;
  static const double _pwDt = 114;
  static const double _pwBl = 108;
  static const double _pwCd = 82;
  static const double _pwNm = 208;
  static const double _pwCu = 112;
  static const double _pwGd = 78;
  static const double _pwSc = 54;
  static const double _pwPo = 104;
  static const double _pwRo = 114;
  static const double _pwBy = 124;

  double get _prepTableScrollWidth =>
      _pwRb +
      _pwDt +
      _pwBl +
      _pwCd +
      _pwNm +
      _pwCu +
      _pwGd +
      _pwSc +
      _pwPo +
      _pwRo +
      _pwBy;

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
    if (!mounted) return;
    final q = _catalogQueryFromFields();
    if (_companyId.isEmpty || q.trim().isEmpty) {
      setState(() {
        _catalogHits = [];
        _catalogSearching = false;
      });
      return;
    }
    setState(() => _catalogSearching = true);
    final firedFor = q.trim();
    try {
      final hits = await _lookup.searchProducts(
        companyId: _companyId,
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

  void _applyCatalogProduct(ProductLookupItem hit) {
    _muteCatalogFieldListeners = true;
    try {
      _codeCtrl.text = hit.productCode;
      _nameCtrl.text = hit.productName;
    } finally {
      _muteCatalogFieldListeners = false;
    }
    setState(() {
      _linkedProductId = hit.productId;
      if (hit.customerName != null && hit.customerName!.trim().isNotEmpty) {
        _customerCtrl.text = hit.customerName!.trim();
      }
      if (hit.unit != null && hit.unit!.trim().isNotEmpty) {
        _unit = hit.unit!.trim();
      }
      _catalogHits = [];
      _catalogSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildCatalogMatchesStrip(ThemeData theme, ColorScheme cs) {
    if (!_catalogSearching && _catalogHits.isEmpty) {
      return const SizedBox.shrink();
    }
    final rule = cs.outlineVariant.withValues(alpha: 0.5);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: rule, width: 1)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: _catalogSearching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _catalogHits.length,
                separatorBuilder: (_, unused) => Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
                itemBuilder: (ctx, i) {
                  final h = _catalogHits[i];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      h.productCode,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      h.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _applyCatalogProduct(h),
                  );
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    _catalogDebounce?.cancel();
    _codeFocus.dispose();
    _nameFocus.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _pnCtrl.dispose();
    _batchCtrl.dispose();
    _customerCtrl.dispose();
    _rawOperatorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fillFromCatalog() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _companyId.isEmpty) return;
    try {
      final hit = await _lookup.getByExactCode(
        companyId: _companyId,
        productCode: code,
      );
      if (!mounted) return;
      if (hit == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nema aktivnog proizvoda s tom šifrom.')),
        );
        return;
      }
      _muteCatalogFieldListeners = true;
      try {
        setState(() {
          _nameCtrl.text = hit.productName;
          _linkedProductId = hit.productId;
          if (hit.unit != null && hit.unit!.trim().isNotEmpty) {
            _unit = hit.unit!.trim();
          }
        });
      } finally {
        _muteCatalogFieldListeners = false;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pretraga: $e')));
    }
  }

  /// Gruba ekstrakcija broja i jedinice iz teksta etikete (npr. `12 kg`).
  void _applyQtyHintFromLabel(String? qtyText) {
    if (qtyText == null) return;
    final t = qtyText.trim();
    if (t.isEmpty) return;
    final m = RegExp(r'([0-9]+[.,]?[0-9]*)').firstMatch(t);
    if (m == null) return;
    final n = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (n == null || n <= 0) return;
    final lower = t.toLowerCase();
    String? u;
    if (lower.contains('kg')) {
      u = 'kg';
    } else if (lower.contains('m²') || lower.contains('m2')) {
      u = 'm2';
    } else if (lower.contains('kom')) {
      u = 'kom';
    } else if (lower.contains('lit') || RegExp(r'\d\s*l\b').hasMatch(lower)) {
      u = 'l';
    } else if (RegExp(r'\bm\b').hasMatch(lower) && !lower.contains('kom')) {
      u = 'm';
    }
    setState(() {
      _goodQty = n;
      if (u != null) _unit = u;
    });
  }

  Future<void> _scanRawPieceLabelQr() async {
    final resolution = await Navigator.push<ProductionQrScanResolution>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProductionQrScanScreen(companyData: widget.companyData),
      ),
    );
    if (!mounted || resolution == null) return;

    switch (resolution.intent) {
      case ProductionQrIntent.printedClassificationLabelV1:
        final m = resolution.labelFields;
        if (m == null) break;
        final pcode = (m['pcode'] ?? '').toString().trim();
        final piece = (m['piece'] ?? '').toString().trim();
        final pn = (m['pn'] ?? '').toString().trim();
        if (pcode.isEmpty && piece.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Etiketa nema šifru ni naziv komada (pcode / piece).'),
            ),
          );
          return;
        }
        final cust = (m['customer'] ?? m['customerName'] ?? '').toString().trim();
        _muteCatalogFieldListeners = true;
        try {
          setState(() {
            if (pcode.isNotEmpty) _codeCtrl.text = pcode;
            if (piece.isNotEmpty) _nameCtrl.text = piece;
            if (pn.isNotEmpty) _pnCtrl.text = pn;
            if (cust.isNotEmpty) _customerCtrl.text = cust;
            _sourceQrPayload = resolution.rawPayload;
            _linkedProductId = null;
          });
        } finally {
          _muteCatalogFieldListeners = false;
        }
        _applyQtyHintFromLabel(m['qty']?.toString());
        if (pcode.isNotEmpty && _companyId.isNotEmpty) {
          await _fillFromCatalog();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scanLabelLoadedSnack())),
        );
        break;

      case ProductionQrIntent.productionOrderReferenceV1:
        final id = resolution.productionOrderId?.trim();
        if (id == null || id.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR naloga nema ID — koristi etiketu sirovog komada (JSON).')),
          );
          return;
        }
        setState(() {
          _pnCtrl.text = id;
          _sourceQrPayload = resolution.rawPayload;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_scanOrderQrSnack())),
        );
        break;

      case ProductionQrIntent.nepoznat:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_scanUnknownExpectedHint()}'
              'Ručni unos: ${resolution.rawPayload.length > 80 ? '${resolution.rawPayload.substring(0, 80)}…' : resolution.rawPayload}',
            ),
          ),
        );
        break;
    }
  }

  Future<void> _pickWorkDay() async {
    final first = DateTime.now().subtract(const Duration(days: 7));
    final last = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDay,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _workDay = picked);
    }
  }

  Future<void> _editGoodQty() async {
    final v = await openTrackingQuantitySheet(
      context,
      title: _goodQtyEditorTitle(),
      hint: _goodQtyEditorHint(),
      initialValue: _goodQty > 0 ? _goodQty : null,
    );
    if (v != null && mounted) setState(() => _goodQty = v);
  }

  Future<void> _editScrapQty(ScrapTileDef def) async {
    final current = _scrapByCode[def.code] ?? 0;
    final v = await openTrackingQuantitySheet(
      context,
      title: def.label,
      hint: 'Škart · kod: ${def.code} · jedinica: $_unit',
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

  List<TrackingScrapLine> _scrapLinesForSave(List<ScrapTileDef> defs) {
    final out = <TrackingScrapLine>[];
    for (final d in defs) {
      final q = _scrapByCode[d.code];
      if (q != null && q > 0) {
        out.add(TrackingScrapLine(code: d.code, label: d.label, qty: q));
      }
    }
    return out;
  }

  void _resetDraftQuantities() {
    setState(() {
      _goodQty = 0;
      _scrapByCode.clear();
    });
  }

  Future<void> _submit(List<ScrapTileDef> scrapDefs) async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje companyId ili plantKey u sesiji.')),
      );
      return;
    }
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final scrapLines = _scrapLinesForSave(scrapDefs);
    final scrapSum = scrapLines.fold<double>(0, (a, b) => a + b.qty);

    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesi šifru i naziv artikla.')),
      );
      return;
    }
    if (_goodQty + scrapSum <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submitNeedPositiveQtyMessage())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final rawPn = _pnCtrl.text.trim();
      await _service.createEntry(
        companyId: _companyId,
        plantKey: _plantKey,
        phase: widget.phase,
        workDate: _workDateKey(_workDay),
        itemCode: code,
        itemName: name,
        goodQty: _goodQty,
        unit: _unit,
        productId: _linkedProductId,
        productionOrderId: rawPn.isEmpty ? null : rawPn,
        rawMaterialOrderCode: rawPn.isEmpty ? null : rawPn,
        lineOrBatchRef: _batchCtrl.text.trim().isEmpty ? null : _batchCtrl.text.trim(),
        customerName: _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim(),
        rawWorkOperatorName: _rawOperatorCtrl.text.trim().isEmpty
            ? null
            : _rawOperatorCtrl.text.trim(),
        preparedByDisplayName: _preparedBySnapshot().isEmpty ? null : _preparedBySnapshot(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        scrapBreakdown: scrapLines,
        sourceQrPayload: _sourceQrPayload,
      );
      if (!mounted) return;
      _notesCtrl.clear();
      _batchCtrl.clear();
      _customerCtrl.clear();
      _rawOperatorCtrl.clear();
      _pnCtrl.clear();
      _codeCtrl.clear();
      _nameCtrl.clear();
      _resetDraftQuantities();
      setState(() => _sourceQrPayload = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveSuccessMessage())));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firestore: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Minimalan unos u ćeliji (bez „pill“ obruba), u skladu s listom naloga.
  InputDecoration _prepTableFieldDecoration(BuildContext context, String hint) {
    final cs = Theme.of(context).colorScheme;
    final none = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 11,
        color: cs.onSurfaceVariant.withValues(alpha: 0.78),
      ),
      filled: true,
      fillColor: Colors.transparent,
      border: none,
      enabledBorder: none,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.45), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    );
  }

  InputDecoration _prepMjDropdownDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final soft = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.surface,
      border: soft,
      enabledBorder: soft,
      focusedBorder: soft.copyWith(
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _prepCardCell(
    BuildContext context, {
    required double width,
    required Widget child,
    bool showRightDivider = true,
  }) {
    final line = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55);
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: showRightDivider ? Border(right: BorderSide(color: line, width: 1)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  /// Kartična tablica (siva traka zaglavlja, bijeli redovi, tanki vertikalni razdjelnici).
  Widget _buildPreparationTrackingTable(
    BuildContext context,
    List<ProductionOperatorTrackingEntry> savedRows,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final headerStrip = isLight ? const Color(0xFFE0E4E7) : cs.surfaceContainerHigh;
    final frameLine = cs.outlineVariant.withValues(alpha: 0.72);
    final rowRule = cs.outlineVariant.withValues(alpha: 0.5);
    final scrapSum = _scrapSum();
    final seq = _sequenceByEntryId(savedRows);
    final defectNames = _mergedDefectNames();
    final headerStyle = TextStyle(
      color: cs.onSurface.withValues(alpha: 0.92),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final cellStyle = TextStyle(fontSize: 11, height: 1.25, color: cs.onSurface);

    final colW = <double>[
      _pwRb,
      _pwDt,
      _pwBl,
      _pwCd,
      _pwNm,
      _pwCu,
      _pwGd,
      _pwSc,
      _pwPo,
      _pwRo,
      _pwBy,
    ];

    Widget hLabel(String t, {required String tooltip, required double w}) {
      return SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
          child: Tooltip(
            message: tooltip,
            child: Text(
              t,
              style: headerStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    Widget oneLine(String text, {int maxLines = 2, TextAlign align = TextAlign.start}) {
      return Text(
        text,
        maxLines: maxLines,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: cellStyle,
      );
    }

    List<Widget> wrapBodyCells(List<Widget> children) {
      return [
        for (var i = 0; i < children.length; i++)
          _prepCardCell(
            context,
            width: colW[i],
            showRightDivider: i < children.length - 1,
            child: children[i],
          ),
      ];
    }

    Widget headerBand() {
      return DecoratedBox(
        decoration: BoxDecoration(color: headerStrip),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hLabel('R.br.', tooltip: 'Redni broj unosa (1 = zadnji spremljen u danu)', w: _pwRb),
            hLabel('Datum i vrijeme', tooltip: 'Automatski se postavlja pri spremanju', w: _pwDt),
            hLabel('Palica / šarž / lin.', tooltip: 'Broj palice, šarže ili linije', w: _pwBl),
            hLabel('Šifra kom.', tooltip: 'Šifra komada', w: _pwCd),
            hLabel('Naziv kom.', tooltip: 'Naziv komada', w: _pwNm),
            hLabel('Kupac', tooltip: 'Kupac', w: _pwCu),
            hLabel(
              _tableGoodColumnHeader(),
              tooltip: _tableGoodColumnTooltip(),
              w: _pwGd,
            ),
            hLabel('Škart ($_unit)', tooltip: 'Ukupna količina škarta', w: _pwSc),
            hLabel('Nalog sirov.', tooltip: 'Broj naloga izrade sirovih komada', w: _pwPo),
            hLabel('Op. izrada', tooltip: 'Ime operatera na izradi sirovih komada', w: _pwRo),
            hLabel('Pripremio', tooltip: 'Ime i prezime proizvodnog operatera koji je pripremio komade', w: _pwBy),
          ],
        ),
      );
    }

    Widget dataBand(List<Widget> cells) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: rowRule, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: wrapBodyCells(cells),
        ),
      );
    }

    final goodTapBg = isLight
        ? const Color(0xFFE8F5E9).withValues(alpha: 0.55)
        : cs.primaryContainer.withValues(alpha: 0.22);

    final draftCells = <Widget>[
      Text('—', style: cellStyle.copyWith(color: cs.onSurfaceVariant)),
      Text(
        'nakon spremanja',
        style: cellStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: cs.onSurfaceVariant,
        ),
      ),
      TextField(
        controller: _batchCtrl,
        style: cellStyle,
        decoration: _prepTableFieldDecoration(context, 'npr. P-12'),
      ),
      TextField(
        controller: _codeCtrl,
        focusNode: _codeFocus,
        style: cellStyle,
        textCapitalization: TextCapitalization.characters,
        decoration: _prepTableFieldDecoration(context, 'Šifra'),
      ),
      TextField(
        controller: _nameCtrl,
        focusNode: _nameFocus,
        style: cellStyle,
        decoration: _prepTableFieldDecoration(context, 'Naziv'),
      ),
      TextField(
        controller: _customerCtrl,
        style: cellStyle,
        decoration: _prepTableFieldDecoration(context, 'Kupac'),
      ),
      Material(
        color: goodTapBg,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _saving ? null : _editGoodQty,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              _goodQty > 0 ? _fmtQty(_goodQty) : 'Odaberi…',
              style: cellStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: _goodQty > 0 ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          scrapSum > 0 ? _fmtQty(scrapSum) : '—',
          style: cellStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      TextField(
        controller: _pnCtrl,
        style: cellStyle,
        decoration: _prepTableFieldDecoration(context, 'Nalog'),
      ),
      TextField(
        controller: _rawOperatorCtrl,
        style: cellStyle,
        decoration: _prepTableFieldDecoration(context, 'Operater'),
      ),
      Tooltip(
        message: 'Automatski iz prijave',
        child: Text(
          _preparedBySnapshot().isEmpty ? '—' : _preparedBySnapshot(),
          style: cellStyle.copyWith(fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    final bodyChunks = <Widget>[
      headerBand(),
      dataBand(draftCells),
    ];

    for (final e in savedRows) {
      final n = seq[e.id] ?? 0;
      final scrapQ = e.scrapTotalQty;
      bodyChunks.add(
        dataBand([
          oneLine('$n', maxLines: 1),
          oneLine(_formatPrepDateTime(e.createdAt), maxLines: 1),
          oneLine((e.lineOrBatchRef ?? '').isEmpty ? '—' : e.lineOrBatchRef!, maxLines: 2),
          oneLine(e.itemCode, maxLines: 1),
          oneLine(e.itemName, maxLines: 2),
          oneLine((e.customerName ?? '').isEmpty ? '—' : e.customerName!, maxLines: 2),
          Align(
            alignment: Alignment.centerRight,
            child: oneLine(_fmtQty(e.effectiveGoodQty), maxLines: 1, align: TextAlign.right),
          ),
          Tooltip(
            message: e.scrapBreakdownSummaryForDisplay(defectNames).isEmpty
                ? '—'
                : e.scrapBreakdownSummaryForDisplay(defectNames),
            child: Align(
              alignment: Alignment.centerRight,
              child: oneLine(
                scrapQ > 0 ? _fmtQty(scrapQ) : '—',
                maxLines: 1,
                align: TextAlign.right,
              ),
            ),
          ),
          oneLine(
            e.displayRawMaterialOrder.isEmpty ? '—' : e.displayRawMaterialOrder,
            maxLines: 2,
          ),
          oneLine(
            (e.rawWorkOperatorName ?? '').isEmpty ? '—' : e.rawWorkOperatorName!,
            maxLines: 2,
          ),
          oneLine(e.displayPreparedBy, maxLines: 2),
        ]),
      );
    }

    final mjBar = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: rowRule, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text('Jedinica mjere', style: headerStyle.copyWith(fontSize: 12)),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>(_unit),
                initialValue: _unit,
                isDense: true,
                decoration: _prepMjDropdownDecoration(context),
                items: const [
                  DropdownMenuItem(value: 'kom', child: Text('kom')),
                  DropdownMenuItem(value: 'kg', child: Text('kg')),
                  DropdownMenuItem(value: 'm', child: Text('m')),
                  DropdownMenuItem(value: 'm2', child: Text('m²')),
                  DropdownMenuItem(value: 'l', child: Text('l')),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _unit = v);
                      },
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: frameLine, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _prepTableScrollWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...bodyChunks,
                  _buildCatalogMatchesStrip(theme, cs),
                ],
              ),
            ),
          ),
          mjBar,
        ],
      ),
    );
  }

  Widget _qtyTiles(BuildContext context, List<ScrapTileDef> scrapDefs) {
    final tiles = <Widget>[
      _QuantityTile(
        title: _goodQtyTileTitle(),
        subtitle: _unit,
        value: _goodQty,
        accent: Colors.green.shade700,
        onTap: _saving ? null : _editGoodQty,
      ),
      for (final d in scrapDefs)
        _QuantityTile(
          title: d.label,
          subtitle: d.code,
          value: _scrapByCode[d.code] ?? 0,
          accent: Colors.deepOrange.shade700,
          onTap: _saving ? null : () => _editScrapQty(d),
        ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cross = w >= 920
            ? 5
            : w >= 720
            ? 4
            : w >= 520
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: w >= 920 ? 1.65 : (w >= 520 ? 1.35 : 1.12),
          children: tiles,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workKey = _workDateKey(_workDay);
    final scrapDefs = _scrapTiles();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                'Datum unosa: $workKey',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: 'Promijeni datum',
                icon: const Icon(Icons.edit_calendar_outlined),
                onPressed: _pickWorkDay,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Količine', style: theme.textTheme.titleMedium)),
                  if (_canEditCompanyDefectNames())
                    TextButton.icon(
                      onPressed: _openDefectLabelsEditor,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Nazivi tipova škarta'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _qtySectionIntro(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _qtyTiles(context, scrapDefs),
              const SizedBox(height: 24),
              Text('Unos i evidencija', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _fillFromCatalog,
                    icon: const Icon(Icons.manage_search_outlined),
                    label: const Text('Popuni naziv iz šifrarnika'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _scanRawPieceLabelQr,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    label: const Text('Skeniraj QR etiketu'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _printDraftLabel,
                    icon: const Icon(Icons.label_outline),
                    label: const Text('Ispiši etiketu (QR)'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Šifru ili naziv u tablici možeš ukucati ručno: ispod redova prikazuju se '
                'poklapanja iz šifrarnika (odabir popunjava polja). Gumb iznad traži točno po šifri.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Radni dan: $workKey',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ProductionOperatorTrackingEntry>>(
                stream: _service.watchDayPhase(
                  companyId: _companyId,
                  plantKey: _plantKey,
                  phase: widget.phase,
                  workDate: workKey,
                ),
                builder: (context, snap) {
                  if (!snap.hasData && !snap.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final rows = snap.hasData ? snap.data! : const <ProductionOperatorTrackingEntry>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (snap.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Greška učitavanja: ${snap.error}',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      _buildPreparationTrackingTable(context, rows),
                      if (snap.hasData && rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _emptyDayHint(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : () => _submit(scrapDefs),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Spremanje…' : 'Spremi red'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Napomena (opcionalno)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DefectDisplayNamesEditorDialog extends StatefulWidget {
  final String companyId;
  final Map<String, String> seedByCode;

  const _DefectDisplayNamesEditorDialog({
    required this.companyId,
    required this.seedByCode,
  });

  @override
  State<_DefectDisplayNamesEditorDialog> createState() =>
      _DefectDisplayNamesEditorDialogState();
}

class _DefectDisplayNamesEditorDialogState extends State<_DefectDisplayNamesEditorDialog> {
  final _svc = CompanyDefectDisplayNamesService();
  late final Map<String, TextEditingController> _c = {
    for (final code in PlatformDefectCodes.allCodes)
      code: TextEditingController(text: widget.seedByCode[code] ?? code),
  };
  bool _busy = false;

  @override
  void dispose() {
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Map<String, String> _effectiveFromControllers() {
    final m = <String, String>{};
    for (final code in PlatformDefectCodes.allCodes) {
      final t = _c[code]!.text.trim();
      m[code] = t.isEmpty ? code : t;
    }
    return m;
  }

  Map<String, String> _toFirestoreMap() {
    final out = <String, String>{};
    for (final code in PlatformDefectCodes.allCodes) {
      final t = _c[code]!.text.trim();
      if (t.isNotEmpty && t != code) {
        out[code] = t;
      }
    }
    return out;
  }

  Future<void> _onSave() async {
    setState(() => _busy = true);
    try {
      await _svc.save(
        companyId: widget.companyId,
        displayNamesByCode: _toFirestoreMap(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(_effectiveFromControllers());
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
    return AlertDialog(
      title: const Text('Prikazni nazivi tipova škarta'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kodovi (${PlatformDefectCodes.codeAt1Based(1)} … '
                '${PlatformDefectCodes.codeAt1Based(PlatformDefectCodes.count)}) su fiksni; '
                'uređuješ samo naziv koji vide operateri i izvještaji.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final code in PlatformDefectCodes.allCodes) ...[
                Text(code, style: theme.textTheme.labelSmall),
                TextField(
                  controller: _c[code],
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _busy ? null : _onSave,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Spremi'),
        ),
      ],
    );
  }
}

class _QuantityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final Color accent;
  final VoidCallback? onTap;

  const _QuantityTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final has = value > 0;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: has ? accent : theme.colorScheme.outlineVariant,
              width: has ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    fontSize: (theme.textTheme.titleSmall?.fontSize ?? 14) * 0.92,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: (theme.textTheme.labelSmall?.fontSize ?? 11) * 0.95,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        has ? _fmt(value) : 'Odaberi',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: (theme.textTheme.titleLarge?.fontSize ?? 22) * 0.88,
                          color: has ? accent : theme.hintColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.touch_app_outlined,
                      size: 20,
                      color: accent.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
