import 'package:cloud_functions/cloud_functions.dart';

import '../models/production_station_work_session.dart';

class ProductionStationWorkSessionCallableService {
  ProductionStationWorkSessionCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<ProductionStationWorkSession> startProductionStationWorkSession({
    required String companyId,
    required int stationSlot,
    required String productionOrderId,
  }) async {
    final res = await _functions
        .httpsCallable('startProductionStationWorkSession')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'stationSlot': stationSlot,
          'productionOrderId': productionOrderId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Pokretanje sesije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      (data['sessionId'] ?? '').toString(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<({ProductionStationWorkSession session, String? trackingEntryId})>
  updateProductionStationWorkSession({
    required String companyId,
    required String sessionId,
    required String action,
    double goodQtyDelta = 0,
    double scrapQtyDelta = 0,
    double reworkQtyDelta = 0,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'sessionId': sessionId.trim(),
      'action': action.trim(),
    };
    if (action == 'record_output') {
      payload['goodQtyDelta'] = goodQtyDelta;
      payload['scrapQtyDelta'] = scrapQtyDelta;
      payload['reworkQtyDelta'] = reworkQtyDelta;
      payload['comment'] = (comment ?? '').trim();
    } else if (action == 'set_comment') {
      payload['comment'] = (comment ?? '').trim();
    } else if (comment != null && comment.trim().isNotEmpty) {
      payload['comment'] = comment.trim();
    }

    final res = await _functions
        .httpsCallable('updateProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Ažuriranje sesije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return (
      session: ProductionStationWorkSession.fromMap(
        sessionId.trim(),
        Map<String, dynamic>.from(raw),
      ),
      trackingEntryId: (data['trackingEntryId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['trackingEntryId'] ?? '').toString().trim(),
    );
  }

  Future<ProductionStationWorkSession> finishProductionStationWorkSession({
    required String companyId,
    required String sessionId,
  }) async {
    final res = await _functions
        .httpsCallable('finishProductionStationWorkSession')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'sessionId': sessionId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Završetak sesije nije uspio.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      sessionId.trim(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<ProductionStationWorkSession?> getActiveProductionStationWorkSession({
    required String companyId,
    required int stationSlot,
  }) async {
    final res = await _functions
        .httpsCallable('getActiveProductionStationWorkSession')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'stationSlot': stationSlot,
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje sesije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw == null) return null;
    if (raw is! Map) return null;
    final id = (data['sessionId'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    return ProductionStationWorkSession.fromMap(
      id,
      Map<String, dynamic>.from(raw),
    );
  }
}
