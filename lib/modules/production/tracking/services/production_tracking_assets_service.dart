import 'package:cloud_firestore/cloud_firestore.dart';

import 'production_asset_display_lookup.dart';

/// Čitanje `assets` za pregled strojeva i udio RUNNING (iskoristivost u smislu operativnog stanja).
class ProductionTrackingAssetsService {
  ProductionTrackingAssetsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _runtimeRunning = 'RUNNING';
  static const String _runtimeStopped = 'STOPPED';

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Stabilan ključ linije s dokumenta imovine (prioritet kao u master podacima).
  static String? _lineKeyFromAssetData(Map<String, dynamic> data) {
    for (final k in [
      'productionLineId',
      'lineId',
      'lineCode',
      'productionLineCode',
    ]) {
      final v = _trimDyn(data[k]);
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  static String _trimDyn(dynamic v) => (v ?? '').toString().trim();

  /// Ljudski naziv linije na dokumentu stroja (ako ga master drži uz ključ).
  static String? _lineDisplayFromAssetData(Map<String, dynamic> data) {
    for (final k in [
      'productionLineName',
      'lineName',
      'lineDisplayName',
      'productionLineDisplayName',
    ]) {
      final v = _trimDyn(data[k]);
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  /// Aktivni uređaji pogona (plantKey kao u praćenju / company_plants).
  Future<ProductionPlantAssetsSnapshot> loadForPlant({
    required String companyId,
    required String plantKey,
    int limit = 32,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const ProductionPlantAssetsSnapshot(
        machines: [],
        runningCount: 0,
        totalCount: 0,
        machineLineKeyByMachineId: {},
        lineDisplayNameByLineKey: {},
      );
    }

    final snap = await _db
        .collection('assets')
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('active', isEqualTo: true)
        .limit(limit)
        .get();

    final rows = <ProductionMachineOverview>[];
    final machineLineKeyByMachineId = <String, String>{};
    final lineDisplayNameByLineKey = <String, String>{};
    var running = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final rt = _s(data['runtimeState']).toUpperCase();
      if (rt == _runtimeRunning) running++;

      final name = ProductionAssetDisplayLookup.labelFromAssetData(data);

      final loc = _s(data['locationPath']);
      final subtitle = loc.isNotEmpty ? loc : _s(data['type']);

      ProductionMachineStatus st;
      String detail;
      if (rt == _runtimeRunning) {
        st = ProductionMachineStatus.running;
        detail = subtitle.isNotEmpty ? subtitle : 'U radu';
      } else if (rt == _runtimeStopped) {
        st = ProductionMachineStatus.stopped;
        detail = subtitle.isNotEmpty ? subtitle : 'Zaustavljeno';
      } else {
        st = ProductionMachineStatus.unknown;
        detail = 'Operativno stanje nije postavljeno';
      }

      rows.add(
        ProductionMachineOverview(
          id: d.id,
          title: name,
          status: st,
          detail: detail,
        ),
      );

      final lk = _lineKeyFromAssetData(data);
      if (lk != null && lk.isNotEmpty) {
        machineLineKeyByMachineId[d.id] = lk;
        final dn = _lineDisplayFromAssetData(data);
        if (dn != null && dn.isNotEmpty) {
          lineDisplayNameByLineKey.putIfAbsent(lk, () => dn);
        }
      }
    }

    rows.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return ProductionPlantAssetsSnapshot(
      machines: rows,
      runningCount: running,
      totalCount: rows.length,
      machineLineKeyByMachineId: machineLineKeyByMachineId,
      lineDisplayNameByLineKey: lineDisplayNameByLineKey,
    );
  }
}

enum ProductionMachineStatus { running, stopped, unknown }

class ProductionMachineOverview {
  const ProductionMachineOverview({
    required this.id,
    required this.title,
    required this.status,
    required this.detail,
  });

  final String id;
  final String title;
  final ProductionMachineStatus status;
  final String detail;
}

class ProductionPlantAssetsSnapshot {
  const ProductionPlantAssetsSnapshot({
    required this.machines,
    required this.runningCount,
    required this.totalCount,
    this.machineLineKeyByMachineId = const {},
    this.lineDisplayNameByLineKey = const {},
  });

  final List<ProductionMachineOverview> machines;
  final int runningCount;
  final int totalCount;

  /// Doc id stroja (assets) → ključ linije iz imovine.
  final Map<String, String> machineLineKeyByMachineId;

  /// Ključ linije → prikazni naziv (iz polja tipa `productionLineName` na stroju).
  final Map<String, String> lineDisplayNameByLineKey;

  double get runningSharePct {
    if (totalCount <= 0) return 0;
    return (runningCount * 100.0) / totalCount;
  }
}
