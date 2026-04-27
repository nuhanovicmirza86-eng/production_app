import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/waste_quality_reports_aggregator.dart';

/// Izvoz izvještaja otpada/kvalitete kao CSV (UTF-8, separator `;` za Excel u HR).
class WasteQualityReportCsvShare {
  WasteQualityReportCsvShare._();

  static String _esc(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  static String buildScrapTypeCsv({
    required String plantLabel,
    required String rangeLabel,
    required List<WasteByScrapTypeRow> rows,
    required WasteQualityPeriodSummary period,
  }) {
    final sb = StringBuffer();
    sb.writeln(_esc('Otpad po tipu škarta'));
    sb.writeln(_esc('Pogon: $plantLabel'));
    sb.writeln(_esc('Period: $rangeLabel'));
    sb.writeln(
      '${_esc('Ukupno dobro (kom)')};${_esc(_fmtNum(period.goodQty))}',
    );
    sb.writeln(
      '${_esc('Ukupno škart (kom)')};${_esc(_fmtNum(period.scrapQty))}',
    );
    sb.writeln('${_esc('Broj unosa')};${period.entryCount}');
    sb.writeln();
    sb.writeln('${_esc('Tip (prikaz)')};${_esc('Količina')};${_esc('Udio %')}');
    for (final r in rows) {
      sb.writeln(
        [
          _esc(r.label),
          _esc(_fmtNum(r.qty)),
          _esc(r.pctOfTotalScrap.toStringAsFixed(1).replaceAll('.', ',')),
        ].join(';'),
      );
    }
    return _withBom(sb.toString());
  }

  static String buildProductCsv({
    required String plantLabel,
    required String rangeLabel,
    required List<WasteByProductRow> rows,
    required WasteQualityPeriodSummary period,
  }) {
    final sb = StringBuffer();
    sb.writeln(_esc('Otpad po proizvodu (dnevno)'));
    sb.writeln(_esc('Pogon: $plantLabel'));
    sb.writeln(_esc('Period: $rangeLabel'));
    sb.writeln(
      '${_esc('Period — ukupno dobro')};${_esc(_fmtNum(period.goodQty))}',
    );
    sb.writeln(
      '${_esc('Period — ukupno škart')};${_esc(_fmtNum(period.scrapQty))}',
    );
    sb.writeln(
      '${_esc('Period — otpad %')};${_esc(period.defectPct.toStringAsFixed(1).replaceAll('.', ','))}',
    );
    sb.writeln();
    sb.writeln(
      [
        _esc('Dan (yyyy-MM-dd)'),
        _esc('Proizvod'),
        _esc('Šifra (ako postoji)'),
        _esc('Dobro'),
        _esc('Škart'),
        _esc('Otpad %'),
      ].join(';'),
    );
    for (final r in rows) {
      sb.writeln(
        [
          _esc(r.workDateKey),
          _esc(r.productLine),
          _esc(r.subLine ?? ''),
          _esc(_fmtNum(r.goodQty)),
          _esc(_fmtNum(r.scrapQty)),
          _esc(r.defectPct.toStringAsFixed(1).replaceAll('.', ',')),
        ].join(';'),
      );
    }
    return _withBom(sb.toString());
  }

  static String buildQualityTrendCsv({
    required String plantLabel,
    required String rangeLabel,
    required List<QualityLineSeries> series,
    required WasteQualityPeriodSummary period,
  }) {
    final sb = StringBuffer();
    sb.writeln(_esc('Trend kvaliteta po proizvodnoj liniji (RC)'));
    sb.writeln(_esc('Pogon: $plantLabel'));
    sb.writeln(_esc('Period: $rangeLabel'));
    sb.writeln(
      '${_esc('Cijeli pogon — otpad % (period)')};${_esc(period.defectPct.toStringAsFixed(1).replaceAll('.', ','))}',
    );
    sb.writeln();
    for (final s in series) {
      sb.writeln(_esc('--- ${s.lineTitle} ---'));
      sb.writeln(
        [
          _esc('Dan'),
          _esc('Otpad %'),
          _esc('Dobro'),
          _esc('Škart'),
        ].join(';'),
      );
      for (final p in s.points) {
        if (p.goodQty + p.scrapQty <= 0) continue;
        sb.writeln(
          [
            _esc(p.workDateKey),
            _esc(p.defectPct.toStringAsFixed(1).replaceAll('.', ',')),
            _esc(_fmtNum(p.goodQty)),
            _esc(_fmtNum(p.scrapQty)),
          ].join(';'),
        );
      }
      final avg = s.periodAvgDefect;
      sb.writeln('${_esc('Prosjek linije (%)')};${_esc(avg.toStringAsFixed(1).replaceAll('.', ','))}');
      sb.writeln();
    }
    return _withBom(sb.toString());
  }

  static String _withBom(String s) => '\uFEFF$s';

  static Future<void> share({
    required String fileBaseName,
    required String csvBody,
  }) async {
    final safe = fileBaseName.replaceAll(RegExp(r'[^\w\-\.]+'), '_');
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$safe.csv';
    final f = File(path);
    await f.writeAsString(csvBody, encoding: utf8);
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Izvještaj (CSV)',
    );
  }
}
