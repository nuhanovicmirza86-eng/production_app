import '../models/finance_kpi_snapshot_model.dart';
import 'finance_controlling_period_read_service.dart';

class FinanceKpiSnapshotService {
  FinanceKpiSnapshotService();

  final FinanceControllingPeriodReadService _reads =
      FinanceControllingPeriodReadService();

  /// Jedan snapshot za tenant + poslovnu godinu + mjesec + pogon (Callable; prazan plantKey = rollup).
  Stream<FinanceKpiSnapshotModel?> watchSnapshot({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
  }) {
    final cid = companyId.trim();
    final by = businessYearId.trim();
    if (cid.isEmpty || by.isEmpty) {
      return Stream<FinanceKpiSnapshotModel?>.value(null);
    }
    final pk = plantKey.trim();
    return Stream.fromFuture(
      _reads
          .load(
            companyId: cid,
            businessYearId: by,
            periodYear: periodYear,
            periodMonth: periodMonth,
            plantKey: pk,
          )
          .then((b) => b.kpi),
    );
  }
}
