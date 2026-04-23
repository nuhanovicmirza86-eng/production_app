import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

import '../production_orders/models/production_order_model.dart';
import '../production_orders/services/production_order_service.dart';
import '../execution/services/production_execution_service.dart';
import '../tracking/services/production_asset_display_lookup.dart';
import 'models/planning_conflict.dart';
import 'models/planning_delivery_risk.dart';
import 'models/planning_engine_result.dart';
import 'models/planning_schedule_strategy.dart';
import 'models/scheduled_operation.dart';
import 'services/planning_engine_service.dart';
import 'services/planning_gantt_dto.dart';
import 'services/planning_mes_gantt_merge.dart';
import 'services/planning_execution_variance_service.dart';
import 'services/production_plan_persistence_service.dart';

/// Zajedničko stanje planiranja za [ProductionPlanningHomeScreen] i tabove.
class PlanningSessionController extends ChangeNotifier {
  PlanningSessionController(this.companyId, this.plantKey)
      : _engine = PlanningEngineService(),
        _orderService = ProductionOrderService(),
        _persistence = ProductionPlanPersistenceService(),
        _executionService = ProductionExecutionService(),
        _varianceService = PlanningExecutionVarianceService() {
    perfController = TextEditingController(text: '0.65');
    setupController = TextEditingController(text: '30');
    cycleController = TextEditingController(text: '60');
  }

  final String companyId;
  final String plantKey;

  final PlanningEngineService _engine;
  final ProductionOrderService _orderService;
  final ProductionPlanPersistenceService _persistence;
  final ProductionExecutionService _executionService;
  final PlanningExecutionVarianceService _varianceService;

  late final TextEditingController perfController;
  late final TextEditingController setupController;
  late final TextEditingController cycleController;

  PlanningEngineResult? result;
  String? lastSavedPlanId;
  bool busy = false;
  String? errorMessage;
  bool saving = false;
  int horizonDays = 14;
  /// F4.3 — redoslijed naloga u FCS: EDD (rok) ili SPT (kraći procijenjeni posao prvi).
  PlanningScheduleStrategy scheduleStrategy = PlanningScheduleStrategy.eddDueDate;
  int scenarioIndex = 0;
  /// 0=smjena, 1=dan, 2=tjedan (povezat će se s MES/šiftom kasnije).
  int timeScopeIndex = 1;

  List<ProductionOrderModel> pool = [];
  final Set<String> selectedOrderIds = {};
  final Set<String> excludedOrderIds = {};
  bool loadingPool = true;
  String? poolError;
  String searchQuery = '';
  /// Povećava se ručno (gumb) da se u Provedbi ponovo učitaju MES očitavanja.
  int mesBoardRefreshToken = 0;

  /// Nakon Gantt nudge-a; reset nakon uspješnog [generatePlan].
  bool _localGanttNudged = false;

  bool get hasLocalGanttNudges => _localGanttNudged;

  /// Brzi filteri prikaza poola (AND). Povezivanje s master filterima = kasnije.
  bool poolFilterHasMachine = false;
  /// `null` = ne filtrirati. Inače: [requestedDeliveryDate] u manje od toliko dana (isti prag kao prijašnji „rizik roka” za 3 d).
  int? poolFilterDueWithinDays;
  bool poolFilterNoMachine = false;
  /// `null` = svi strojevi. Inače [ProductionOrderModel.machineId] (točan zapis s naloga).
  String? poolFilterMachineId;
  /// `null` = sve. Inače točno podudaranje [ProductionOrderModel.operationName].
  String? poolFilterOperationName;
  /// `null` = sve linije. [ProductionOrderModel.lineId].
  String? poolFilterLineId;
  /// `null` = svi. Točan kupac s naloga (prikaz imena u poolu).
  String? poolFilterCustomerName;
  /// FCS (plave) + MES (narandžaste) u Ganttu.
  bool showMesGanttOverlay = true;
  bool _mesGanttLoading = false;
  PlanningGanttDto? _ganttWithMes;
  final Set<String> _dismissedEngineConflictKeys = {};
  /// Faza 3: uzrok po `ScheduledOperation.id` (draft do spremanja; Firestore nakon [saveDraft] + Spremi uzroke).
  final Map<String, String> _varianceRootByClientOpId = {};
  final Map<String, String> _varianceNotesByClientOpId = {};
  String? _executionVariancesLoadedForPlanId;
  bool persistingExecutionVariances = false;
  ProductionOrderModel? selectedOrder;
  Map<String, String> ganttMachineLabels = const {};
  String? ganttLabelForResultId;
  /// Ime stroja s poola (šifarnik) kada Gantt još nema taj resurs.
  Map<String, String> _poolMachineIdLabels = const {};

