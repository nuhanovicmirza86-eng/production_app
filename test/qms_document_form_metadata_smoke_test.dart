import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/quality/models/qms_list_models.dart';
import 'package:production_app/modules/quality/widgets/qms_display_formatters.dart';

/// M1-I4-D-B — model + status mapiranje za kontrolisane obrasce.
void main() {
  test('QmsDocumentRow parses company-wide form metadata', () {
    final row = QmsDocumentRow.fromMap({
      'id': 'doc1',
      'documentCode': 'QF-PC-001',
      'title': 'Evidencijski zapisnik — Procesna kontrola kvaliteta',
      'documentKind': 'form',
      'scopeType': 'company',
      'productId': '',
      'status': 'approved',
      'revision': 1,
      'ownerDepartment': 'Kontrola kvaliteta',
      'retentionCategory': 'Zapisi kvaliteta',
    });
    expect(row.documentCode, 'QF-PC-001');
    expect(row.scopeType, 'company');
    expect(row.revision, 1);
    expect(row.ownerDepartment, 'Kontrola kvaliteta');
    expect(row.retentionCategory, 'Zapisi kvaliteta');
    expect(row.productId, isEmpty);
  });

  test('QmsDocumentRow infers company scope when productId empty', () {
    final row = QmsDocumentRow.fromMap({
      'id': 'doc2',
      'title': 'Obrazac',
      'documentKind': 'form',
      'status': 'draft',
    });
    expect(row.scopeType, 'company');
  });

  test('PDF status map: approved→Aktivno, obsolete→Van upotrebe', () {
    expect(QmsDisplayFormatters.qmsControlledFormStatus('draft'), 'Nacrt');
    expect(QmsDisplayFormatters.qmsControlledFormStatus('approved'), 'Aktivno');
    expect(
      QmsDisplayFormatters.qmsControlledFormStatus('obsolete'),
      'Van upotrebe',
    );
  });

  test('UI list status lifecycle labels unchanged', () {
    expect(QmsDisplayFormatters.qmsDocStatus('draft'), 'Nacrt');
    expect(QmsDisplayFormatters.qmsDocStatus('approved'), 'Odobreno');
    expect(QmsDisplayFormatters.qmsDocStatus('obsolete'), 'Zastarjelo');
  });
}
