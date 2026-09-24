import 'package:flutter/material.dart';

import '../models/ncr_open_action_task.dart';
import '../screens/ncr_closure_task_screen.dart';
import '../screens/ncr_detail_screen.dart';
import '../screens/ncr_recheck_task_screen.dart';
import '../screens/ncr_rework_executor_task_screen.dart';

/// M1-I12-D — direktan ulaz u ekran akcije iz inboxa / obavijesti.
/// Vraća `true` ako je neusaglašenost zatvorena.
Future<bool> openNcrOpenActionTask(
  BuildContext context, {
  required Map<String, dynamic> companyData,
  required NcrOpenActionTask task,
}) async {
  switch (task.actionKind) {
    case 'rework_execution':
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => NcrReworkExecutorTaskScreen(
            companyData: companyData,
            ncrId: task.ncrId,
          ),
        ),
      );
      return false;
    case 'recheck':
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => NcrRecheckTaskScreen(
            companyData: companyData,
            ncrId: task.ncrId,
            expectedCheckedQty: task.expectedCheckedQty,
          ),
        ),
      );
      return false;
    case 'close_ncr':
      return await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => NcrClosureTaskScreen(
                companyData: companyData,
                ncrId: task.ncrId,
              ),
            ),
          ) ??
          false;
    default:
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => NcrDetailScreen(
            companyData: companyData,
            ncrId: task.ncrId,
          ),
        ),
      );
      return false;
  }
}

/// Otvara akciju iz MES obavijesti (`extra.actionKind` + `ncrId`).
Future<void> openNcrActionFromMesExtra(
  BuildContext context, {
  required Map<String, dynamic> companyData,
  required Map<String, dynamic> extra,
  required String ncrId,
}) async {
  final actionKind = (extra['actionKind'] ?? '').toString().trim();
  if (actionKind.isEmpty || ncrId.isEmpty) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NcrDetailScreen(
          companyData: companyData,
          ncrId: ncrId,
        ),
      ),
    );
    return;
  }
  final qtyRaw = extra['expectedCheckedQty'];
  int? expected;
  if (qtyRaw is num) {
    expected = qtyRaw.toInt();
  } else {
    expected = int.tryParse('$qtyRaw');
  }
  await openNcrOpenActionTask(
    context,
    companyData: companyData,
    task: NcrOpenActionTask(
      ncrId: ncrId,
      actionKind: actionKind,
      actionLabelBs: '',
      statusLabelBs: '',
      canAct: true,
      expectedCheckedQty: expected,
    ),
  );
}