  void setScheduleStrategy(PlanningScheduleStrategy s) {
    if (scheduleStrategy == s) {
      return;
    }
    scheduleStrategy = s;
    notifyListeners();
  }

  bool get isLocked => busy || saving;

  /// Prikaz u tablici / karticama: pretraga, zatim brzi filteri (AND).
  List<ProductionOrderModel> get ordersForTable {
    var list = _filterBySearch();
    if (poolFilterHasMachine) {
      list = list.where((o) => (o.machineId ?? '').trim().isNotEmpty).toList();
    }
    if (poolFilterDueWithinDays != null) {
      final n = poolFilterDueWithinDays!;
      list = list
          .where(
            (o) {
              final d = o.requestedDeliveryDate;
              return d != null && d.difference(DateTime.now()).inDays < n;
            },
          )
          .toList();
    }
    if (poolFilterNoMachine) {
      list = list.where((o) => (o.machineId ?? '').trim().isEmpty).toList();
    }
    if (poolFilterMachineId != null) {
      final m = poolFilterMachineId!.trim();
      if (m.isNotEmpty) {
        list = list.where((o) => (o.machineId ?? '').trim() == m).toList();
      }
    }
    if (poolFilterOperationName != null) {
      final on = poolFilterOperationName!.trim();
      if (on.isNotEmpty) {
        list = list.where((o) => (o.operationName ?? '').trim() == on).toList();
      }
    }
    if (poolFilterLineId != null) {
      final l = poolFilterLineId!.trim();
      if (l.isNotEmpty) {
        list = list.where((o) => (o.lineId ?? '').trim() == l).toList();
      }
    }
    if (poolFilterCustomerName != null) {
      final c = poolFilterCustomerName!.trim();
      if (c.isNotEmpty) {
        list = list
            .where(
              (o) =>
                  ((o.customerName ?? o.sourceCustomerName) ?? '')
                      .trim() ==
                  c,
            )
            .toList();
      }
    }
    return list;
  }

  String poolMachineLabel(String machineId) {
    final t = machineId.trim();
    if (t.isEmpty) {
      return '—';
    }
    return ganttMachineLabels[t] ?? _poolMachineIdLabels[t] ?? t;
  }

  /// Neparovi (id, kratki prikaz) za dropdown stroja, sortirano po labeli.
  List<({String id, String label})> get machineFilterOptions {
    final ids = <String>{};
    for (final o in pool) {
      final m = o.machineId?.trim();
      if (m != null && m.isNotEmpty) {
        ids.add(m);
      }
    }
    final out = <({String id, String label})>[];
    for (final id in ids) {
      out.add((id: id, label: poolMachineLabel(id)));
    }
    out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return out;
  }

  List<String> get poolDistinctOperationNames {
    final s = <String>{};
    for (final o in pool) {
      final n = o.operationName?.trim();
      if (n != null && n.isNotEmpty) {
        s.add(n);
      }
    }
    final list = s.toList()..sort();
    return list;
  }

  List<ProductionOrderModel> _filterBySearch() {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List<ProductionOrderModel>.from(pool);
    return pool
        .where(
          (o) =>
              o.productionOrderCode.toLowerCase().contains(q) ||
              o.productName.toLowerCase().contains(q) ||
              o.productCode.toLowerCase().contains(q),
        )
        .toList();
  }

