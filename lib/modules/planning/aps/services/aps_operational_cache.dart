import 'dart:async';

import '../models/aps_demand_view.dart';
import '../models/aps_objective_profile_view.dart';
import '../models/aps_scenario_view.dart';
import 'aps_p1_write_service.dart';

class _CacheEntry<T> {
  _CacheEntry(this.value, this.fetchedAt);

  final T value;
  final DateTime fetchedAt;

  bool get expired =>
      DateTime.now().difference(fetchedAt) > ApsOperationalCache.ttl;
}

/// Kratkotrajni in-memory cache za APS operativne liste (hub navigacija).
class ApsOperationalCache {
  ApsOperationalCache._();
  static final ApsOperationalCache instance = ApsOperationalCache._();

  static const ttl = Duration(seconds: 90);

  final Map<String, _CacheEntry<List<ApsScenarioView>>> _scenarios = {};
  final Map<String, _CacheEntry<List<ApsDemandView>>> _demands = {};
  final Map<String, _CacheEntry<List<ApsObjectiveProfileView>>> _profiles = {};

  String _key(String companyId, String plantKey) =>
      '${companyId.trim()}|${plantKey.trim()}';

  void invalidateTenant({required String companyId, required String plantKey}) {
    final k = _key(companyId, plantKey);
    _scenarios.remove(k);
    _demands.remove(k);
    _profiles.remove(k);
  }

  /// Pozadinski prefetch s huba — smanjuje cold Callable na prvom child ekranu.
  void warmUp({
    required ApsP1WriteService service,
    required String companyId,
    required String plantKey,
  }) {
    if (companyId.trim().isEmpty || plantKey.trim().isEmpty) return;
    unawaited(Future.wait([
      scenarios(
        service: service,
        companyId: companyId,
        plantKey: plantKey,
      ),
      demands(
        service: service,
        companyId: companyId,
        plantKey: plantKey,
      ),
      objectiveProfiles(
        service: service,
        companyId: companyId,
        plantKey: plantKey,
      ),
    ]));
  }

  Future<List<ApsScenarioView>> scenarios({
    required ApsP1WriteService service,
    required String companyId,
    required String plantKey,
    bool forceRefresh = false,
  }) async {
    final k = _key(companyId, plantKey);
    if (!forceRefresh) {
      final hit = _scenarios[k];
      if (hit != null && !hit.expired) return hit.value;
    }
    final value = await service.fetchScenarios(
      companyId: companyId,
      plantKey: plantKey,
    );
    _scenarios[k] = _CacheEntry(value, DateTime.now());
    return value;
  }

  Future<List<ApsDemandView>> demands({
    required ApsP1WriteService service,
    required String companyId,
    required String plantKey,
    bool forceRefresh = false,
  }) async {
    final k = _key(companyId, plantKey);
    if (!forceRefresh) {
      final hit = _demands[k];
      if (hit != null && !hit.expired) return hit.value;
    }
    final value = await service.fetchDemands(
      companyId: companyId,
      plantKey: plantKey,
    );
    _demands[k] = _CacheEntry(value, DateTime.now());
    return value;
  }

  Future<List<ApsObjectiveProfileView>> objectiveProfiles({
    required ApsP1WriteService service,
    required String companyId,
    required String plantKey,
    bool forceRefresh = false,
  }) async {
    final k = _key(companyId, plantKey);
    if (!forceRefresh) {
      final hit = _profiles[k];
      if (hit != null && !hit.expired) return hit.value;
    }
    final value = await service.fetchObjectiveProfiles(
      companyId: companyId,
      plantKey: plantKey,
    );
    _profiles[k] = _CacheEntry(value, DateTime.now());
    return value;
  }
}
