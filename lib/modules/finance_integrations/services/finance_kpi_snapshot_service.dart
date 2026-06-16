import '../models/finance_kpi_snapshot_model.dart';
import 'finance_controlling_period_read_service.dart';

class FinanceKpiSnapshotService {
  FinanceKpiSnapshotService();

  final FinanceControllingPeriodReadService _reads =
      FinanceControllingPeriodReadService();

  /// Jedan snapshot za tenant + poslovnu godinu + mjesec + pogon (Callable; prazan plantKey = rollup).
  Future<FinanceKpiSnapshotModel?> loadSnapshot({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
  }) async {
    final cid = companyId.trim();
    final by = businessYearId.trim();
    if (cid.isEmpty || by.isEmpty) {
      return null;
    }
    final pk = plantKey.trim();
    final bundle = await _reads.load(
      companyId: cid,
      businessYearId: by,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: pk,
    );
    return bundle.kpi;
  }

  Stream<FinanceKpiSnapshotModel?> watchSnapshot({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
  }) {
    return Stream.fromFuture(
      loadSnapshot(
        companyId: companyId,
        businessYearId: businessYearId,
        periodYear: periodYear,
        periodMonth: periodMonth,
        plantKey: plantKey,
      ),
    ).asBroadcastStream();
  }
}