  void setPoolFilterHasMachine(bool value) {
    poolFilterHasMachine = value;
    notifyListeners();
  }

  void setPoolFilterDueWithinDays(int? value) {
    poolFilterDueWithinDays = value;
    notifyListeners();
  }

  void setPoolFilterNoMachine(bool value) {
    poolFilterNoMachine = value;
    notifyListeners();
  }

  void setPoolFilterMachineId(String? value) {
    final v = value?.trim();
    poolFilterMachineId = (v == null || v.isEmpty) ? null : v;
    notifyListeners();
  }

  void setPoolFilterOperationName(String? value) {
    final v = value?.trim();
    poolFilterOperationName = (v == null || v.isEmpty) ? null : v;
    notifyListeners();
  }

  void setPoolFilterLineId(String? value) {
    final v = value?.trim();
    poolFilterLineId = (v == null || v.isEmpty) ? null : v;
    notifyListeners();
  }

  void setPoolFilterCustomerName(String? value) {
    final v = value?.trim();
    poolFilterCustomerName = (v == null || v.isEmpty) ? null : v;
    notifyListeners();
  }

  void setShowMesGanttOverlay(bool v) {
    showMesGanttOverlay = v;
    final b = ganttDto;
    if (b != null) {
      unawaited(_afterGanttBaseReady(b));
    } else {
      notifyListeners();
    }
  }

  /// Ponovno učitava MES intervale npr. nakon „Osvježi MES” u Provedbi.
  Future<void> refreshMesGanttOverlay() async {
    final b = ganttDto;
    if (b == null) {
      return;
    }
    await _afterGanttBaseReady(b);
  }

  String _conflictKey(PlanningConflict c) => '${c.type.name}::${c.message}';

  void dismissEngineConflict(PlanningConflict c) {
    _dismissedEngineConflictKeys.add(_conflictKey(c));
    notifyListeners();
  }

  void clearDismissedEngineConflicts() {
    _dismissedEngineConflictKeys.clear();
    notifyListeners();
  }

  String? getExecutionVarianceRootDraft(String clientOperationId) =>
      _varianceRootByClientOpId[clientOperationId];

  String? getExecutionVarianceNotesDraft(String clientOperationId) =>
      _varianceNotesByClientOpId[clientOperationId];

  void setExecutionVarianceDraft(
    String clientOperationId, {
    required String? rootCauseCode,
    String? notes,
  }) {
    final r = rootCauseCode?.trim();
    if (r == null || r.isEmpty) {
      _varianceRootByClientOpId.remove(clientOperationId);
    } else {
      _varianceRootByClientOpId[clientOperationId] = r;
    }
    final n = notes?.trim();
    if (n == null || n.isEmpty) {
      _varianceNotesByClientOpId.remove(clientOperationId);
    } else {
      _varianceNotesByClientOpId[clientOperationId] = n;
    }
    notifyListeners();
  }

  Future<void> loadExecutionVariancesForSavedPlan() async {
    final pid = lastSavedPlanId;
    if (pid == null || pid.isEmpty) {
      return;
    }
    if (_executionVariancesLoadedForPlanId == pid) {
      return;
    }
    if (companyId.isEmpty || plantKey.isEmpty) {
      return;
    }
    try {
      final list = await _varianceService.listForPlan(
        planId: pid,
        companyId: companyId,
        plantKey: plantKey,
      );
      for (final e in list) {
        _varianceRootByClientOpId[e.clientOperationId] = e.rootCauseCode;
        if (e.notes != null && e.notes!.trim().isNotEmpty) {
          _varianceNotesByClientOpId[e.clientOperationId] = e.notes!.trim();
        } else {
          _varianceNotesByClientOpId.remove(e.clientOperationId);
        }
      }
      _executionVariancesLoadedForPlanId = pid;
    } catch (_) {
      // ostaje draft
    }
    notifyListeners();
  }

