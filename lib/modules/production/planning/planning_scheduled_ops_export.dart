import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models/saved_plan_scheduled_row.dart';
import 'planning_ui_formatters.dart';

/// Izvoz tablice zakazanih operacija (CSV, separator `;`, UTF-8 s BOM-om za Excel).
class PlanningScheduledOpsExport {
  const PlanningScheduledOpsExport._();

  static String _esc(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String buildCsv(
    List<SavedPlanScheduledRow> rows, {
    required String planCode,
  }) {
    final h = <String>[
      'R.b.',
      'Nalog',
      'Korak',
      'Operacija',
      'Stroj',
      'Početak',
      'Kraj',
      'Min',
    ];
    final sb = StringBuffer();
    sb.writeln('sep=;');
    sb.writeln(h.map(_esc).join(';'));
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final line = <String>[
        '${i + 1}',
        r.productionOrderCode,
        '${r.operationSequence}',
        (r.operationLabel == null || r.operationLabel!.isEmpty) ? '' : r.operationLabel!,
        r.resourceDisplayName,
        PlanningUiFormatters.formatDateTime(r.plannedStart),
        PlanningUiFormatters.formatDateTime(r.plannedEnd),
        '${r.durationMinutes}',
      ];
      sb.writeln(line.map(_esc).join(';'));
    }
    return sb.toString();
  }

  static Future<void> shareCsv({
    required String fileName,
    required String planCode,
    required List<SavedPlanScheduledRow> rows,
  }) async {
    final body = buildCsv(rows, planCode: planCode);
    final withBom = '\uFEFF$body';
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = '${dir.path}/$safeName';
    final f = File(path);
    await f.writeAsString(withBom, encoding: utf8);
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Zakazane operacije (plan: $planCode)',
    );
  }
}
