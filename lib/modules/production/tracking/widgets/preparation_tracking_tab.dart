import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../workforce/employee_profiles/workforce_employee_qr_navigation.dart';
import '../../../../core/theme/operonix_production_brand.dart';
import '../../../../core/ui/station_input.dart';
import '../../production_orders/models/production_order_model.dart';
import '../../production_orders/printing/classification_label_print_qr.dart';
import '../../production_orders/services/production_order_service.dart';
import '../../products/services/product_lookup_service.dart';
import '../../products/services/product_tracking_label_service.dart';
import '../../qr/production_qr_resolver.dart';
import '../../qr/screens/production_qr_scan_screen.dart';
import '../config/operator_tracking_column_labels.dart';
import '../config/operator_tracking_table_column_visibility_store.dart';
import '../config/preparation_station_ui_prefs.dart';
import '../config/station_tracking_setup_store.dart';
import '../config/tracking_station_plant_store.dart';
import '../offline/offline_tracking_queue.dart';
import '../config/platform_defect_codes.dart';
import '../models/production_operator_tracking_entry.dart';
import '../models/tracking_scrap_line.dart';
import '../export/tracking_station_label_pdf.dart';
import '../services/company_defect_display_names_service.dart';
import '../services/company_operator_tracking_column_labels_service.dart';
import '../services/production_operator_tracking_service.dart';
import '../../station_pages/models/production_station_page.dart';
import '../../packing/screens/station1_close_box_screen.dart';
import 'tracking_quantity_editor_sheet.dart';
import 'tracking_entry_correction_sheet.dart';

/// Operativni unos po fazi: brzi unos (QR + malo polja) ili ručni unos u tablici,
/// pločice za količine, QR skener i ispis etikete.
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