  /// Upis u `execution_variances` za svaku operaciju u zadnjem rezultatu (uz MES trenutke).
  Future<void> persistAllExecutionVariancesToFirestore() async {
    final r = result;
    if (r == null || r.scheduledOperations.isEmpty) {
      return;
    }
    final pid = lastSavedPlanId;
    if (pid == null || pid.isEmpty) {
      return;
    }
    persistingExecutionVariances = true;
    errorMessage = null;
    notifyListeners();
    try {
      final ids = r.scheduledOperations.map((e) => e.productionOrderId).toSet();
      final mes = await _executionService.getExecutionsByOrderIds(
        companyId: companyId,
        plantKey: plantKey,
        productionOrderIds: ids,
      );
      for (final op in r.scheduledOperations) {
        final list = mes[op.productionOrderId] ?? const <Map<String, dynamic>>[];
        final actual = _bestMesStartEndOnMachine(
          list,
          op.machineId,
        );
        final code = getExecutionVarianceRootDraft(op.id) ?? 'unknown';
        final notes = getExecutionVarianceNotesDraft(op.id);
        await _varianceService.upsertForOperation(
          planId: pid,
          companyId: companyId,
          plantKey: plantKey,
          clientOperationId: op.id,
          productionOrderId: op.productionOrderId,
          orderCode: _productionOrderCodeFor(r, op.productionOrderId),
          machineId: op.machineId,
          plannedStart: op.plannedStart,
          plannedEnd: op.plannedEnd,
          actualStart: actual?.$1,
          actualEnd: actual?.$2,
          rootCauseCode: code,
          notes: notes,
        );
      }
      _executionVariancesLoadedForPlanId = pid;
    } catch (e) {
      errorMessage = 'Varijance nisu spremljene. Provjera mreže i uloga.';
    } finally {
      persistingExecutionVariances = false;
      notifyListeners();
    }
  }

  (DateTime, DateTime?)? _bestMesStartEndOnMachine(
    List<Map<String, dynamic>> execs,
    String machineId,
  ) {
    final mid = machineId.trim();
    if (mid.isEmpty) {
      return null;
    }
    DateTime? bestS;
    DateTime? bestE;
    for (final m in execs) {
      if ((m['machineId'] ?? '').toString().trim() != mid) {
        continue;
      }
      final s = m['startedAt'];
      if (s is! Timestamp) {
        continue;
      }
      final start = s.toDate();
      if (bestS == null || start.isAfter(bestS)) {
        bestS = start;
        final e = m['endedAt'];
        bestE = e is Timestamp ? e.toDate() : null;
      }
    }
    final bs = bestS;
    if (bs == null) {
      return null;
    }
    return (bs, bestE);
  }

  List<PlanningConflict> get visibleEngineConflicts {
    final r = result;
    if (r == null) {
      return const [];
    }
    return r.conflicts
        .where((c) => !_dismissedEngineConflictKeys.contains(_conflictKey(c)))
        .toList();
  }

  void clearPoolFilters() {
    poolFilterHasMachine = false;
    poolFilterDueWithinDays = null;
    poolFilterNoMachine = false;
    poolFilterMachineId = null;
    poolFilterOperationName = null;
    poolFilterLineId = null;
    poolFilterCustomerName = null;
    notifyListeners();
  }

  PlanningGanttDto? get ganttDto {
    final r = result;
    if (r == null) return null;
    return PlanningGanttDto.fromEngineResult(r);
  }

  /// Prikaz: plan (FCS) + opc. MES preko [showMesGanttOverlay] nakon učitavanja.
  PlanningGanttDto? get ganttForDisplay {
    final b = ganttDto;
    if (b == null) {
      return null;
    }
    if (showMesGanttOverlay && _ganttWithMes != null) {
      return _ganttWithMes;
    }
    return b;
  }

  bool get mesGanttLoading => _mesGanttLoading;

  List<({String id, String label})> get lineFilterOptions {
    final ids = <String>{};
    for (final o in pool) {
      final l = o.lineId?.trim();
      if (l != null && l.isNotEmpty) {
        ids.add(l);
      }
    }
    final out = <({String id, String label})>[];
    for (final id in ids) {
      out.add((id: id, label: id));
    }
    out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return out;
  }

