import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/waste_quality_reports_aggregator.dart';

/// Izvoz istih agregata kao CSV, u XLSX (jedan radni list, blokovi s praznim redom).
class WasteQualityReportExcelExport {
  WasteQualityReportExcelExport._();

  static String _fmtNum(double v) {
    if (v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }

  static void _text(Sheet sh, int col, int row, String s) {
    sh
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(s);
  }

  static int _rowText(Sheet sh, int row, List<String> cells) {
    for (var i = 0; i < cells.length; i++) {
      _text(sh, i, row, cells[i]);
    }
    return row + 1;
  }

  static List<int> buildScrapTypeXlsx({
    required String plantLabel,
    required String rangeLabel,
    required List<WasteByScrapTypeRow> rows,
    required WasteQualityPeriodSummary period,
  }) {
    final ex = Excel.createExcel()..delete('Sheet1');
    const name = 'Otpad po tipu';
    final sh = ex[name];
    ex.setDefaultSheet(name);
    var r = 0;
    r = _rowText(sh, r, ['Otpad po tipu škarta', '', '']);
    r = _rowText(sh, r, ['Pogon', plantLabel, '']);
    r = _rowText(sh, r, ['Period', rangeLabel, '']);
    r = _rowText(
      sh,
      r,
      ['Ukupno dobro (kom)', _fmtNum(period.goodQty), ''],
    );
    r = _rowText(
      sh,
      r,
      ['Ukupno škart (kom)', _fmtNum(period.scrapQty), ''],
    );
    r = _rowText(sh, r, ['Broj unosa', '${period.entryCount}', '']);
    r++;
    r = _rowText(sh, r, ['Tip (prikaz)', 'Količina', 'Udio %']);
    for (final row in rows) {
      r = _rowText(
        sh,
        r,
        [
          row.label,
          _fmtNum(row.qty),
          '${row.pctOfTotalScrap.toStringAsFixed(1)}%',
        ],
      );
    }
    return _encodeOrThrow(ex);
  }

  static List<int> buildProductXlsx({
    required String plantLabel,
    required String rangeLabel,
    required List<WasteByProductRow> rows,
    required WasteQualityPeriodSummary period,
  }) {
    final ex = Excel.createExcel()..delete('Sheet1');
    const name = 'Otpad po proizvodu';
    final sh = ex[name];
    ex.setDefaultSheet(name);
    var r = 0;
    r = _rowText(sh, r, ['Otpad po proizvodu (dnevno)', '', '', '', '', '']);
    r = _rowText(sh, r, ['Pogon', plantLabel, '', '', '', '']);
    r = _rowText(sh, r, ['Period', rangeLabel, '', '', '', '']);
    r = _rowText(
      sh,
      r,
      [
        'Period — ukupno dobro',
        _fmtNum(period.goodQty),
        '',
        '',
        '',
        '',
      ],
    );
    r = _rowText(
      sh,
      r,
      [
        'Period — ukupno škart',
        _fmtNum(period.scrapQty),
        '',
        '',
        '',
        '',
      ],
    );
    r = _rowText(
      sh,
      r,
      [
        'Period — otpad %',
        '${period.defectPct.toStringAsFixed(1)}%',
        '',
        '',
        '',
        '',
      ],
    );
    r++;
    r = _rowText(
      sh,
      r,
      [
        'Dan (yyyy-MM-dd)',
        'Proizvod',
        'Šifra (ako postoji)',
        'Dobro',
        'Škart',
        'Otpad %',
      ],
    );
    for (final p in rows) {
      r = _rowText(
        sh,
        r,
        [
          p.workDateKey,
          p.productLine,
          p.subLine ?? '',
          _fmtNum(p.goodQty),
          _fmtNum(p.scrapQty),
          '${p.defectPct.toStringAsFixed(1)}%',
        ],
      );
    }
    return _encodeOrThrow(ex);
  }

  static List<int> buildQualityTrendXlsx({
    required String plantLabel,
    required String rangeLabel,
    required List<QualityLineSeries> series,
    required WasteQualityPeriodSummary period,
  }) {
    final ex = Excel.createExcel()..delete('Sheet1');
    const name = 'Trend kvaliteta';
    final sh = ex[name];
    ex.setDefaultSheet(name);
    var r = 0;
    r = _rowText(
      sh,
      r,
      [
        'Trend kvaliteta po proizvodnoj liniji (RC)',
        '',
        '',
        '',
      ],
    );
    r = _rowText(sh, r, ['Pogon', plantLabel, '', '', '']);
    r = _rowText(sh, r, ['Period', rangeLabel, '', '', '']);
    r = _rowText(
      sh,
      r,
      [
        'Cijeli pogon — otpad % (period)',
        '${period.defectPct.toStringAsFixed(1)}%',
        '',
        '',
        '',
      ],
    );
    r++;
    for (final s in series) {
      r = _rowText(
        sh,
        r,
        [s.lineTitle, '', '', ''],
      );
      r = _rowText(
        sh,
        r,
        ['Dan', 'Otpad %', 'Dobro', 'Škart'],
      );
      for (final p in s.points) {
        if (p.goodQty + p.scrapQty <= 0) {
          continue;
        }
        r = _rowText(
          sh,
          r,
          [
            p.workDateKey,
            '${p.defectPct.toStringAsFixed(1)}%',
            _fmtNum(p.goodQty),
            _fmtNum(p.scrapQty),
          ],
        );
      }
      r = _rowText(
        sh,
        r,
        [
          'Prosjek linije (%)',
          s.periodAvgDefect.toStringAsFixed(1),
          '',
          '',
        ],
      );
      r++;
    }
    return _encodeOrThrow(ex);
  }

  static List<int> _encodeOrThrow(Excel ex) {
    final b = ex.encode();
    if (b == null) {
      throw StateError('Kodiranje XLSX nije uspjelo.');
    }
    return b;
  }

  static Future<void> share({
    required String fileBaseName,
    required List<int> xlsxBytes,
  }) async {
    final safe =
        fileBaseName.replaceAll(RegExp(r'[^\w\-\.]+'), '_');
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$safe.xlsx';
    final f = File(path);
    await f.writeAsBytes(xlsxBytes, flush: true);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'Izvještaj (Excel)',
    );
  }
}
