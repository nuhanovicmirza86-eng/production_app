import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/downtime_analytics_engine.dart';
import '../models/downtime_event_model.dart';

/// CSV izvoz analitike zastoja (Excel-friendly, separator `;`).
class DowntimeAnalyticsExport {
  static String _esc(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String buildCsv({
    required DowntimeAnalyticsReport report,
    required String companyId,
    required String plantKey,
  }) {
    final sb = StringBuffer();
    sb.writeln(
      '${_esc('Zastoji — analitika')};${_esc(companyId)};${_esc(plantKey)}',
    );
    sb.writeln(
      '${_esc('Period')};${_esc(report.rangeStart.toIso8601String())};${_esc(report.rangeEndExclusive.toIso8601String())}',
    );
    sb.writeln('${_esc('Uključeni odbijeni')};${report.includeRejected}');
    sb.writeln();
    sb.writeln('${_esc('SAŽETAK')};${_esc('Vrijednost')}');
    sb.writeln('${_esc('Broj zastoja (doprinos u minutama)')};${report.eventsTouchingPeriod}');
    sb.writeln('${_esc('Ukupno minuta (u periodu)')};${report.totalMinutesClipped}');
    sb.writeln('${_esc('Gubitak OEE (min)')};${report.minutesOeeLoss}');
    sb.writeln('${_esc('Gubitak OOE (min)')};${report.minutesOoeLoss}');
    sb.writeln('${_esc('Gubitak TEEP (min)')};${report.minutesTeepLoss}');
    sb.writeln('${_esc('Planirani (min)')};${report.plannedMinutes}');
    sb.writeln('${_esc('Neplanirani (min)')};${report.unplannedMinutes}');
    sb.writeln(
      '${_esc('MTTR riješeni (min, prosjek)')};${report.mttrMinutesResolved?.toStringAsFixed(1) ?? '—'}',
    );
    sb.writeln('${_esc('Broj za MTTR')};${report.closedForMttrCount}');
    sb.writeln('${_esc('Verificirani zapisi')};${report.verifiedCount}');
    sb.writeln('${_esc('CAPA flag')};${report.correctiveActionFlagged}');
    sb.writeln();

    sb.writeln('${_esc('STATUSI')};${_esc('Broj')}');
    final stKeys = report.countByStatus.keys.toList()..sort();
    for (final k in stKeys) {
      sb.writeln('${_esc(DowntimeEventStatus.labelHr(k))};${report.countByStatus[k]}');
    }
    sb.writeln();

    sb.writeln('${_esc('PARETO — kategorije')};${_esc('Min')};${_esc('Kom')};${_esc('%')};${_esc('Kum %')}');
    for (final r in report.paretoCategories) {
      sb.writeln(
        '${_esc(r.label)};${r.minutes};${r.count};${r.pctOfTotalMinutes.toStringAsFixed(1)};${r.cumulativePct.toStringAsFixed(1)}',
      );
    }
    sb.writeln();

    sb.writeln(
      '${_esc('RADNI CENTRI')};${_esc('Min')};${_esc('Kom')};${_esc('OEE min')};${_esc('OOE min')};${_esc('TEEP min')}',
    );
    for (final r in report.byWorkCenter.take(40)) {
      sb.writeln(
        '${_esc(r.label)};${r.minutesClipped};${r.events};${r.minutesOee};${r.minutesOoe};${r.minutesTeep}',
      );
    }
    sb.writeln();

    sb.writeln(
      '${_esc('PROCESI')};${_esc('Min')};${_esc('Kom')};${_esc('OEE min')};${_esc('OOE min')};${_esc('TEEP min')}',
    );
    for (final r in report.byProcess.take(40)) {
      sb.writeln(
        '${_esc(r.label)};${r.minutesClipped};${r.events};${r.minutesOee};${r.minutesOoe};${r.minutesTeep}',
      );
    }
    sb.writeln();

    sb.writeln(
      '${_esc('DAN')};${_esc('Datum')};${_esc('Broj zastoja')};${_esc('Min')};${_esc('OEE')};${_esc('OOE')};${_esc('TEEP')}',
    );
    for (final d in report.byDay) {
      final ds =
          '${d.dayLocal.year}-${d.dayLocal.month.toString().padLeft(2, '0')}-${d.dayLocal.day.toString().padLeft(2, '0')}';
      sb.writeln(
        'DAN;$ds;${d.eventCount};${d.minutesClipped};${d.minutesOee};${d.minutesOoe};${d.minutesTeep}',
      );
    }
    sb.writeln();

    sb.writeln('${_esc('PONAVLJANJA RAZLOGA')};${_esc('Kom')};${_esc('Min')}');
    for (final r in report.repeatReasons.take(30)) {
      sb.writeln('${_esc(r.reason)};${r.occurrences};${r.totalMinutesClipped}');
    }

    return sb.toString();
  }

  static Future<void> shareCsv({
    required DowntimeAnalyticsReport report,
    required String companyId,
    required String plantKey,
  }) async {
    final csv = buildCsv(
      report: report,
      companyId: companyId,
      plantKey: plantKey,
    );
    final dir = await getTemporaryDirectory();
    final safePlant = plantKey.trim().isEmpty ? 'plant' : plantKey.trim();
    final fn =
        'zastoji_analitika_${safePlant}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final path = '${dir.path}/$fn';
    final f = File(path);
    await f.writeAsString(csv, encoding: utf8);
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Analitika zastoja (CSV)',
    );
  }
}