  List<String> get poolDistinctCustomerNames {
    final s = <String>{};
    for (final o in pool) {
      final c = (o.customerName ?? o.sourceCustomerName)?.trim();
      if (c != null && c.isNotEmpty) {
        s.add(c);
      }
    }
    final l = s.toList()..sort();
    return l;
  }

  /// Parovi operacija na istom stroju s vremenskim preklapanjem (nakon ručnog pomicanja).
  List<String> get ganttMachineOverlapMessages {
    final r = result;
    if (r == null || r.scheduledOperations.isEmpty) {
      return const [];
    }
    final byM = <String, List<ScheduledOperation>>{};
    for (final o in r.scheduledOperations) {
      final m = o.machineId.trim();
      if (m.isEmpty) {
        continue;
      }
      byM.putIfAbsent(m, () => []).add(o);
    }
    final out = <String>[];
    for (final e in byM.entries) {
      final list = List<ScheduledOperation>.from(e.value)
        ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
      for (var i = 0; i < list.length - 1; i++) {
        final a = list[i];
        final b = list[i + 1];
        if (a.plannedEnd.isAfter(b.plannedStart)) {
          final ca = _productionOrderCodeFor(r, a.productionOrderId);
          final cb = _productionOrderCodeFor(r, b.productionOrderId);
          final lab = poolMachineLabel(e.key);
          out.add('$lab: nalogi $ca i $cb se vremenski preklapaju.');
        }
      }
    }
    return out;
  }

  /// ID-jevi [ScheduledOperation.id] uključeni u vremensko preklapanje na istom stroju.
  Set<String> get overlappingScheduledOperationIds {
    final r = result;
    if (r == null || r.scheduledOperations.isEmpty) {
      return const {};
    }
    final byM = <String, List<ScheduledOperation>>{};
    for (final o in r.scheduledOperations) {
      final m = o.machineId.trim();
      if (m.isEmpty) {
        continue;
      }
      byM.putIfAbsent(m, () => []).add(o);
    }
    final out = <String>{};
    for (final e in byM.entries) {
      final list = List<ScheduledOperation>.from(e.value)
        ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
      for (var i = 0; i < list.length - 1; i++) {
        final a = list[i];
        final b = list[i + 1];
        if (a.plannedEnd.isAfter(b.plannedStart)) {
          if (a.id.isNotEmpty) {
            out.add(a.id);
          }
          if (b.id.isNotEmpty) {
            out.add(b.id);
          }
        }
      }
    }
    return out;
  }

  String _productionOrderCodeFor(PlanningEngineResult r, String orderId) {
    for (final it in r.plan.items) {
      if (it.productionOrderId == orderId) {
        final c = (it.productionOrderCode ?? '').trim();
        return c.isNotEmpty ? c : orderId;
      }
    }
    return orderId;
  }

  /// UI: šifra naloga u kontekstu zadnjeg [PlanningEngineResult].
  String engineOrderCode(PlanningEngineResult r, String productionOrderId) =>
      _productionOrderCodeFor(r, productionOrderId);

  void setSearchQuery(String v) {
    searchQuery = v;
    notifyListeners();
  }

  void bumpMesBoardRefresh() {
    mesBoardRefreshToken++;
    notifyListeners();
    final b = ganttDto;
    if (b != null) {
      unawaited(_afterGanttBaseReady(b));
    }
  }

