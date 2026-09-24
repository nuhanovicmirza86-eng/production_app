import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../models/ncr_rework_executor_task.dart';
import '../screens/ncr_rework_executor_task_screen.dart';
import '../services/quality_callable_service.dart';
import '../../../features/station_evidence/screens/profile_driven_evidence_detail_screen.dart';

/// M1-I12-D — preusmjeravanje izvršioca dorade na scoped ekran umjesto evidencije.
class NcrReworkExecutorNavigation {
  const NcrReworkExecutorNavigation._();

  static Future<void> openEvidenceSessionOrExecutorReworkTask({
    required BuildContext context,
    required Map<String, dynamic> companyData,
    required String sessionId,
  }) async {
    final role = ProductionAccessHelper.normalizeRole(companyData['role']);
    if (ProductionAccessHelper.canBeNcrReworkExecutorRole(role)) {
      final companyId = (companyData['companyId'] ?? '').toString().trim();
      if (companyId.isNotEmpty) {
        try {
          final svc = QualityCallableService();
          final resolved = await svc.resolveNcrReworkExecutorTaskForEvidenceSession(
            companyId: companyId,
            sessionId: sessionId,
          );
          final found = resolved['found'] == true;
          final taskMap = resolved['task'];
          if (found && taskMap is Map) {
            final task = NcrReworkExecutorTask.fromMap(
              Map<String, dynamic>.from(taskMap),
            );
            if (task.ncrId.isNotEmpty && context.mounted) {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => NcrReworkExecutorTaskScreen(
                    companyData: companyData,
                    ncrId: task.ncrId,
                    initialTask: task,
                  ),
                ),
              );
              return;
            }
          }
        } catch (_) {
          // Nema scoped zadatka — nastavi na standardni ekran (supervizija).
        }
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDrivenEvidenceDetailScreen(
          companyData: companyData,
          sessionId: sessionId,
        ),
      ),
    );
  }
}
