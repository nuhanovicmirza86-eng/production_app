import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_station_config.dart';
import '../models/production_station_page.dart';
import '../models/station_page_gate_result.dart';
import 'production_station_page_callable_service.dart';

class ProductionStationPageService {
  final FirebaseFirestore _firestore;
  final ProductionStationPageCallableService _callable;

  ProductionStationPageService({
    FirebaseFirestore? firestore,
    ProductionStationPageCallableService? callable,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _callable = callable ?? ProductionStationPageCallableService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('production_station_pages');

  CollectionReference<Map<String, dynamic>> get _configCol =>
      _firestore.collection('production_station_configs');

  /// Stranice stanica za odabrani tenant i pogon.
  Stream<List<ProductionStationPage>> watchPages({
    required String companyId,
    required String plantKey,
  }) {
    return _col
        .where('companyId', isEqualTo: companyId)
        .where('plantKey', isEqualTo: plantKey)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ProductionStationPage.fromDoc).toList();
          list.sort((a, b) => a.stationSlot.compareTo(b.stationSlot));
          return list;
        });
  }

  /// Snimanje stranice stanice — isključivo Callable (`upsertProductionStationPage`).
  Future<void> upsertPage({required ProductionStationPage page}) async {
    await _callable.upsertProductionStationPage(page: page);
  }

  /// @nodoc — koristi [upsertPage].
  Future<void> createPage({
    required ProductionStationPage page,
    required String currentUid,
    String? currentEmail,
  }) async {
    await upsertPage(page: page);
  }

  /// @nodoc — koristi [upsertPage].
  Future<void> updatePage({
    required ProductionStationPage page,
    required String currentUid,
  }) async {
    await upsertPage(page: page);
  }

  /// Kanonski config po slotu (`production_station_configs/{companyId}__{slot}`).
  Future<ProductionStationConfig?> getConfigBySlot({
    required String companyId,
    required int stationSlot,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty || stationSlot < 1) return null;
    final id = ProductionStationConfig.buildConfigId(
      companyId: cid,
      stationSlot: stationSlot,
    );
    final doc = await _configCol.doc(id).get();
    if (!doc.exists) return null;
    return ProductionStationConfig.fromMap({
      'id': doc.id,
      ...?doc.data(),
    });
  }

  ProductionStationPage _legacyPageFromConfig(ProductionStationConfig config) {
    return ProductionStationPage(
      id: config.id,
      companyId: config.companyId,
      plantKey: config.assignedPlantKey,
      stationSlot: config.stationSlot,
      phase: config.phase,
      displayName: config.displayName,
      active: config.active,
      provisionedByUid: config.id,
      provisionedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      notes: config.notes,
      inboundWarehouseId: config.inboundWarehouseId,
      outboundWarehouseId: config.outboundWarehouseId,
    );
  }

  /// Jedna stranica stanice (npr. magacin za prijem kutije po slotu).
  /// Dual-read: `production_station_configs` pa legacy `production_station_pages`.
  Future<ProductionStationPage?> getPage({
    required String companyId,
    required String plantKey,
    required int stationSlot,
  }) async {
    final config = await getConfigBySlot(
      companyId: companyId,
      stationSlot: stationSlot,
    );
    if (config != null) {
      return _legacyPageFromConfig(config);
    }

    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty || stationSlot < 1 || stationSlot > 3) {
      return null;
    }
    final id = ProductionStationPage.buildPageId(
      companyId: cid,
      plantKey: pk,
      stationSlot: stationSlot,
    );
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ProductionStationPage.fromDoc(doc);
  }

  /// Provjera prije punog zaslona stanice.
  ///
  /// Blokira samo ako postoji dokument i `active == false`. Bez dokumenta ili uz drugu fazu — **dopušteno**
  /// (npr. tvrtka s jednom ili dvije stanice ne mora popunjavati sve slotove).
  /// [companyData] — ista mapa kao u [AuthWrapper] / dedicated stanica (pogon iz konteksta).
  Future<StationPageGateResult> checkStationPageForLaunchPhaseFromSession({
    required Map<String, dynamic> companyData,
    required String phase,
  }) {
    return checkStationPageForLaunchPhase(
      companyId: (companyData['companyId'] ?? '').toString(),
      plantKey: ProductionStationPage.plantKeyForStationContext(companyData),
      phase: phase,
    );
  }

  Future<StationPageGateResult> checkStationPageForLaunchPhase({
    required String companyId,
    required String plantKey,
    required String phase,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final ph = phase.trim();

    if (cid.isEmpty || pk.isEmpty) {
      return StationPageGateResult.blocked(
        'Nedostaje podatak o kompaniji ili pogonu u profilu korisnika.',
      );
    }

    try {
      final slot = ProductionStationPage.stationSlotForPhase(ph);
      final config = await getConfigBySlot(companyId: cid, stationSlot: slot);
      if (config != null) {
        if (!config.active) {
          return StationPageGateResult.blocked(
            'Ova stanica je onemogućena u konfiguraciji (neaktivna). '
            'Admin može uključiti je u „Stanice proizvodnje“.',
          );
        }
        return StationPageGateResult.ok(_legacyPageFromConfig(config));
      }

      final id = ProductionStationPage.buildPageId(
        companyId: cid,
        plantKey: pk,
        stationSlot: slot,
      );
      final doc = await _col.doc(id).get();
      if (!doc.exists) {
        return StationPageGateResult.ok();
      }
      final page = ProductionStationPage.fromDoc(doc);
      if (!page.active) {
        return StationPageGateResult.blocked(
          'Ova stanica je onemogućena u konfiguraciji (neaktivna). '
          'Admin može uključiti je u „Stanice proizvodnje“.',
        );
      }
      return StationPageGateResult.ok(page);
    } catch (e) {
      return StationPageGateResult.blocked(
        'Nije moguće učitati konfiguraciju stanice: $e',
      );
    }
  }
}