  /// Pomiče operaciju u nacrtu (vremenska os); **ne** pokreće ponovno FCS — KPI/konflikti mogu biti zastarjeli.
  void nudgeScheduledOperationById(String operationId, Duration delta) {
    if (isLocked) {
      return;
    }
    final r = result;
    if (r == null || operationId.isEmpty) {
      return;
    }
    if (delta.inMilliseconds == 0) {
      return;
    }
    final list = r.scheduledOperations;
    final idx = list.indexWhere((e) => e.id == operationId);
    if (idx < 0) {
      return;
    }
    final op = list[idx];
    var ns = op.plannedStart.add(delta);
    var ne = op.plannedEnd.add(delta);
    if (!ne.isAfter(ns)) {
      return;
    }
    var nSetup = op.setupStart?.add(delta);
    var nRunS = op.runStart?.add(delta);
    var nRunE = op.runEnd?.add(delta);
    if (nRunS != null && nRunE != null && !nRunE.isAfter(nRunS)) {
      nRunE = nRunS.add(const Duration(minutes: 1));
      if (!ne.isAfter(nRunE)) {
        ne = nRunE;
      }
    }
    final next = op.copyWith(
      plannedStart: ns,
      plannedEnd: ne,
      setupStart: nSetup,
      runStart: nRunS,
      runEnd: nRunE,
    );
    final newList = List<ScheduledOperation>.from(list)..[idx] = next;
    result = PlanningEngineResult(
      plan: r.plan,
      scheduledOperations: newList,
      conflicts: r.conflicts,
      resourceSnapshot: r.resourceSnapshot,
      kpi: r.kpi,
    );
    _localGanttNudged = true;
    _onResultChanged();
    notifyListeners();
  }

  void setScenarioIndex(int v) {
    scenarioIndex = v;
    notifyListeners();
  }

  void setHorizonDays(int v) {
    horizonDays = v;
    notifyListeners();
  }

  void setTimeScopeIndex(int v) {
    timeScopeIndex = v;
    notifyListeners();
  }

  void setSelectedOrder(ProductionOrderModel? o) {
    selectedOrder = o;
    notifyListeners();
  }

  void toggleOrderSelected(String id, bool? checked) {
    if (isLocked) return;
    if (checked == true) {
      selectedOrderIds.add(id);
    } else {
      selectedOrderIds.remove(id);
    }
    notifyListeners();
  }

  void selectAllInPool() {
    if (isLocked) return;
    selectedOrderIds
      ..clear()
      ..addAll(pool.where((o) => !excludedOrderIds.contains(o.id)).map((e) => e.id));
    notifyListeners();
  }

