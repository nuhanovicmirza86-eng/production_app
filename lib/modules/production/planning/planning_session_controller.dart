import 'package:flutter/material.dart';

import '../production_orders/models/production_order_model.dart';
import '../production_orders/services/production_order_service.dart';
import '../tracking/services/production_asset_display_lookup.dart';
import 'models/planning_engine_result.dart';
import 'services/planning_engine_service.dart';
import 'services/planning_gantt_dto.dart';
import 'services/production_plan_persistence_service.dart';

/// Zajedničko stanje planiranja za [ProductionPlanningHomeScreen] i tabove.
class PlanningSessionController extends ChangeNotifier {
  PlanningSessionController(this.companyId, this.plantKey)
      : _engine = PlanningEngineService(),
        _orderService = ProductionOrderService(),
        _persistence = ProductionPlanPersistenceService() {
    perfController = TextEditingController(text: '0.65');
    setupController = TextEditingController(text: '30');
    cycleController = TextEditingController(text: '60');
  }

  final String companyId;
  final String plantKey;

  final PlanningEngineService _engine;
  final ProductionOrderService _orderService;
  final ProductionPlanPersistenceService _persistence;

  late final TextEditingController perfController;
  late final TextEditingController setupController;
  late final TextEditingController cycleController;

  PlanningEngineResult? result;
  String? lastSavedPlanId;
  bool busy = false;
  String? errorMessage;
  bool saving = false;
  int horizonDays = 14;
  int scenarioIndex = 0;
  /// 0=smjena, 1=dan, 2=tjedan (povezat će se s MES/šiftom kasnije).
  int timeScopeIndex = 1;

  List<ProductionOrderModel> pool = [];
  final Set<String> selectedOrderIds = {};
  final Set<String> excludedOrderIds = {};
  bool loadingPool = true;
  String? poolError;
  String searchQuery = '';
  ProductionOrderModel? selectedOrder;
  Map<String, String> ganttMachineLabels = const {};
  String? ganttLabelForResultId;

  bool get isLocked => busy || saving;

  /// Prikaz u tablici (samo pretraga); isključene stavke ostaju vidljive s oznakom.
  List<ProductionOrderModel> get ordersForTable => _filterBySearch();

  List<ProductionOrderModel> _filterBySearch() {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return pool;
    return pool
        .where(
          (o) =>
              o.productionOrderCode.toLowerCase().contains(q) ||
              o.productName.toLowerCase().contains(q) ||
              o.productCode.toLowerCase().contains(q),
        )
        .toList();
  }

  PlanningGanttDto? get ganttDto {
    final r = result;
    if (r == null) return null;
    return PlanningGanttDto.fromEngineResult(r);
  }

  void setSearchQuery(String v) {
    searchQuery = v;
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

  Future<void> loadPool() async {
    if (companyId.isEmpty || plantKey.isEmpty) {
      loadingPool = false;
      poolError = 'Nedostaje podatak o kompaniji ili pogonu.';
      pool = [];
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
          if (c != 0) return c;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      pool = list;
      selectedOrderIds
        ..clear()
        ..addAll(list.where((o) => !excludedOrderIds.contains(o.id)).map((e) => e.id));
      selectedOrder = list.isNotEmpty ? list.first : null;
      loadingPool = false;
    } catch (_) {
      loadingPool = false;
      pool = [];
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
      notifyListeners();
    } else {
      _resolveGanttLabels(d);
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
      );
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
      );
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
