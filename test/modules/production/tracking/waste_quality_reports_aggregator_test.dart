import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/tracking/export/waste_quality_report_excel_export.dart';
import 'package:production_app/modules/production/tracking/models/production_operator_tracking_entry.dart';
import 'package:production_app/modules/production/tracking/models/tracking_scrap_line.dart';
import 'package:production_app/modules/production/tracking/services/production_tracking_analytics_service.dart';
import 'package:production_app/modules/production/tracking/services/waste_quality_reports_aggregator.dart';

void main() {
  group('summarizeWasteQualityPeriod', () {
    test('zbraja količine i postotke', () {
      final e = <ProductionOperatorTrackingEntry>[
        _e(
          id: 'a',
          qty: 100,
          scrap: [const TrackingScrapLine(code: 'DEF_001', label: 'A', qty: 10)],
        ),
        _e(
          id: 'b',
          qty: 50,
          scrap: [const TrackingScrapLine(code: 'DEF_001', label: 'A', qty: 5)],
        ),
      ];
      final s = summarizeWasteQualityPeriod(e);
      expect(s.totalQty, 150);
      expect(s.goodQty, 135);
      expect(s.scrapQty, 15);
      expect(s.entryCount, 2);
      expect(s.defectPct, closeTo(10, 0.0001));
      expect(s.yieldPct, closeTo(90, 0.0001));
    });
  });

  group('aggregateWasteByScrapType', () {
    test('grupira po kodu i računa udio', () {
      final entries = <ProductionOperatorTrackingEntry>[
        _e(
          id: '1',
          qty: 20,
          scrap: [const TrackingScrapLine(code: 'DEF_001', label: 'X', qty: 3)],
        ),
        _e(
          id: '2',
          qty: 20,
          scrap: [const TrackingScrapLine(code: 'DEF_002', label: 'Y', qty: 7)],
        ),
      ];
      final names = <String, String>{'DEF_001': 'Materijal'};
      final rows = aggregateWasteByScrapType(
        entries: entries,
        defectDisplayNames: names,
      );
      expect(rows, hasLength(2));
      expect(rows[0].code, 'DEF_002');
      expect(rows[0].qty, 7);
      expect(rows[1].code, 'DEF_001');
      expect(rows[1].label, 'Materijal');
      expect(rows[1].qty, 3);
      final sumPct =
          rows.map((r) => r.pctOfTotalScrap).fold<double>(0, (a, b) => a + b);
      expect(sumPct, closeTo(100, 0.01));
    });
  });

  group('aggregateWasteByProductPerDay', () {
    test('agregira po danu i šifri proizvoda', () {
      final entries = <ProductionOperatorTrackingEntry>[
        _e(
          id: '1',
          workDate: '2026-04-20',
          itemCode: 'P1',
          itemName: 'A',
          qty: 100,
          scrap: [const TrackingScrapLine(code: 'DEF_001', label: 's', qty: 10)],
        ),
        _e(
          id: '2',
          workDate: '2026-04-20',
          itemCode: 'P1',
          itemName: 'A',
          qty: 50,
          scrap: [const TrackingScrapLine(code: 'DEF_001', label: 's', qty: 5)],
        ),
        _e(
          id: '3',
          workDate: '2026-04-21',
          itemCode: 'P1',
          itemName: 'A',
          qty: 40,
          scrap: const [],
        ),
      ];
      final rows = aggregateWasteByProductPerDay(entries);
      expect(rows, hasLength(2));
      expect(rows[0].workDateKey, '2026-04-21');
      expect(rows[0].defectPct, 0.0);
      expect(rows[1].workDateKey, '2026-04-20');
      expect(rows[1].totalQty, 150);
      expect(rows[1].goodQty, 135);
      expect(rows[1].scrapQty, 15);
      expect(rows[1].defectPct, closeTo(10, 0.0001));
    });
  });

  group('aggregateQualityTrendByLine', () {
    test('grupira po radnom centru i ispunjava sve dane u rasponu', () {
      final entries = <ProductionOperatorTrackingEntry>[
        _e(
          id: '1',
          workDate: '2026-04-20',
          workCenterId: 'wc1',
          qty: 100,
          scrap: [const TrackingScrapLine(code: 'DEF_001', label: 's', qty: 10)],
        ),
        _e(
          id: '2',
          workDate: '2026-04-21',
          workCenterId: 'wc1',
          qty: 50,
          scrap: [const TrackingScrapLine(code: 'DEF_001', label: 's', qty: 5)],
        ),
      ];
      final days = <String>['2026-04-20', '2026-04-21', '2026-04-22'];
      final series = aggregateQualityTrendByLine(
        entries: entries,
        workDateKeysChronological: days,
        resolveLineTitle: (id) => id == 'wc1' ? 'Linija 1' : '—',
      );
      expect(series, hasLength(1));
      final s = series.first;
      expect(s.lineTitle, 'Linija 1');
      expect(s.points, hasLength(3));
      expect(s.points[0].defectPct, closeTo(10, 0.0001));
      expect(s.points[1].defectPct, closeTo(10, 0.0001));
      expect(
        s.points[2].defectPct,
        0.0,
      );
      expect(s.periodAvgDefect, closeTo(10, 0.0001));
    });
  });

  group('QualityLineSeries.isDeviation', () {
    test('ističe visok dan u odnosu na prosjek', () {
      expect(
        QualityLineSeries.isDeviation(dayDefectPct: 0, periodAvg: 5),
        false,
      );
      expect(
        QualityLineSeries.isDeviation(dayDefectPct: 4, periodAvg: 3),
        false,
      );
      expect(
        QualityLineSeries.isDeviation(dayDefectPct: 8, periodAvg: 4),
        true,
      );
    });
  });

  group('enumerateWorkDateKeysInRange', () {
    test('uključivo od-do', () {
      final a = DateTime(2026, 4, 20);
      final b = DateTime(2026, 4, 22);
      final list = enumerateWorkDateKeysInRange(a, b);
      expect(list, [
        '2026-04-20',
        '2026-04-21',
        '2026-04-22',
      ]);
    });
  });

  group('ProductionTrackingAnalyticsService.workDateKey', () {
    test('format yyyy-MM-dd', () {
      expect(
        ProductionTrackingAnalyticsService.workDateKey(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
    });
  });

  group('WasteQualityReportExcelExport', () {
    test('generira neprazan XLSX za otpad po tipu', () {
      final rows = aggregateWasteByScrapType(
        entries: [
          _e(
            id: '1',
            qty: 100,
            scrap: [
              const TrackingScrapLine(code: 'DEF_001', label: 'A', qty: 5),
            ],
          ),
        ],
        defectDisplayNames: const {'DEF_001': 'Materijal'},
      );
      final period = summarizeWasteQualityPeriod([
        _e(
          id: '1',
          qty: 100,
          scrap: [
            const TrackingScrapLine(code: 'DEF_001', label: 'A', qty: 5),
          ],
        ),
      ]);
      final bytes = WasteQualityReportExcelExport.buildScrapTypeXlsx(
        plantLabel: 'Test pogon',
        rangeLabel: '2026-04-01 – 2026-04-07',
        rows: rows,
        period: period,
      );
      expect(bytes.length, greaterThan(200));
      expect(String.fromCharCodes(bytes.sublist(0, 2)), 'PK');
    });
  });
}

ProductionOperatorTrackingEntry _e({
  required String id,
  String workDate = '2026-04-20',
  String itemCode = 'P1',
  String itemName = 'Proizvod',
  double qty = 100,
  String phase = ProductionOperatorTrackingEntry.phasePreparation,
  List<TrackingScrapLine> scrap = const [],
  String? workCenterId,
}) {
  return ProductionOperatorTrackingEntry(
    id: id,
    companyId: 'c1',
    plantKey: 'PLANT_1',
    phase: phase,
    workDate: workDate,
    itemCode: itemCode,
    itemName: itemName,
    quantity: qty,
    unit: 'kom',
    scrapBreakdown: scrap,
    workCenterId: workCenterId,
    createdByUid: 'u1',
    createdByEmail: 'u@test.local',
  );
}