  void selectFiltered() {
    if (isLocked) return;
    for (final o in ordersForTable) {
      if (!excludedOrderIds.contains(o.id)) {
        selectedOrderIds.add(o.id);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    if (isLocked) return;
    selectedOrderIds.clear();
    notifyListeners();
  }

  void clearFilteredFromSelection() {
    if (isLocked) return;
    for (final o in ordersForTable) {
      selectedOrderIds.remove(o.id);
    }
    notifyListeners();
  }

  void excludeFromPlan(String orderId) {
    if (isLocked) return;
    selectedOrderIds.remove(orderId);
    excludedOrderIds.add(orderId);
    notifyListeners();
  }

  void includeInPlan(String orderId) {
    if (isLocked) return;
    excludedOrderIds.remove(orderId);
    notifyListeners();
  }

  static const scenarioOptions = <({String id, String label, bool enabled})>[
    (id: 'draft', label: 'Nacrt', enabled: true),
    (id: 'sim', label: 'Simulacija', enabled: true),
    (id: 'ok', label: 'Potvrđeno', enabled: true),
    (id: 'live', label: 'U produkciji', enabled: false),
  ];

  void _sanitizePoolFilters() {
    if (poolFilterMachineId != null) {
      final id = poolFilterMachineId!.trim();
      if (id.isEmpty || !pool.any((o) => (o.machineId ?? '').trim() == id)) {
        poolFilterMachineId = null;
      }
    }
    if (poolFilterOperationName != null) {
      final on = poolFilterOperationName!.trim();
      if (on.isEmpty || !pool.any((o) => (o.operationName ?? '').trim() == on)) {
        poolFilterOperationName = null;
      }
    }
    if (poolFilterLineId != null) {
      final l = poolFilterLineId!.trim();
      if (l.isEmpty || !pool.any((o) => (o.lineId ?? '').trim() == l)) {
        poolFilterLineId = null;
      }
    }
    if (poolFilterCustomerName != null) {
      final c = poolFilterCustomerName!.trim();
      if (c.isEmpty) {
        poolFilterCustomerName = null;
      } else if (!pool.any(
            (o) =>
                ((o.customerName ?? o.sourceCustomerName) ?? '').trim() == c,
          )) {
        poolFilterCustomerName = null;
      }
    }
  }

  Future<void> _rebuildPoolMachineLabels() async {
    final ids = <String>{};
    for (final o in pool) {
      final m = o.machineId?.trim();
      if (m != null && m.isNotEmpty) {
        ids.add(m);
      }
    }
    if (ids.isEmpty) {
      if (_poolMachineIdLabels.isNotEmpty) {
        _poolMachineIdLabels = {};
        notifyListeners();
      }
      return;
    }
    try {
      final lookup = await ProductionAssetDisplayLookup.loadForPlant(
        companyId: companyId,
        plantKey: plantKey,
        limit: 500,
      );
      final m = <String, String>{};
      for (final id in ids) {
        m[id] = lookup.resolve(id);
      }
      _poolMachineIdLabels = m;
    } catch (_) {
      _poolMachineIdLabels = {};
    }
    notifyListeners();
  }

  Future<void> loadPool() async {
    if (companyId.isEmpty || plantKey.isEmpty) {
      loadingPool = false;
      poolError = 'Nedostaje podatak o kompaniji ili pogonu.';
      pool = [];
      _poolMachineIdLabels = {};
      selectedOrderIds.clear();
      selectedOrder = null;
      notifyListeners();
      return;
    }
    loadingPool = true;
    poolError = null;
    notifyListeners();
    try {
      final all = await _orderService.getOrders(companyId: companyId, plantKey: plantKey);
      var list = all.where((o) {
        final s = o.status.toLowerCase();
        return s == 'released' || s == 'in_progress';
      }).toList();
      list.sort((a, b) {
        final da = a.requestedDeliveryDate;
        final db = b.requestedDeliveryDate;
        if (da != null && db != null) {
          final c = da.compareTo(db);
          if (c != 0) {
            return c;
          }
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      pool = list;
      _sanitizePoolFilters();
      selectedOrderIds
        ..clear()
        ..addAll(list.where((o) => !excludedOrderIds.contains(o.id)).map((e) => e.id));
      selectedOrder = list.isNotEmpty ? list.first : null;
      loadingPool = false;
      unawaited(_rebuildPoolMachineLabels());
    } catch (_) {
      loadingPool = false;
      pool = [];
      _poolMachineIdLabels = {};
      selectedOrderIds.clear();
      poolError = 'Učitavanje naloga nije uspjelo. Pokušajte kasnije.';
      selectedOrder = null;
    }
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void _onResultChanged() {
    final d = ganttDto;
    if (d == null) {
      ganttMachineLabels = const {};
      ganttLabelForResultId = null;
      _ganttWithMes = null;
      notifyListeners();
    } else {
      unawaited(_afterGanttBaseReady(d));
    }
  }

  Future<void> _afterGanttBaseReady(PlanningGanttDto base) async {
    await _rebuildGanttWithMes(base);
    final display = ganttForDisplay;
    if (display == null || display.operations.isEmpty) {
      ganttMachineLabels = const {};
      ganttLabelForResultId = result?.plan.id;
      notifyListeners();
      return;
    }
    await _resolveGanttLabels(display);
  }

  Future<void> _rebuildGanttWithMes(PlanningGanttDto base) async {
    if (!showMesGanttOverlay || result == null) {
      _ganttWithMes = null;
      return;
    }
    final r = result!;
    final ids = r.scheduledOperations.map((e) => e.productionOrderId).toSet();
    if (ids.isEmpty) {
      _ganttWithMes = null;
      return;
    }
    _mesGanttLoading = true;
    notifyListeners();
    try {
      final mes = await _executionService.getExecutionsByOrderIds(
        companyId: companyId,
        plantKey: plantKey,
        productionOrderIds: ids,
      );
      final mesOps = planningMesGanttOpsFromExecutions(
        mesByOrderId: mes,
        productionOrderIdsInPlan: ids,
        orderCodeFor: (oid) => _productionOrderCodeFor(r, oid),
      );
      _ganttWithMes = appendGanttOperations(base, mesOps);
    } catch (_) {
      _ganttWithMes = null;
    } finally {
      _mesGanttLoading = false;
      notifyListeners();
    }
  }

  Future<void> _resolveGanttLabels(PlanningGanttDto d) async {
    final rid = result?.plan.id;
    if (d.operations.isEmpty) {
      ganttMachineLabels = const {};
      ganttLabelForResultId = rid;
      notifyListeners();
      return;
    }
    try {
      final lookup = await ProductionAssetDisplayLookup.loadForPlant(
        companyId: companyId,
        plantKey: plantKey,
        limit: 500,
      );
      final ids = <String>{for (final o in d.operations) o.machineId};
      final m = <String, String>{};
      for (final id in ids) {
        m[id] = id.isEmpty ? 'Nije dodijeljen stroj' : lookup.resolve(id);
      }
      ganttMachineLabels = m;
      ganttLabelForResultId = rid;
    } catch (_) {
      ganttMachineLabels = const {};
      ganttLabelForResultId = rid;
    }
    notifyListeners();
  }

  Future<void> generatePlan() async {
    if (companyId.isEmpty || plantKey.isEmpty) return;
    if (selectedOrderIds.isEmpty) {
      return;
    }
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final start = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final end = start.add(Duration(days: horizonDays));
      final perf = double.tryParse(perfController.text.replaceAll(',', '.')) ?? 0.65;
      final setup = double.tryParse(setupController.text.replaceAll(',', '.')) ?? 30;
      final cyc = double.tryParse(cycleController.text.replaceAll(',', '.')) ?? 60;
      final eligible = pool.where((o) => !excludedOrderIds.contains(o.id)).toList();
      final allPoolSelected = eligible.isNotEmpty &&
          eligible.every((o) => selectedOrderIds.contains(o.id)) &&
          selectedOrderIds.length == eligible.length;
      result = await _engine.generateDraftPlan(
        companyId: companyId,
        plantKey: plantKey,
        horizonStart: start,
        horizonEnd: end,
        productionOrderIds: allPoolSelected ? null : selectedOrderIds.toList(),
        performanceFactor: perf,
        setupMinutes: setup,
        cycleSecPerUnit: cyc,
        scheduleStrategy: scheduleStrategy,
      );
      _dismissedEngineConflictKeys.clear();
      _localGanttNudged = false;
      lastSavedPlanId = null;
      _executionVariancesLoadedForPlanId = null;
      _varianceRootByClientOpId.clear();
      _varianceNotesByClientOpId.clear();
      _onResultChanged();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft() async {
    final r = result;
    if (r == null) return;
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      lastSavedPlanId = await _persistence.saveDraftFromEngineResult(
        result: r,
        companyId: companyId,
        plantKey: plantKey,
        localGanttAdjusted: _localGanttNudged,
      );
      unawaited(loadExecutionVariancesForSavedPlan());
    } catch (e) {
      errorMessage = 'Spremanje nije uspjelo. Provjerite uloge i mrežu.';
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  int countRiskOrders() {
    return pool
        .where(
          (o) =>
              (o.requestedDeliveryDate != null) &&
              o.requestedDeliveryDate!.difference(DateTime.now()).inDays < 3 &&
              (o.machineId ?? '').trim().isNotEmpty,
        )
        .length;
  }

  /// F4.5 — heuristika rizika isporuke nakon zadnjeg FCS (null ako nema rezultata).
  PlanningDeliveryRisk? get planningDeliveryRisk {
    final r = result;
    if (r == null) {
      return null;
    }
    return PlanningDeliveryRisk.fromEngineResult(
      r,
      poolUrgentCount: countRiskOrders(),
      poolSize: pool.isEmpty ? 1 : pool.length,
    );
  }

  int countNoMachine() {
    return pool.where((o) => (o.machineId ?? '').trim().isEmpty).length;
  }

  @override
  void dispose() {
    perfController.dispose();
    setupController.dispose();
    cycleController.dispose();
    super.dispose();
  }
}
