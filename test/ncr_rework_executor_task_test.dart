import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/quality/models/ncr_rework_executor_task.dart';

void main() {
  group('NcrReworkExecutorTask', () {
    test('fromMap maps business fields without raw ids in display', () {
      final task = NcrReworkExecutorTask.fromMap({
        'ncrId': 'ncr-internal-id',
        'ncrCode': 'NCR-ABC123',
        'productCode': 'P-01',
        'productName': 'Proizvod A',
        'productLabel': 'P-01 — Proizvod A',
        'productionOrderCode': 'RN-2026-001',
        'machineName': 'CNC-1',
        'taskDescription': 'Ispraviti toleranciju',
        'dueAt': '2026-09-15T10:00:00.000Z',
        'quantityHint': 5,
        'canConfirm': true,
      });

      expect(task.displayNcrCode, 'NCR-ABC123');
      expect(task.displayProduct, 'P-01 — Proizvod A');
      expect(task.displayMachine, 'CNC-1');
      expect(task.quantityHint, 5);
      expect(task.canConfirm, isTrue);
    });
  });
}