class _PreparationTrackingTabState extends State<PreparationTrackingTab>
    with WidgetsBindingObserver {
  final _service = ProductionOperatorTrackingService();
  final _lookup = ProductLookupService();
  final _orderService = ProductionOrderService();

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pnCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _releaseToolOrRodCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _rawOperatorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final FocusNode _batchFocus = FocusNode();
  final FocusNode _releaseToolFocus = FocusNode();
  final FocusNode _codeFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _customerFocus = FocusNode();
  final FocusNode _pnFocus = FocusNode();
  final FocusNode _rawOperatorFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  final _goodQtyCtrl = TextEditingController();
  final FocusNode _goodQtyFocus = FocusNode();
  final ScrollController _tableHScrollController = ScrollController();
  final FocusNode _qtyTilesFocusNode = FocusNode();

  /// Fokus s tipkovnice za pločice (dobro + škart); null = još nema odabira strelicama.
  int? _qtyTileKeyboardIndex;

  Timer? _offlineFlushTimer;

  /// Zadnji sken (debounce duplog istog QR-a).
  String? _lastQrRaw;
  DateTime? _lastQrAt;
  static const Duration _qrDebounceWindow = Duration(seconds: 2);

  /// Pogon: lista iz Firestore + odabir na stanici.
  List<String> _plantKeys = [];
  Map<String, String> _plantLabelByKey = {};
  String? _selectedStationPlantKey;
  bool _plantsLoading = true;
  Object? _plantsLoadError;

  /// Validacija prikaza (crveni obrubi).
  bool _attemptedSubmit = false;

  /// Status traka + offline red.
  String _statusLine = '';
  int _offlineQueueCount = 0;

  /// Brzi unos (QR + malo polja) ili puni ručni unos u tablici.
  bool _quickEntryMode = true;

  /// Naglasak boje za glavne gumbe (lokalno na uređaju).
  int _accentIndex = 0;

  /// Vanjski QR skener (tipkovnica) — skriveni unos.
  final TextEditingController _wedgeCtrl = TextEditingController();
  final FocusNode _wedgeFocus = FocusNode();

  /// Lokalno: koje kolone prikazati (default sve dok se ne učita).
  Map<String, bool> _columnVisibility = {};

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

  /// Kad nije null, koristi se umjesto `operatorTrackingColumnLabels` iz [widget.companyData]
  /// (nakon spremanja u editoru, da se poštuju i obrisani prilagođeni nazivi).
  Map<String, String>? _columnLabelsResolvedSnapshot;

  /// `null` = koristi vrijednost iz [widget.companyData].
  bool? _columnUiShowSystemHeadersSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    void onDraftTextChanged() {
      if (_muteCatalogFieldListeners) return;
      setState(() => _linkedProductId = null);
      _scheduleCatalogSearch();
      _touchDraftEdited();
    }

    _codeCtrl.addListener(onDraftTextChanged);
    _nameCtrl.addListener(onDraftTextChanged);
    _codeFocus.addListener(_scheduleCatalogSearch);
    _nameFocus.addListener(_scheduleCatalogSearch);
    _pnFocus.addListener(_onPnFocusChanged);
    for (final c in [
      _batchCtrl,
      _releaseToolOrRodCtrl,
      _customerCtrl,
      _rawOperatorCtrl,
      _pnCtrl,
    ]) {
      c.addListener(_touchDraftEdited);
    }
    _goodQtyCtrl.addListener(_touchDraftEdited);
    unawaited(_loadColumnVisibility());
    unawaited(_loadStationUiPrefs());
    unawaited(_loadPlants());
    unawaited(_refreshOfflineCount());
    unawaited(_tryFlushOfflineQueue(silent: true));
    _offlineFlushTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_tryFlushOfflineQueue(silent: true));
    });
    HardwareKeyboard.instance.addHandler(_onShortcutFocusQtyTiles);
  }

  /// Globalni prečac: Alt+Shift+P — fokus na mrežu pločica (radi i iz tekstualnih polja).
  bool _onShortcutFocusQtyTiles(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyP) return false;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final alt =
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
    final shift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    if (!alt || !shift) return false;
    _focusQtyTilesFromShortcut();
    return true;
  }

  void _focusQtyTilesFromShortcut() {
    if (!mounted) return;
    setState(() => _qtyTileKeyboardIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _qtyTilesFocusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadPlants());
      unawaited(_tryFlushOfflineQueue(silent: true));
    }
  }

  Future<void> _loadStationUiPrefs() async {
    final q = await PreparationStationUiPrefs.loadQuickMode();
    final a = await PreparationStationUiPrefs.loadAccentIndex();
    if (!mounted) return;
    setState(() {
      _quickEntryMode = q;
      _accentIndex = a;
    });
  }

  @override
  void didUpdateWidget(PreparationTrackingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      unawaited(_loadColumnVisibility());
    }
    final oldSb = (oldWidget.companyData['stationBoundPlantKey'] ?? '')
        .toString()
        .trim();
    final newSb = (widget.companyData['stationBoundPlantKey'] ?? '')
        .toString()
        .trim();
    if (oldSb != newSb) {
      unawaited(_loadPlants());
    }
  }

  Future<void> _loadColumnVisibility() async {
    final m = await OperatorTrackingTableColumnVisibilityStore.load(
      preparationPhase: _isPrepPhase,
    );
    if (!mounted) return;
    setState(() => _columnVisibility = m);
  }

  /// Kad je na PN-u upisan lot materijala (SK), preuzmi ga u šaržu/palicu bez dodatnog skeniranja.
  void _onPnFocusChanged() {
    if (!_pnFocus.hasFocus) {
      unawaited(_syncMaterialLotFromOrderReference());
    }
  }

  Future<void> _syncMaterialLotFromOrderReference() async {
    if (!mounted) return;
    final ref = _pnCtrl.text.trim();
    if (ref.isEmpty) return;
    if (_batchCtrl.text.trim().isNotEmpty) return;
    if (_companyId.isEmpty || _plantKeyEffective.isEmpty) return;

    try {
      ProductionOrderModel? order;
      try {
        order = await _orderService.getById(
          id: ref,
          companyId: _companyId,
          plantKey: _plantKeyEffective,
        );
      } catch (_) {
        order = null;
      }
      order ??= await _orderService.getByProductionOrderCode(
        companyId: _companyId,
        plantKey: _plantKeyEffective,
        productionOrderCode: ref,
      );
      if (!mounted || order == null) return;
      final lot = (order.inputMaterialLot ?? '').trim();
      if (lot.isEmpty) return;
      setState(() {
        _batchCtrl.text = lot;
      });
    } catch (_) {
      // Nalog nije pronađen ili nema pristup — polje ostaje ručno.
    }
  }

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool get _isAdminRole =>
      ProductionAccessHelper.isAdminRole(widget.companyData['role'] ?? '');

  String get _sessionPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  /// Pogon vezan za ovu dedicated stanicu na uređaju (postavlja admin pri prvom pokretanju).
  String get _stationBoundPlantKey =>
      (widget.companyData['stationBoundPlantKey'] ?? '').toString().trim();

  /// Isključivanje ispisa etikete (Callable postavlja na serveru; ovdje lokalne postavke preglednika/stanice).
  bool get _stationLabelPrintingEnabled {
    final v = widget.companyData['stationLabelPrintingEnabled'];
    if (v is bool) return v;
    return true;
  }

  String get _stationLabelLayoutKey {
    final raw =
        (widget.companyData['stationLabelLayout'] ??
                kStationLabelLayoutStandard)
            .toString()
            .trim();
    return kStationLabelLayoutKeys.contains(raw)
        ? raw
        : kStationLabelLayoutStandard;
  }

  /// Pogon za naloge i Firestore — odabir na stanici ili jedini pogon.
  String get _plantKeyEffective {
    if (_stationBoundPlantKey.isNotEmpty) {
      return _stationBoundPlantKey;
    }
    if (_plantKeys.length > 1) {
      return (_selectedStationPlantKey ?? '').trim();
    }
    if (_plantKeys.length == 1) return _plantKeys.first;
    return _sessionPlantKey;
  }

  bool get _plantSelectionReady {
    if (_plantsLoading) return false;
    if (_stationBoundPlantKey.isNotEmpty) {
      final pk = _stationBoundPlantKey;
      final up = _sessionPlantKey;
      return up.isNotEmpty && pk == up;
    }
    final pk = _plantKeyEffective;
    if (pk.isEmpty) return false;
    if (_plantKeys.length > 1) {
      final s = _selectedStationPlantKey?.trim() ?? '';
      return s.isNotEmpty && _plantKeys.contains(s);
    }
    return true;
  }

  bool get _valErrBatch =>
      _attemptedSubmit && _quickEntryMode && _batchCtrl.text.trim().isEmpty;

  bool get _valErrCode => _attemptedSubmit && _codeCtrl.text.trim().isEmpty;

  bool get _valErrName => _attemptedSubmit && _nameCtrl.text.trim().isEmpty;

  bool get _valErrQty {
    if (!_attemptedSubmit) return false;
    return _goodQty + _scrapSum() <= 0;
  }

  bool get _isPrepPhase =>
      widget.phase == ProductionOperatorTrackingEntry.phasePreparation;

  static String _str(dynamic v) => (v ?? '').toString().trim();

  String _plantLabelFromDoc(Map<String, dynamic> data, String fallbackId) {
    final displayName = _str(data['displayName']);
    final defaultName = _str(data['defaultName']);
    final plantCode = _str(data['plantCode']);
    final plantKey = _str(data['plantKey']);
    final base = displayName.isNotEmpty
        ? displayName
        : defaultName.isNotEmpty
        ? defaultName
        : plantKey.isNotEmpty
        ? plantKey
        : fallbackId;
    if (plantCode.isNotEmpty) return '$base ($plantCode)';
    return base;
  }

  Future<void> _loadPlants() async {
    if (_companyId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _plantsLoading = false;
        _plantKeys = [];
        _plantLabelByKey = {};
        _selectedStationPlantKey = _sessionPlantKey.isNotEmpty
            ? _sessionPlantKey
            : null;
      });
      _setDefaultStatusLine();
      return;
    }
    final bound = _stationBoundPlantKey;
    if (bound.isNotEmpty) {
      setState(() {
        _plantsLoading = true;
        _plantsLoadError = null;
      });
      try {
        final snap = await FirebaseFirestore.instance
            .collection('company_plants')
            .where('companyId', isEqualTo: _companyId)
            .get();
        String label = bound;
        for (final d in snap.docs) {
          final data = d.data();
          if (data['active'] == false) continue;
          final pk = _str(data['plantKey']).isNotEmpty
              ? _str(data['plantKey'])
              : d.id;
          if (pk == bound) {
            label = _plantLabelFromDoc(data, d.id);
            break;
          }
        }
        if (!mounted) return;
        setState(() {
          _plantKeys = [bound];
          _plantLabelByKey = {bound: label};
          _selectedStationPlantKey = bound;
          _plantsLoading = false;
        });
        _setDefaultStatusLine();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _plantsLoadError = e;
          _plantsLoading = false;
          _plantKeys = [bound];
          _plantLabelByKey = {bound: bound};
          _selectedStationPlantKey = bound;
        });
        _setDefaultStatusLine();
      }
      return;
    }
    setState(() {
      _plantsLoading = true;
      _plantsLoadError = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company_plants')
          .where('companyId', isEqualTo: _companyId)
          .get();
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final ao = (a.data()['order'] as num?)?.toInt() ?? 0;
        final bo = (b.data()['order'] as num?)?.toInt() ?? 0;
        if (ao != bo) return ao.compareTo(bo);
        return _plantLabelFromDoc(a.data(), a.id).toLowerCase().compareTo(
          _plantLabelFromDoc(b.data(), b.id).toLowerCase(),
        );
      });
      final keys = <String>[];
      final labels = <String, String>{};
      for (final d in docs) {
        final data = d.data();
        if (data['active'] == false) continue;
        final pk = _str(data['plantKey']).isNotEmpty
            ? _str(data['plantKey'])
            : d.id;
        if (pk.isEmpty) continue;
        keys.add(pk);
        labels[pk] = _plantLabelFromDoc(data, d.id);
      }
      final saved = await TrackingStationPlantStore.load(_companyId);
      String? pick;
      if (keys.length == 1) {
        pick = keys.first;
      } else if (!_isAdminRole) {
        pick = keys.contains(_sessionPlantKey)
            ? _sessionPlantKey
            : (keys.isNotEmpty ? keys.first : null);
      } else if (saved != null && keys.contains(saved)) {
        pick = saved;
      } else if (keys.contains(_sessionPlantKey)) {
        pick = _sessionPlantKey;
      } else if (keys.length > 1) {
        pick = null;
      } else {
        pick = _sessionPlantKey.isNotEmpty ? _sessionPlantKey : null;
      }

      if (!mounted) return;
      setState(() {
        _plantKeys = keys;
        _plantLabelByKey = labels;
        _selectedStationPlantKey = pick;
        _plantsLoading = false;
      });
      if (pick != null && keys.isNotEmpty) {
        await TrackingStationPlantStore.save(_companyId, pick);
      }
      _setDefaultStatusLine();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plantsLoadError = e;
        _plantsLoading = false;
        _plantKeys = [];
        _plantLabelByKey = {};
        _selectedStationPlantKey = _sessionPlantKey.isNotEmpty
            ? _sessionPlantKey
            : null;
      });
      _setDefaultStatusLine();
    }
  }

  void _setDefaultStatusLine() {
    if (!mounted) return;
    if (!_plantSelectionReady) {
      setState(() => _statusLine = 'Odaberi pogon prije unosa.');
    } else {
      setState(() => _statusLine = 'Spremno za unos.');
    }
  }

  Future<void> _refreshOfflineCount() async {
    if (kIsWeb) {
      if (mounted) setState(() => _offlineQueueCount = 0);
      return;
    }
    final n = await OfflineTrackingQueue.count();
    if (!mounted) return;
    setState(() => _offlineQueueCount = n);
    if (n > 0) {
      setState(
        () => _statusLine =
            'U redu čekanja: $n unosa (šalje se kad je mreža dostupna).',
      );
    }
  }

  bool _isNetworkFailure(Object e) {
    if (e is FirebaseException) {
      final c = e.code.toLowerCase();
      return c == 'unavailable' ||
          c == 'deadline-exceeded' ||
          c.contains('network') ||
          c == 'resource-exhausted';
    }
    final s = e.toString().toLowerCase();
    return s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('host lookup');
  }

  Future<void> _tryFlushOfflineQueue({bool silent = false}) async {
    if (kIsWeb) return;
    final all = await OfflineTrackingQueue.loadAll();
    if (all.isEmpty) {
      await _refreshOfflineCount();
      return;
    }
    var ok = 0;
    for (final item in List<Map<String, dynamic>>.from(all)) {
      final id = (item['localQueueId'] ?? '').toString();
      if (id.isEmpty) continue;
      try {
        final copy = Map<String, dynamic>.from(item)
          ..remove('localQueueId')
          ..remove('queuedAtMs');
        await _service.createEntryFromQueuePayload(copy);
        await OfflineTrackingQueue.removeByLocalQueueId(id);
        ok++;
      } catch (e) {
        if (!_isNetworkFailure(e)) break;
      }
    }
    await _refreshOfflineCount();
    if (!silent && mounted && ok > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Poslano iz reda čekanja: $ok.')));
    }
    if (mounted) _setDefaultStatusLine();
  }

  Future<void> _enqueueOfflineFromSubmit(Map<String, dynamic> payload) async {
    if (kIsWeb) {
      throw StateError('web');
    }
    await OfflineTrackingQueue.enqueue(payload);
    await _refreshOfflineCount();
  }

  void _focusAfterSuccessfulSaveQuick() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _wedgeFocus.requestFocus();
    });
  }

  void _touchDraftEdited() {
    if (_attemptedSubmit) setState(() => _attemptedSubmit = false);
  }

  InputDecoration _tableCellDec(
    BuildContext context,
    String hint, {
    String? errorText,
  }) {
    final base = StationInputDecoration.tableCell(context, hint);
    if (errorText == null || errorText.isEmpty) return base;
    final cs = Theme.of(context).colorScheme;
    return base.copyWith(
      errorText: errorText,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: cs.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }

  Map<String, String> _mergedColumnLabels() {
    return _columnLabelsResolvedSnapshot ??
        parseOperatorTrackingColumnLabels(widget.companyData);
  }

  bool _mergedShowSystemHeaders() {
    if (_columnUiShowSystemHeadersSession != null) {
      return _columnUiShowSystemHeadersSession!;
    }
    return parseOperatorTrackingColumnUi(widget.companyData).showSystemHeaders;
  }

  String _workDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Klasifikacija u JSON etiketi (usklađeno s BOM katalogom).
  String _classificationForLabels() {
    if (_stationBoundPlantKey.isNotEmpty) {
      final sc = (widget.companyData['stationTrackingClassification'] ?? '')
          .toString()
          .trim();
      if (sc.isNotEmpty) return sc.toUpperCase();
    }
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

  String _scanLabelLoadedSnack() => 'Podaci s etikete su učitani.';

  String _scanOrderQrSnack() => 'Proizvodni nalog je učitan iz QR koda.';

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

  static bool _bytesLookLikePdf(Uint8List b) {
    if (b.length < 4) return false;
    return b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46;
  }

  /// Šifra u tablici + opcionalno povezani proizvod iz šifrarnika.
  Future<String?> _resolveProductIdForLabelPrint() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _companyId.isEmpty) return null;
    final linked = _linkedProductId?.trim();
    if (linked != null && linked.isNotEmpty) return linked;
    final hit = await _lookup.getByExactCode(
      companyId: _companyId,
      productCode: code,
      onlyActive: false,
    );
    return hit?.productId;
  }

  Future<void> _openStation1CloseBox() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final rawPn = _pnCtrl.text.trim();
    final pn = rawPn.isEmpty ? null : rawPn;
    final linked = _linkedProductId?.trim();
    final productId = (linked != null && linked.isNotEmpty) ? linked : null;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Station1CloseBoxScreen(
          companyData: widget.companyData,
          classification: _classificationForLabels(),
          workDateKey: _workDateKey(_workDay),
          stationSlot: ProductionStationPage.stationSlotForPhase(widget.phase),
          initialDraft: Station1DraftSnapshot(
            productCode: code,
            productName: name,
            qtyGood: _goodQty,
            unit: _unit,
            productionOrderCode: pn,
            productId: productId,
            trackingEntryId: null,
          ),
        ),
      ),
    );
  }

  Future<void> _printDraftLabel() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_labelPrintNeedCodeNameMessage())));
      return;
    }

    final productId = await _resolveProductIdForLabelPrint();
    if (productId != null && productId.isNotEmpty) {
      try {
        final custom = await ProductTrackingLabelService.loadForPrint(
          productId,
        );
        if (custom != null) {
          final ct = custom.contentType.toLowerCase();
          final asPdf = ct.contains('pdf') || _bytesLookLikePdf(custom.bytes);
          if (asPdf) {
            await TrackingStationLabelPdf.printPrebuiltPdfBytes(custom.bytes);
          } else {
            await TrackingStationLabelPdf.printRasterImageAsA6Pdf(custom.bytes);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ispis: prilagođena etiketa proizvoda (upload).'),
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Prilagođena etiketa: $e')));
        return;
      }
    }

    final rawPn = _pnCtrl.text.trim();
    final pn = rawPn.isEmpty ? 'RUČNO-${_workDateKey(_workDay)}' : rawPn;
    final op = _preparedBySnapshot().trim().isEmpty
        ? '—'
        : _preparedBySnapshot().trim();
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
        labelLayoutKey: _stationLabelLayoutKey,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ispis etikete: $e')));
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

  Future<void> _openColumnLabelsEditor() async {
    if (!_canEditCompanyDefectNames() || _companyId.isEmpty) return;
    final merged = _mergedColumnLabels();
    final showSys = _mergedShowSystemHeaders();
    final result = await showDialog<_ColumnLabelsEditResult>(
      context: context,
      builder: (ctx) => _OperatorTrackingColumnLabelsEditorDialog(
        companyId: _companyId,
        phase: widget.phase,
        unit: _unit,
        seedLabels: merged,
        showSystemHeaders: showSys,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _columnLabelsResolvedSnapshot = result.labels.isEmpty
            ? <String, String>{}
            : Map<String, String>.from(result.labels);
        _columnUiShowSystemHeadersSession = result.showSystemHeaders;
      });
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

  Widget _trackingHeaderLabel(
    BuildContext context, {
    required String columnKey,
    required double w,
    required TextStyle headerStyle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final labels = _mergedColumnLabels();
    final showSys = _mergedShowSystemHeaders();
    final title = resolvedOperatorTrackingColumnTitle(
      columnKey,
      companyLabels: labels,
      phase: widget.phase,
      unit: _unit,
    );
    final tooltip = resolvedOperatorTrackingColumnTooltip(
      columnKey,
      phase: widget.phase,
    );
    final sys = operatorTrackingColumnSystemLine(columnKey);
    final muted = cs.onSurface.withValues(alpha: 0.58);
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Tooltip(
          message: tooltip,
          child: showSys
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sys,
                      style: headerStyle.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: muted,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: headerStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Text(
                  title,
                  style: headerStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }

  /// U brzom načinu samo polja potrebna na liniji (bez škarta, datuma u nacrtu, itd.).
  List<String> _visibleColumnKeysQuick() {
    return [
      OperatorTrackingColumnKeys.lineOrBatchRef,
      if (_isPrepPhase) OperatorTrackingColumnKeys.releaseToolOrRodRef,
      OperatorTrackingColumnKeys.itemCode,
      OperatorTrackingColumnKeys.itemName,
      OperatorTrackingColumnKeys.goodQty,
      OperatorTrackingColumnKeys.actions,
    ];
  }

  List<String> _visibleColumnKeys() {
    if (_quickEntryMode) {
      return _visibleColumnKeysQuick();
    }
    final order = OperatorTrackingTableColumnVisibilityStore.keysInOrder(
      preparationPhase: _isPrepPhase,
    );
    if (_columnVisibility.isEmpty) return order;
    return order.where((k) => _columnVisibility[k] != false).toList();
  }

  bool _columnVisible(String key) => _visibleColumnKeys().contains(key);

  double _widthForKey(String k) {
    switch (k) {
      case OperatorTrackingColumnKeys.rowIndex:
        return _pwRb;
      case OperatorTrackingColumnKeys.prepDateTime:
        return _pwDt;
      case OperatorTrackingColumnKeys.lineOrBatchRef:
        return _pwBl;
      case OperatorTrackingColumnKeys.releaseToolOrRodRef:
        return _pwTr;
      case OperatorTrackingColumnKeys.itemCode:
        return _pwCd;
      case OperatorTrackingColumnKeys.itemName:
        return _pwNm;
      case OperatorTrackingColumnKeys.customerName:
        return _pwCu;
      case OperatorTrackingColumnKeys.goodQty:
        return _pwGd;
      case OperatorTrackingColumnKeys.scrapTotal:
        return _pwSc;
      case OperatorTrackingColumnKeys.rawMaterialOrder:
        return _pwPo;
      case OperatorTrackingColumnKeys.rawWorkOperator:
        return _pwRo;
      case OperatorTrackingColumnKeys.preparedBy:
        return _pwBy;
      case OperatorTrackingColumnKeys.actions:
        return _pwAc;
      default:
        return 80;
    }
  }

  double _prepTableScrollWidthComputed() {
    var s = 0.0;
    for (final k in _visibleColumnKeys()) {
      s += _widthForKey(k);
    }
    return s;
  }

  FocusNode? _nextAfterBatch() {
    if (_isPrepPhase &&
        _columnVisible(OperatorTrackingColumnKeys.releaseToolOrRodRef)) {
      return _releaseToolFocus;
    }
    return _codeFocus;
  }

  FocusNode? _nextAfterGoodQtyField() {
    if (_columnVisible(OperatorTrackingColumnKeys.rawMaterialOrder)) {
      return _pnFocus;
    }
    if (_columnVisible(OperatorTrackingColumnKeys.rawWorkOperator)) {
      return _rawOperatorFocus;
    }
    return _notesFocus;
  }

  FocusNode? _nextAfterCustomer() {
    if (_columnVisible(OperatorTrackingColumnKeys.goodQty)) {
      return _goodQtyFocus;
    }
    return _nextAfterGoodQtyField();
  }

  FocusNode? _nextAfterPn() {
    if (_columnVisible(OperatorTrackingColumnKeys.rawWorkOperator)) {
      return _rawOperatorFocus;
    }
    return _notesFocus;
  }

  Future<void> _openTableColumnVisibility() async {
    final keys = OperatorTrackingTableColumnVisibilityStore.keysInOrder(
      preparationPhase: _isPrepPhase,
    );
    final copy = <String, bool>{
      for (final k in keys) k: (_columnVisibility[k] != false),
    };
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('Vidljive kolone u tablici'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Možeš sakriti kolone koje ti ne trebaju. Šifra, naziv i količina '
                        'dobrog uvijek ostaju.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final k in keys) ...[
                        CheckboxListTile(
                          dense: true,
                          value: copy[k] != false,
                          onChanged:
                              OperatorTrackingTableColumnVisibilityStore
                                  .lockedKeys
                                  .contains(k)
                              ? null
                              : (v) {
                                  setSt(() => copy[k] = v ?? false);
                                },
                          title: Text(
                            resolvedOperatorTrackingColumnTitle(
                              k,
                              companyLabels: _mergedColumnLabels(),
                              phase: widget.phase,
                              unit: _unit,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, Map<String, bool>.from(copy)),
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    await OperatorTrackingTableColumnVisibilityStore.save(result);
    setState(() => _columnVisibility = result);
  }

  /// R.br. 1 = najnoviji unos (isti redoslijed kao stream: `createdAt` desc).
  Map<String, int> _sequenceByEntryId(
    List<ProductionOperatorTrackingEntry> rows,
  ) {
    final sorted = [...rows]
      ..sort((a, b) {
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
  static const double _pwTr = 108;
  static const double _pwCd = 82;
  static const double _pwNm = 208;
  static const double _pwCu = 112;
  static const double _pwGd = 78;
  static const double _pwSc = 54;
  static const double _pwPo = 104;
  static const double _pwRo = 114;
  static const double _pwBy = 124;
  static const double _pwAc = 44;

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
    _catalogDebounce = Timer(
      const Duration(milliseconds: 280),
      _runCatalogSearch,
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _offlineFlushTimer?.cancel();
    _catalogDebounce?.cancel();
    _pnFocus.removeListener(_onPnFocusChanged);
    _batchFocus.dispose();
    _releaseToolFocus.dispose();
    _codeFocus.dispose();
    _nameFocus.dispose();
    _customerFocus.dispose();
    _pnFocus.dispose();
    _rawOperatorFocus.dispose();
    _notesFocus.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _pnCtrl.dispose();
    _batchCtrl.dispose();
    _releaseToolOrRodCtrl.dispose();
    _customerCtrl.dispose();
    _rawOperatorCtrl.dispose();
    _notesCtrl.dispose();
    _goodQtyCtrl.dispose();
    _goodQtyFocus.dispose();
    _tableHScrollController.dispose();
    _wedgeCtrl.dispose();
    _wedgeFocus.dispose();
    HardwareKeyboard.instance.removeHandler(_onShortcutFocusQtyTiles);
    _qtyTilesFocusNode.dispose();
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
          const SnackBar(
            content: Text('Nema aktivnog proizvoda s tom šifrom.'),
          ),
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
    _syncGoodQtyText();
  }

  /// Nakon skeniranja u brzom načinu: sljedeće što operater ručno upisuje (šarža / alat / količina).
  void _focusQuickEntryAfterQr() {
    if (!_quickEntryMode || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final batchEmpty = _batchCtrl.text.trim().isEmpty;
      final releaseEmpty = _releaseToolOrRodCtrl.text.trim().isEmpty;
      if (batchEmpty) {
        _batchFocus.requestFocus();
      } else if (_isPrepPhase && releaseEmpty) {
        _releaseToolFocus.requestFocus();
      } else {
        _goodQtyFocus.requestFocus();
      }
    });
  }

  void _resetDraftForNewEntry() {
    _muteCatalogFieldListeners = true;
    try {
      setState(() {
        _batchCtrl.clear();
        _releaseToolOrRodCtrl.clear();
        _customerCtrl.clear();
        _pnCtrl.clear();
        _codeCtrl.clear();
        _nameCtrl.clear();
        _goodQty = 0;
        _scrapByCode.clear();
        _linkedProductId = null;
        _sourceQrPayload = null;
      });
      _goodQtyCtrl.clear();
    } finally {
      _muteCatalogFieldListeners = false;
    }
  }

  Future<void> _applyQrResolution(
    ProductionQrScanResolution resolution, {
    required bool clearDraftForNewEntry,
  }) async {
    if (!mounted) return;
    final raw = resolution.rawPayload.trim();
    if (raw.isNotEmpty) {
      final now = DateTime.now();
      if (_lastQrRaw == raw &&
          _lastQrAt != null &&
          now.difference(_lastQrAt!) < _qrDebounceWindow) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Isti kod je upravo obraden. Pričekaj trenutak ili skeniraj drugi.',
              ),
            ),
          );
        }
        return;
      }
      _lastQrRaw = raw;
      _lastQrAt = now;
    }
    if (clearDraftForNewEntry) {
      _resetDraftForNewEntry();
    }

    switch (resolution.intent) {
      case ProductionQrIntent.workforceEmployeeV1:
        if (!mounted) return;
        await openWorkforceEmployeeFromBadgeQr(
          context: context,
          companyData: widget.companyData,
          rawPayload: resolution.rawPayload,
        );
        break;

      case ProductionQrIntent.printedClassificationLabelV1:
        final m = resolution.labelFields;
        if (m == null) break;
        final pcode = (m['pcode'] ?? '').toString().trim();
        final piece = (m['piece'] ?? '').toString().trim();
        final pn = (m['pn'] ?? '').toString().trim();
        if (pcode.isEmpty && piece.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Na etiketi nedostaju šifra i naziv komada.'),
            ),
          );
          return;
        }
        final cust = (m['customer'] ?? m['customerName'] ?? '')
            .toString()
            .trim();
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
        await _syncMaterialLotFromOrderReference();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_scanLabelLoadedSnack())));
        _focusQuickEntryAfterQr();
        break;

      case ProductionQrIntent.packedStation1BoxV1:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ovo je QR zatvorene kutije za logistiku. Otvori „Upakovane kutije Stanica 1“ i skeniraj ga tamo.',
            ),
          ),
        );
        break;

      case ProductionQrIntent.productionOrderReferenceV1:
        final id = resolution.productionOrderId?.trim();
        if (id == null || id.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ovaj QR nalog nije valjan. Pokušaj s etiketom komada.',
              ),
            ),
          );
          return;
        }
        setState(() {
          _pnCtrl.text = id;
          _sourceQrPayload = resolution.rawPayload;
        });
        await _syncMaterialLotFromOrderReference();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_scanOrderQrSnack())));
        _focusQuickEntryAfterQr();
        break;

      case ProductionQrIntent.wmsLotDocV1:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ovo je WMS etiketa lota. Koristi modul WMS — centralni magacin (putaway / otprem).',
            ),
          ),
        );
        break;

      case ProductionQrIntent.logisticsReceiptDocV1:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Koristi skener u logističkom hubu za prijem.'),
          ),
        );
        break;

      case ProductionQrIntent.nepoznat:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kod nije prepoznat. Očekuje se etiketa komada ili proizvodni nalog.',
            ),
          ),
        );
        break;
    }
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
    await _applyQrResolution(
      resolution,
      clearDraftForNewEntry: _quickEntryMode,
    );
  }

  Future<void> _onScannerWedgeSubmitted(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final resolution = resolveProductionQrScan(trimmed);
    await _applyQrResolution(
      resolution,
      clearDraftForNewEntry: _quickEntryMode,
    );
    _wedgeCtrl.clear();
    if (!mounted) return;
    if (!_quickEntryMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _wedgeFocus.requestFocus();
      });
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
    if (v != null && mounted) {
      setState(() => _goodQty = v);
      _syncGoodQtyText();
    }
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
    _goodQtyCtrl.clear();
  }

  void _syncGoodQtyText() {
    final t = _goodQty > 0 ? _fmtQty(_goodQty) : '';
    if (_goodQtyCtrl.text == t) return;
    _goodQtyCtrl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _onGoodQtyFieldChanged(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) {
      setState(() => _goodQty = 0);
      return;
    }
    final v = double.tryParse(t);
    if (v == null) return;
    setState(() => _goodQty = v < 0 ? 0 : v);
  }

  Future<void> _submit(List<ScrapTileDef> scrapDefs) async {
    if (_companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesija nije valjana. Odjavi se i ponovo prijavi.'),
        ),
      );
      return;
    }
    if (!_plantSelectionReady) {
      setState(() => _statusLine = 'Odaberi pogon prije spremanja.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi pogon za ovu stanicu.')),
      );
      return;
    }

    setState(() => _attemptedSubmit = true);

    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final scrapLines = _scrapLinesForSave(scrapDefs);
    final scrapSum = scrapLines.fold<double>(0, (a, b) => a + b.qty);

    if (code.isEmpty || name.isEmpty) {
      setState(
        () => _statusLine = 'Dopuni polja označena u tablici (šifra i naziv).',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _quickEntryMode
                ? 'Skeniraj etiketu komada ili prebaci na ručni unos.'
                : 'Unesi šifru i naziv artikla.',
          ),
        ),
      );
      return;
    }
    if (_quickEntryMode && _batchCtrl.text.trim().isEmpty) {
      setState(() => _statusLine = 'Upiši šaržu ili palicu.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upiši šaržu ili palicu.')));
      return;
    }
    if (_goodQty + scrapSum <= 0) {
      setState(
        () => _statusLine =
            'Upiši količinu pripremljenog komada ili škarta (pločice).',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_submitNeedPositiveQtyMessage())));
      return;
    }

    Map<String, dynamic>? queuePayload;
    setState(() => _saving = true);
    try {
      final rawPn = _pnCtrl.text.trim();
      queuePayload = <String, dynamic>{
        'companyId': _companyId,
        'plantKey': _plantKeyEffective,
        'phase': widget.phase,
        'workDate': _workDateKey(_workDay),
        'itemCode': code,
        'itemName': name,
        'goodQty': _goodQty,
        'unit': _unit,
        'productId': _linkedProductId,
        'productionOrderId': rawPn.isEmpty ? null : rawPn,
        'rawMaterialOrderCode': rawPn.isEmpty ? null : rawPn,
        'lineOrBatchRef': _batchCtrl.text.trim().isEmpty
            ? null
            : _batchCtrl.text.trim(),
        'releaseToolOrRodRef':
            _isPrepPhase && _releaseToolOrRodCtrl.text.trim().isNotEmpty
            ? _releaseToolOrRodCtrl.text.trim()
            : null,
        'customerName': _customerCtrl.text.trim().isEmpty
            ? null
            : _customerCtrl.text.trim(),
        'rawWorkOperatorName': _rawOperatorCtrl.text.trim().isEmpty
            ? null
            : _rawOperatorCtrl.text.trim(),
        'preparedByDisplayName': _preparedBySnapshot().isEmpty
            ? null
            : _preparedBySnapshot(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'scrapBreakdown': scrapLines.map((e) => e.toMap()).toList(),
        'sourceQrPayload': _sourceQrPayload,
      };

      await _service.createEntry(
        companyId: _companyId,
        plantKey: _plantKeyEffective,
        phase: widget.phase,
        workDate: _workDateKey(_workDay),
        itemCode: code,
        itemName: name,
        goodQty: _goodQty,
        unit: _unit,
        productId: _linkedProductId,
        productionOrderId: rawPn.isEmpty ? null : rawPn,
        rawMaterialOrderCode: rawPn.isEmpty ? null : rawPn,
        lineOrBatchRef: _batchCtrl.text.trim().isEmpty
            ? null
            : _batchCtrl.text.trim(),
        releaseToolOrRodRef:
            _isPrepPhase && _releaseToolOrRodCtrl.text.trim().isNotEmpty
            ? _releaseToolOrRodCtrl.text.trim()
            : null,
        customerName: _customerCtrl.text.trim().isEmpty
            ? null
            : _customerCtrl.text.trim(),
        rawWorkOperatorName: _rawOperatorCtrl.text.trim().isEmpty
            ? null
            : _rawOperatorCtrl.text.trim(),
        preparedByDisplayName: _preparedBySnapshot().isEmpty
            ? null
            : _preparedBySnapshot(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        scrapBreakdown: scrapLines,
        sourceQrPayload: _sourceQrPayload,
      );
      if (!mounted) return;
      _notesCtrl.clear();
      _batchCtrl.clear();
      _releaseToolOrRodCtrl.clear();
      _customerCtrl.clear();
      _rawOperatorCtrl.clear();
      _pnCtrl.clear();
      _codeCtrl.clear();
      _nameCtrl.clear();
      _resetDraftQuantities();
      setState(() {
        _sourceQrPayload = null;
        _attemptedSubmit = false;
      });
      setState(() => _statusLine = 'Spremljeno.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveSuccessMessage())));
      if (_quickEntryMode) {
        _focusAfterSuccessfulSaveQuick();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _batchFocus.requestFocus();
        });
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (_isNetworkFailure(e) && !kIsWeb && queuePayload != null) {
        try {
          await _enqueueOfflineFromSubmit(
            Map<String, dynamic>.from(queuePayload),
          );
          if (!mounted) return;
          _notesCtrl.clear();
          _batchCtrl.clear();
          _releaseToolOrRodCtrl.clear();
          _customerCtrl.clear();
          _rawOperatorCtrl.clear();
          _pnCtrl.clear();
          _codeCtrl.clear();
          _nameCtrl.clear();
          _resetDraftQuantities();
          setState(() {
            _sourceQrPayload = null;
            _attemptedSubmit = false;
          });
          setState(
            () => _statusLine =
                'Nema veze. Unos je u redu čekanja i poslat će se kad mreža proradi.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nema mreže — unos je spremljen lokalno i poslat će se automatski.',
              ),
            ),
          );
          if (_quickEntryMode) _focusAfterSuccessfulSaveQuick();
        } catch (err) {
          setState(
            () => _statusLine =
                'Nije moguće spremiti ni offline. Pokušaj ponovo.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Offline spremanje nije uspjelo: $err')),
          );
        }
      } else {
        setState(() => _statusLine = 'Greška pri spremanju. Pokušaj ponovo.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (_isNetworkFailure(e) && !kIsWeb && queuePayload != null) {
        try {
          await _enqueueOfflineFromSubmit(
            Map<String, dynamic>.from(queuePayload),
          );
          if (!mounted) return;
          _notesCtrl.clear();
          _batchCtrl.clear();
          _releaseToolOrRodCtrl.clear();
          _customerCtrl.clear();
          _rawOperatorCtrl.clear();
          _pnCtrl.clear();
          _codeCtrl.clear();
          _nameCtrl.clear();
          _resetDraftQuantities();
          setState(() {
            _sourceQrPayload = null;
            _attemptedSubmit = false;
          });
          setState(
            () => _statusLine =
                'Nema veze. Unos je u redu čekanja i poslat će se kad mreža proradi.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nema mreže — unos je spremljen lokalno i poslat će se automatski.',
              ),
            ),
          );
          if (_quickEntryMode) _focusAfterSuccessfulSaveQuick();
        } catch (err) {
          setState(() => _statusLine = 'Spremanje nije uspjelo.');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$err')));
        }
      } else {
        setState(() => _statusLine = 'Greška pri spremanju.');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _prepMjDropdownDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final soft = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
      ),
    );
    return InputDecoration(
      filled: true,
      fillColor: cs.surface,
      border: soft,
      enabledBorder: soft,
      focusedBorder: soft.copyWith(
        borderSide: const BorderSide(
          color: kOperonixProductionBrandGreen,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }

  Widget _prepCardCell(
    BuildContext context, {
    required double width,
    required Widget child,
    bool showRightDivider = true,
  }) {
    final line = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.55);
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: showRightDivider
            ? Border(right: BorderSide(color: line, width: 1))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _trackingTableDraftCell(
    BuildContext context,
    String k,
    TextStyle cellStyle,
    ColorScheme cs,
    Color goodTapBg,
  ) {
    final scrapSum = _scrapSum();
    switch (k) {
      case OperatorTrackingColumnKeys.rowIndex:
        return Text('—', style: cellStyle.copyWith(color: cs.onSurfaceVariant));
      case OperatorTrackingColumnKeys.prepDateTime:
        return Text(
          'nakon spremanja',
          style: cellStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: cs.onSurfaceVariant,
          ),
        );
      case OperatorTrackingColumnKeys.lineOrBatchRef:
        return StationTextField(
          controller: _batchCtrl,
          focusNode: _batchFocus,
          nextFocus: _nextAfterBatch(),
          style: cellStyle,
          enabled: !_saving,
          decoration: _tableCellDec(
            context,
            'npr. P-12',
            errorText: _valErrBatch ? 'Obavezno' : null,
          ),
        );
      case OperatorTrackingColumnKeys.releaseToolOrRodRef:
        return StationTextField(
          controller: _releaseToolOrRodCtrl,
          focusNode: _releaseToolFocus,
          nextFocus: _codeFocus,
          style: cellStyle,
          enabled: !_saving,
          decoration: StationInputDecoration.tableCell(
            context,
            'Alat / palica',
          ),
        );
      case OperatorTrackingColumnKeys.itemCode:
        return StationTextField(
          controller: _codeCtrl,
          focusNode: _codeFocus,
          nextFocus: _nameFocus,
          style: cellStyle,
          enabled: !_saving,
          textCapitalization: TextCapitalization.characters,
          decoration: _tableCellDec(
            context,
            'Šifra',
            errorText: _valErrCode ? 'Obavezno' : null,
          ),
        );
      case OperatorTrackingColumnKeys.itemName:
        return StationTextField(
          controller: _nameCtrl,
          focusNode: _nameFocus,
          nextFocus: _customerFocus,
          style: cellStyle,
          enabled: !_saving,
          decoration: _tableCellDec(
            context,
            'Naziv',
            errorText: _valErrName ? 'Obavezno' : null,
          ),
        );
      case OperatorTrackingColumnKeys.customerName:
        return StationTextField(
          controller: _customerCtrl,
          focusNode: _customerFocus,
          nextFocus: _nextAfterCustomer(),
          style: cellStyle,
          enabled: !_saving,
          decoration: StationInputDecoration.tableCell(context, 'Kupac'),
        );
      case OperatorTrackingColumnKeys.goodQty:
        return Container(
          decoration: BoxDecoration(
            color: goodTapBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: StationTextField(
            controller: _goodQtyCtrl,
            focusNode: _goodQtyFocus,
            nextFocus: _nextAfterGoodQtyField(),
            style: cellStyle,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: _onGoodQtyFieldChanged,
            decoration: _tableCellDec(
              context,
              'Količina',
              errorText: _valErrQty ? 'Obavezno' : null,
            ),
          ),
        );
      case OperatorTrackingColumnKeys.scrapTotal:
        return Align(
          alignment: Alignment.centerRight,
          child: Text(
            scrapSum > 0 ? _fmtQty(scrapSum) : '—',
            style: cellStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      case OperatorTrackingColumnKeys.rawMaterialOrder:
        return StationTextField(
          controller: _pnCtrl,
          focusNode: _pnFocus,
          nextFocus: _nextAfterPn(),
          style: cellStyle,
          enabled: !_saving,
          decoration: StationInputDecoration.tableCell(context, 'Nalog'),
        );
      case OperatorTrackingColumnKeys.rawWorkOperator:
        return StationTextField(
          controller: _rawOperatorCtrl,
          focusNode: _rawOperatorFocus,
          nextFocus: _notesFocus,
          style: cellStyle,
          enabled: !_saving,
          decoration: StationInputDecoration.tableCell(context, 'Operater'),
        );
      case OperatorTrackingColumnKeys.preparedBy:
        return Tooltip(
          message: 'Automatski iz prijave',
          child: Text(
            _preparedBySnapshot().isEmpty ? '—' : _preparedBySnapshot(),
            style: cellStyle.copyWith(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      case OperatorTrackingColumnKeys.actions:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _trackingTableSavedCell(
    BuildContext context,
    String k,
    ProductionOperatorTrackingEntry e,
    int rowNum,
    Map<String, String> defectNames,
    TextStyle cellStyle,
    ColorScheme cs,
  ) {
    Text oneLine(
      String text, {
      int maxLines = 2,
      TextAlign align = TextAlign.start,
    }) {
      return Text(
        text,
        maxLines: maxLines,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: cellStyle,
      );
    }

    final scrapQ = e.scrapTotalQty;
    switch (k) {
      case OperatorTrackingColumnKeys.rowIndex:
        return oneLine('$rowNum', maxLines: 1);
      case OperatorTrackingColumnKeys.prepDateTime:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            oneLine(_formatPrepDateTime(e.createdAt), maxLines: 1),
            if (e.correctionApplied)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Ispravljeno'
                  '${e.correctedAt != null ? ' · ${_formatPrepDateTime(e.correctedAt)}' : ''}',
                  style: cellStyle.copyWith(
                    fontSize: 9,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      case OperatorTrackingColumnKeys.lineOrBatchRef:
        return oneLine(
          (e.lineOrBatchRef ?? '').isEmpty ? '—' : e.lineOrBatchRef!,
          maxLines: 2,
        );
      case OperatorTrackingColumnKeys.releaseToolOrRodRef:
        return oneLine(
          (e.releaseToolOrRodRef ?? '').isEmpty ? '—' : e.releaseToolOrRodRef!,
          maxLines: 2,
        );
      case OperatorTrackingColumnKeys.itemCode:
        return oneLine(e.itemCode, maxLines: 1);
      case OperatorTrackingColumnKeys.itemName:
        return oneLine(e.itemName, maxLines: 2);
      case OperatorTrackingColumnKeys.customerName:
        return oneLine(
          (e.customerName ?? '').isEmpty ? '—' : e.customerName!,
          maxLines: 2,
        );
      case OperatorTrackingColumnKeys.goodQty:
        return Align(
          alignment: Alignment.centerRight,
          child: oneLine(
            _fmtQty(e.effectiveGoodQty),
            maxLines: 1,
            align: TextAlign.right,
          ),
        );
      case OperatorTrackingColumnKeys.scrapTotal:
        return Tooltip(
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
        );
      case OperatorTrackingColumnKeys.rawMaterialOrder:
        return oneLine(
          e.displayRawMaterialOrder.isEmpty ? '—' : e.displayRawMaterialOrder,
          maxLines: 2,
        );
      case OperatorTrackingColumnKeys.rawWorkOperator:
        return oneLine(
          (e.rawWorkOperatorName ?? '').isEmpty ? '—' : e.rawWorkOperatorName!,
          maxLines: 2,
        );
      case OperatorTrackingColumnKeys.preparedBy:
        return oneLine(e.displayPreparedBy, maxLines: 2);
      case OperatorTrackingColumnKeys.actions:
        return _trackingSavedRowActions(context, e, cs);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _trackingSavedRowActions(
    BuildContext context,
    ProductionOperatorTrackingEntry e,
    ColorScheme cs,
  ) {
    if (e.correctionApplied) {
      return Tooltip(
        message: (e.correctionReason ?? '').trim().isEmpty
            ? 'Ispravak je već iskorišten.'
            : e.correctionReason!.trim(),
        child: Icon(Icons.check_circle_outline, size: 20, color: cs.primary),
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final own = uid.isNotEmpty && uid == e.createdByUid;
    final inBox = e.packedBoxId != null && e.packedBoxId!.trim().isNotEmpty;
    if (!own) {
      return const SizedBox.shrink();
    }
    if (inBox) {
      return Tooltip(
        message: 'Stavka je u kutiji — ispravak nije moguć.',
        child: Icon(Icons.inventory_2_outlined, size: 18, color: cs.outline),
      );
    }
    return IconButton(
      tooltip: 'Jednokratna ispravka unosa',
      icon: const Icon(Icons.edit_outlined, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
      onPressed: _saving
          ? null
          : () => unawaited(_openCorrectionForEntry(context, e)),
    );
  }

  Future<void> _openCorrectionForEntry(
    BuildContext context,
    ProductionOperatorTrackingEntry e,
  ) async {
    await showTrackingEntryCorrectionSheet(
      context: context,
      entry: e,
      companyId: _companyId,
      preparationPhase: _isPrepPhase,
      service: _service,
      companyData: widget.companyData,
    );
  }

  /// Kartična tablica (siva traka zaglavlja, bijeli redovi, tanki vertikalni razdjelnici).
  Widget _buildPreparationTrackingTable(
    BuildContext context,
    List<ProductionOperatorTrackingEntry> savedRows, {
    required bool showDraftRow,
    required bool showSavedRows,
    required bool includeCatalogStrip,
    bool includeMjBar = true,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final headerStrip = isLight
        ? const Color(0xFFE0E4E7)
        : cs.surfaceContainerHigh;
    final frameLine = cs.outlineVariant.withValues(alpha: 0.72);
    final rowRule = cs.outlineVariant.withValues(alpha: 0.5);
    final seq = _sequenceByEntryId(savedRows);
    final defectNames = _mergedDefectNames();
    final headerStyle = TextStyle(
      color: cs.onSurface.withValues(alpha: 0.92),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final cellStyle = TextStyle(
      fontSize: 11,
      height: 1.25,
      color: cs.onSurface,
    );

    final vk = _visibleColumnKeys();
    final colW = vk.map(_widthForKey).toList();

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
            for (final k in vk)
              _trackingHeaderLabel(
                context,
                columnKey: k,
                w: _widthForKey(k),
                headerStyle: headerStyle,
              ),
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
      for (final k in vk)
        _trackingTableDraftCell(context, k, cellStyle, cs, goodTapBg),
    ];

    final bodyChunks = <Widget>[headerBand()];
    if (showDraftRow) {
      bodyChunks.add(dataBand(draftCells));
    }

    if (showSavedRows) {
      for (final e in savedRows) {
        final n = seq[e.id] ?? 0;
        bodyChunks.add(
          dataBand([
            for (final k in vk)
              _trackingTableSavedCell(
                context,
                k,
                e,
                n,
                defectNames,
                cellStyle,
                cs,
              ),
          ]),
        );
      }
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
          Scrollbar(
            controller: _tableHScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _tableHScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _prepTableScrollWidthComputed(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...bodyChunks,
                    if (showDraftRow && includeCatalogStrip)
                      _buildCatalogMatchesStrip(theme, cs),
                  ],
                ),
              ),
            ),
          ),
          if (includeMjBar) mjBar,
        ],
      ),
    );
  }

  static int _crossAxisCountForQtyTiles(double w) {
    if (w >= 920) return 5;
    if (w >= 720) return 4;
    if (w >= 520) return 3;
    return 2;
  }

  KeyEventResult _handleQtyTilesKeyEvent(
    KeyEvent event, {
    required int total,
    required int cross,
    required List<ScrapTileDef> scrapDefs,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_saving || total <= 0) return KeyEventResult.ignored;

    final key = event.logicalKey;

    void moveTo(int idx) {
      if (!mounted) return;
      setState(() => _qtyTileKeyboardIndex = idx.clamp(0, total - 1));
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_qtyTileKeyboardIndex == null) {
        moveTo(0);
      } else {
        final cur = _qtyTileKeyboardIndex!.clamp(0, total - 1);
        final next = cur + 1;
        moveTo(next >= total ? 0 : next);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_qtyTileKeyboardIndex == null) {
        moveTo(total - 1);
      } else {
        final cur = _qtyTileKeyboardIndex!.clamp(0, total - 1);
        final next = cur - 1;
        moveTo(next < 0 ? total - 1 : next);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_qtyTileKeyboardIndex == null) {
        moveTo(0);
      } else {
        final cur = _qtyTileKeyboardIndex!.clamp(0, total - 1);
        final next = cur + cross;
        if (next < total) moveTo(next);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_qtyTileKeyboardIndex == null) {
        moveTo(total - 1);
      } else {
        final cur = _qtyTileKeyboardIndex!.clamp(0, total - 1);
        final next = cur - cross;
        if (next >= 0) moveTo(next);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      var idx = _qtyTileKeyboardIndex;
      if (idx == null) {
        idx = 0;
        moveTo(0);
      } else {
        idx = idx.clamp(0, total - 1);
      }
      if (idx == 0) {
        unawaited(_editGoodQty());
      } else {
        unawaited(_editScrapQty(scrapDefs[idx - 1]));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _qtyTiles(BuildContext context, List<ScrapTileDef> scrapDefs) {
    final total = 1 + scrapDefs.length;
    int? effectiveKb(int? raw) {
      if (raw == null) return null;
      if (total <= 0) return null;
      return raw.clamp(0, total - 1);
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cross = _crossAxisCountForQtyTiles(w);
        final kb = effectiveKb(_qtyTileKeyboardIndex);
        final showKbRing =
            _qtyTilesFocusNode.hasFocus && kb != null && !_saving;

        final tiles = <Widget>[
          _QuantityTile(
            title: _goodQtyTileTitle(),
            subtitle: _unit,
            value: _goodQty,
            accent: Colors.green.shade700,
            isKeyboardFocused: showKbRing && kb == 0,
            onTap: _saving
                ? null
                : () {
                    setState(() => _qtyTileKeyboardIndex = 0);
                    _qtyTilesFocusNode.requestFocus();
                    _editGoodQty();
                  },
          ),
          for (var i = 0; i < scrapDefs.length; i++)
            _QuantityTile(
              title: scrapDefs[i].label,
              subtitle: scrapDefs[i].code,
              value: _scrapByCode[scrapDefs[i].code] ?? 0,
              accent: Colors.deepOrange.shade700,
              isKeyboardFocused: showKbRing && kb == i + 1,
              onTap: _saving
                  ? null
                  : () {
                      setState(() => _qtyTileKeyboardIndex = i + 1);
                      _qtyTilesFocusNode.requestFocus();
                      _editScrapQty(scrapDefs[i]);
                    },
            ),
        ];

        return ScrollIntoViewOnFocus(
          focusNode: _qtyTilesFocusNode,
          alignment: 0.45,
          child: Focus(
            focusNode: _qtyTilesFocusNode,
            skipTraversal: false,
            onKeyEvent: (node, event) => _handleQtyTilesKeyEvent(
              event,
              total: total,
              cross: cross,
              scrapDefs: scrapDefs,
            ),
            child: Semantics(
              label:
                  'Pločice količina: Alt+Shift+P za fokus (i iz polja), Tab do ovog područja, strelice za odabir, Enter ili razmak za unos.',
              child: GridView.count(
                crossAxisCount: cross,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: w >= 920 ? 1.65 : (w >= 520 ? 1.35 : 1.12),
                children: tiles,
              ),
            ),
          ),
        );
      },
    );
  }

  static const List<Color> _kAccentColors = [
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFFEF6C00),
    Color(0xFF6A1B9A),
  ];

  static const List<String> _kAccentLabels = [
    'Zelena',
    'Plava',
    'Narančasta',
    'Ljubičasta',
  ];

  ThemeData _themedForAccents(ThemeData base) {
    final accent =
        _kAccentColors[_accentIndex.clamp(0, _kAccentColors.length - 1)];
    final cs = base.colorScheme;
    return base.copyWith(
      colorScheme: cs.copyWith(
        primary: accent,
        primaryContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.16),
          cs.surface,
        ),
      ),
    );
  }

  void _showPrepScreenHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kako radi ovaj ekran'),
        content: const SingleChildScrollView(
          child: Text(
            'Ako ih je više, samo korisnik s ulogom admin može odabrati pogon za ovu stanicu; '
            'ostali vide svoj pogon iz profila. Unosi se vode za taj pogon. '
            'Brzi unos: skeniraj etiketu komada (gumb ili vanjski uređaj na stanici), '
            'upiši šaržu ili alat i količinu pripremljenih komada, zatim potvrdi. '
            'Datum i vrijeme unosa dodaju se automatski kad spremiš.\n\n'
            'Ručni unos: ispuni podatke u tablici (šifra ili naziv, nalog, operator, količine) '
            'i potvrdi.\n\n'
            'Za količine škarta koristi pločice; nazive vrsta postavlja korisnik s ulogom admin. '
            'Tipkovnica: Alt+Shift+P odmah prebacuje fokus na pločice (radi i iz polja); '
            'inače Tab do područja pločica, strelice za pomicanje odabira, Enter ili razmak za unos (bez miša). '
            'Ako nema mreže, unos može ostati u redu čekanja i poslati se kasnije.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  void _showCatalogHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Šifrarnik'),
        content: const Text(
          'Kad upisuješ šifru ili naziv u tablici, ispod se nude prijedlozi iz šifrarnika. '
          'Gumb „Popuni naziv“ u izborniku traži točno po šifri.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workKey = _workDateKey(_workDay);
    final scrapDefs = _scrapTiles();
    final themed = _themedForAccents(theme);

    return Theme(
      data: themed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Datum unosa: $workKey',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fokus na pločice količina (Alt+Shift+P)',
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      onPressed: _saving ? null : _focusQtyTilesFromShortcut,
                    ),
                    IconButton(
                      tooltip: 'Kako radi ovaj ekran',
                      icon: const Icon(Icons.info_outline),
                      onPressed: _showPrepScreenHelpDialog,
                    ),
                    IconButton(
                      tooltip: 'Promijeni datum',
                      icon: const Icon(Icons.edit_calendar_outlined),
                      onPressed: _pickWorkDay,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Tema gumba',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    for (var i = 0; i < _kAccentColors.length; i++)
                      ChoiceChip(
                        label: Text(_kAccentLabels[i]),
                        selected: _accentIndex == i,
                        onSelected: (v) {
                          if (!v) return;
                          setState(() => _accentIndex = i);
                          unawaited(
                            PreparationStationUiPrefs.saveAccentIndex(i),
                          );
                        },
                      ),
                  ],
                ),
                if (_plantsLoadError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Pogone nije moguće učitati. Koristi se pogon iz prijave.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (_stationBoundPlantKey.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pogon stanice: ${_plantLabelByKey[_stationBoundPlantKey] ?? _stationBoundPlantKey}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (_plantKeys.length > 1) ...[
                  const SizedBox(height: 10),
                  if (_isAdminRole)
                    DropdownButtonFormField<String>(
                      key: ValueKey<String?>(_selectedStationPlantKey),
                      initialValue:
                          _selectedStationPlantKey != null &&
                              _plantKeys.contains(_selectedStationPlantKey)
                          ? _selectedStationPlantKey
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pogon (obavezno za ovu stanicu)',
                      ),
                      items: [
                        for (final pk in _plantKeys)
                          DropdownMenuItem<String>(
                            value: pk,
                            child: Text(
                              _plantLabelByKey[pk] ?? pk,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving || _plantsLoading
                          ? null
                          : (v) async {
                              if (v == null) return;
                              setState(() => _selectedStationPlantKey = v);
                              await TrackingStationPlantStore.save(
                                _companyId,
                                v,
                              );
                              _setDefaultStatusLine();
                            },
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pogon: ${_plantLabelByKey[_plantKeyEffective] ?? _plantKeyEffective}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ] else if (_plantKeys.length == 1) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pogon: ${_plantLabelByKey[_plantKeys.first] ?? _plantKeys.first}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Material(
                  color: _offlineQueueCount > 0
                      ? theme.colorScheme.tertiaryContainer.withValues(
                          alpha: 0.45,
                        )
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.65,
                        ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _offlineQueueCount > 0
                              ? Icons.cloud_queue_outlined
                              : Icons.info_outline,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusLine.isEmpty
                                ? (_plantsLoading ? 'Učitavanje…' : 'Spremno.')
                                : _statusLine,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_offlineQueueCount > 0)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => unawaited(
                                    _tryFlushOfflineQueue(silent: false),
                                  ),
                            child: const Text('Pošalji sada'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _plantsLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : !_plantSelectionReady
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _stationBoundPlantKey.isNotEmpty &&
                                _stationBoundPlantKey != _sessionPlantKey
                            ? 'Pogon na ovoj stanici ne odgovara tvom korisniku. Odjavi se i prijavi računom korisnika tog pogona.'
                            : _plantKeys.length > 1
                            ? 'Odaberi pogon za ovu stanicu (izbornik iznad).'
                            : 'Pogon nije definiran u sustavu. Obrati se korisniku s ulogom admin.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  )
                : StreamBuilder<List<ProductionOperatorTrackingEntry>>(
                    stream: _service.watchDayPhase(
                      companyId: _companyId,
                      plantKey: _plantKeyEffective,
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
                      final rows = snap.hasData
                          ? snap.data!
                          : const <ProductionOperatorTrackingEntry>[];

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('Brzi unos'),
                                icon: Icon(Icons.bolt_outlined),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                label: Text('Ručni unos'),
                                icon: Icon(Icons.edit_note_outlined),
                              ),
                            ],
                            selected: {_quickEntryMode},
                            onSelectionChanged: (Set<bool> s) {
                              final v = s.first;
                              setState(() => _quickEntryMode = v);
                              unawaited(
                                PreparationStationUiPrefs.saveQuickMode(v),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          if (snap.hasError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Podaci se ne mogu učitati. Pokušaj ponovo.',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          if (_quickEntryMode) ...[
                            ScrollIntoViewOnFocus(
                              focusNode: _wedgeFocus,
                              child: TextField(
                                controller: _wedgeCtrl,
                                focusNode: _wedgeFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Vanjski QR skener',
                                  hintText: 'Fokus ovdje, zatim skeniraj',
                                ),
                                onSubmitted: (s) =>
                                    unawaited(_onScannerWedgeSubmitted(s)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : _scanRawPieceLabelQr,
                                    icon: const Icon(
                                      Icons.qr_code_scanner_outlined,
                                    ),
                                    label: const Text('Skeniraj QR'),
                                  ),
                                ),
                                if (_isPrepPhase) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: _saving
                                          ? null
                                          : _openStation1CloseBox,
                                      icon: const Icon(
                                        Icons.inventory_2_outlined,
                                      ),
                                      label: const Text('Zatvori kutiju'),
                                    ),
                                  ),
                                ] else if (_stationLabelPrintingEnabled) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: _saving
                                          ? null
                                          : _printDraftLabel,
                                      icon: const Icon(Icons.label_outline),
                                      label: const Text('Ispiši etiketu'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Trenutni unos',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _openTableColumnVisibility,
                                  icon: const Icon(
                                    Icons.view_column_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Kolone'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildPreparationTrackingTable(
                              context,
                              rows,
                              showDraftRow: true,
                              showSavedRows: false,
                              includeCatalogStrip: false,
                              includeMjBar: true,
                            ),
                            const SizedBox(height: 8),
                            ExpansionTile(
                              initiallyExpanded: false,
                              title: Text('Današnji unosi (${rows.length})'),
                              children: [
                                if (rows.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    child: Text(
                                      _emptyDayHint(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                else
                                  _buildPreparationTrackingTable(
                                    context,
                                    rows,
                                    showDraftRow: false,
                                    showSavedRows: true,
                                    includeCatalogStrip: false,
                                    includeMjBar: false,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _submit(scrapDefs),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _saving ? 'Spremanje…' : 'Potvrdi unos',
                              ),
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Količine',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Šifrarnik i pločice',
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 22,
                                  ),
                                  onPressed: _showCatalogHelpDialog,
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Još opcija',
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'fill',
                                      enabled: !_saving,
                                      child: const Text(
                                        'Popuni naziv iz šifrarnika',
                                      ),
                                    ),
                                    if (_canEditCompanyDefectNames()) ...[
                                      const PopupMenuItem(
                                        value: 'defect',
                                        child: Text('Nazivi tipova škarta'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'labels',
                                        child: Text('Nazivi kolona u praćenju'),
                                      ),
                                    ],
                                  ],
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'fill':
                                        unawaited(_fillFromCatalog());
                                      case 'defect':
                                        unawaited(_openDefectLabelsEditor());
                                      case 'labels':
                                        unawaited(_openColumnLabelsEditor());
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _qtyTiles(context, scrapDefs),
                            const SizedBox(height: 20),
                            Text(
                              'Unos u tablicu',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : _scanRawPieceLabelQr,
                                    icon: const Icon(
                                      Icons.qr_code_scanner_outlined,
                                    ),
                                    label: const Text('Skeniraj QR'),
                                  ),
                                ),
                                if (_isPrepPhase) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: _saving
                                          ? null
                                          : _openStation1CloseBox,
                                      icon: const Icon(
                                        Icons.inventory_2_outlined,
                                      ),
                                      label: const Text('Zatvori kutiju'),
                                    ),
                                  ),
                                ] else if (_stationLabelPrintingEnabled) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.tonalIcon(
                                      onPressed: _saving
                                          ? null
                                          : _printDraftLabel,
                                      icon: const Icon(Icons.label_outline),
                                      label: const Text('Ispiši etiketu'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            ScrollIntoViewOnFocus(
                              focusNode: _wedgeFocus,
                              child: TextField(
                                controller: _wedgeCtrl,
                                focusNode: _wedgeFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Vanjski QR skener',
                                  hintText: 'Fokus ovdje, zatim skeniraj',
                                ),
                                onSubmitted: (s) =>
                                    unawaited(_onScannerWedgeSubmitted(s)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Radni dan: $workKey',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _openTableColumnVisibility,
                                  icon: const Icon(
                                    Icons.view_column_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Kolone'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildPreparationTrackingTable(
                              context,
                              rows,
                              showDraftRow: true,
                              showSavedRows: true,
                              includeCatalogStrip: true,
                              includeMjBar: true,
                            ),
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
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _submit(scrapDefs),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _saving ? 'Spremanje…' : 'Potvrdi unos',
                              ),
                            ),
                            const SizedBox(height: 12),
                            StationTextField(
                              controller: _notesCtrl,
                              focusNode: _notesFocus,
                              maxLines: 2,
                              decoration: StationInputDecoration.formField(
                                context,
                                labelText: 'Napomena (opcionalno)',
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
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

class _DefectDisplayNamesEditorDialogState
    extends State<_DefectDisplayNamesEditorDialog> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
                  decoration: const InputDecoration(),
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

class _ColumnLabelsEditResult {
  final Map<String, String> labels;
  final bool showSystemHeaders;

  const _ColumnLabelsEditResult({
    required this.labels,
    required this.showSystemHeaders,
  });
}

class _OperatorTrackingColumnLabelsEditorDialog extends StatefulWidget {
  final String companyId;
  final String phase;
  final String unit;
  final Map<String, String> seedLabels;
  final bool showSystemHeaders;

  const _OperatorTrackingColumnLabelsEditorDialog({
    required this.companyId,
    required this.phase,
    required this.unit,
    required this.seedLabels,
    required this.showSystemHeaders,
  });

  @override
  State<_OperatorTrackingColumnLabelsEditorDialog> createState() =>
      _OperatorTrackingColumnLabelsEditorDialogState();
}

class _OperatorTrackingColumnLabelsEditorDialogState
    extends State<_OperatorTrackingColumnLabelsEditorDialog> {
  /// Kolone u horizontalnoj tablici na stanici (unos operatera).
  static const List<String> _keysTable = [
    OperatorTrackingColumnKeys.rowIndex,
    OperatorTrackingColumnKeys.prepDateTime,
    OperatorTrackingColumnKeys.lineOrBatchRef,
    OperatorTrackingColumnKeys.releaseToolOrRodRef,
    OperatorTrackingColumnKeys.itemCode,
    OperatorTrackingColumnKeys.itemName,
    OperatorTrackingColumnKeys.customerName,
    OperatorTrackingColumnKeys.goodQty,
    OperatorTrackingColumnKeys.scrapTotal,
    OperatorTrackingColumnKeys.rawMaterialOrder,
    OperatorTrackingColumnKeys.rawWorkOperator,
    OperatorTrackingColumnKeys.preparedBy,
    OperatorTrackingColumnKeys.actions,
  ];

  /// Zaglavlja koja postoje samo u PDF dnevnog lista (naslovi šifre, naziva, dobra, škarta
  /// dijele iste ključeve kao u tablici iznad — ne ponavljaju se ovdje).
  static const List<String> _keysPdfOnly = [
    OperatorTrackingColumnKeys.quantityTotal,
    OperatorTrackingColumnKeys.unit,
    OperatorTrackingColumnKeys.productionOrderNumber,
    OperatorTrackingColumnKeys.commercialOrderNumber,
    OperatorTrackingColumnKeys.notes,
    OperatorTrackingColumnKeys.operatorEmail,
  ];

  final _svc = CompanyOperatorTrackingColumnLabelsService();
  late final Map<String, TextEditingController> _c = {
    for (final k in [..._keysTable, ..._keysPdfOnly])
      k: TextEditingController(text: widget.seedLabels[k] ?? ''),
  };
  late bool _showSys = widget.showSystemHeaders;
  bool _busy = false;

  @override
  void dispose() {
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Map<String, String> _labelsToSave() {
    final out = <String, String>{};
    for (final k in [..._keysTable, ..._keysPdfOnly]) {
      final t = _c[k]!.text.trim();
      if (t.isNotEmpty) out[k] = t;
    }
    return out;
  }

  Widget _buildKeyEditor(ThemeData theme, String k) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            operatorTrackingColumnSystemLine(k),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Ugrađeno: ${defaultOperatorTrackingColumnTitle(k, phase: widget.phase, unit: widget.unit)}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _c[k],
            enabled: !_busy,
            decoration: const InputDecoration(
              hintText: 'Prilagođeni naziv (opcionalno)',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    setState(() => _busy = true);
    try {
      final labels = _labelsToSave();
      await _svc.save(
        companyId: widget.companyId,
        labelsByKey: labels,
        showSystemHeaders: _showSys,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _ColumnLabelsEditResult(labels: labels, showSystemHeaders: _showSys),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Nazivi kolona u praćenju'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ključevi u sustavu ostaju isti (npr. lineOrBatchRef). '
                'Ovdje mijenjaš samo tekst koji vide ljudi. Prazno polje = ugrađeni naziv.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Prikaži sistemsku oznaku u zaglavlju tablice',
                ),
                subtitle: const Text(
                  'Drugi red: tehnički ključ polja. Isključi ako operaterima smeta.',
                ),
                value: _showSys,
                onChanged: _busy ? null : (v) => setState(() => _showSys = v),
              ),
              const Divider(height: 28),
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'Tablica na stanici',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Kolone u širokoj tablici za unos (pripremna faza, prva i završna kontrola).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                children: [
                  for (final k in _keysTable) _buildKeyEditor(theme, k),
                ],
              ),
              const SizedBox(height: 4),
              ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'PDF — dnevni list praćenja',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Dodatne kolone koje postoje samo u ispisu PDF-a. '
                  'Za vrijeme, šifru, naziv, dobro, škart i slično koriste se isti nazivi '
                  'kao u tablici iznad — ne treba ih ponovno unositi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                children: [
                  for (final k in _keysPdfOnly) _buildKeyEditor(theme, k),
                ],
              ),
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
  final bool isKeyboardFocused;
  final VoidCallback? onTap;

  const _QuantityTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    this.isKeyboardFocused = false,
    required this.onTap,
  });

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final has = value > 0;
    final borderColor = isKeyboardFocused
        ? theme.colorScheme.primary
        : (has ? accent : theme.colorScheme.outlineVariant);
    final double borderWidth = isKeyboardFocused ? 2.5 : (has ? 2.0 : 1.0);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
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
                    fontSize:
                        (theme.textTheme.titleSmall?.fontSize ?? 14) * 0.92,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize:
                        (theme.textTheme.labelSmall?.fontSize ?? 11) * 0.95,
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
                          fontSize:
                              (theme.textTheme.titleLarge?.fontSize ?? 22) *
                              0.88,
                          color: has ? accent : theme.hintColor,
                        ),
                      ),
                    ),
                    Icon(
                      isKeyboardFocused
                          ? Icons.keyboard_outlined
                          : Icons.touch_app_outlined,
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
