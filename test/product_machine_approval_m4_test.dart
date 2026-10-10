import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/products/product_machine_approval/pma_gateway.dart';
import 'package:production_app/modules/production/products/product_machine_approval/pma_models.dart';
import 'package:production_app/modules/production/products/product_machine_approval/product_machine_approval_tab.dart';

void main() {
  test('quality confirmation view keeps the business signature only', () {
    final view = PmaApprovalView.fromCallable({
      'omNumber': 'OM-2026-0001',
      'revision': 1,
      'title': 'OM-2026-0001 · rev.1',
      'state': 'quality_confirmed',
      'statusLabel': 'Kvalitet potvrdio',
      'plantName': 'Brčko (BR)',
      'qualityApproval': {
        'displayName': 'Emina Kvalitet',
        'roleLabel': 'Menadžer kvaliteta',
        'approvedAt': '2026-10-10T16:40:00.000Z',
        'uid': 'user-qc',
        'email': 'emina@example.com',
      },
      'technologyApproval': {
        'displayName': 'Ana Anić',
        'roleLabel': 'Inženjer tehnologije',
        'approvedAt': '2026-10-10T14:28:00.000Z',
        'uid': 'user-ana',
      },
    });
    final shown = '${view.qualitySignatureLabel} ${view.technologySignatureLabel}';
    expect(view.isQualityConfirmed, isTrue);
    expect(shown.contains('Emina Kvalitet'), isTrue);
    expect(shown.contains('Menadžer kvaliteta'), isTrue);
    expect(shown.contains('user-qc'), isFalse);
    expect(shown.contains('emina@example.com'), isFalse);
    expect(shown.contains('user-ana'), isFalse);
  });

  testWidgets('only quality control sees confirm and return on a signed revision', (
    tester,
  ) async {
    await _pump(tester, gateway: _FakeGateway(), role: 'quality_control');
    expect(find.text('Potvrdi kvalitet'), findsOneWidget);
    expect(find.text('Vrati tehnologiji'), findsOneWidget);
    expect(find.text('Odobri tehnologiju'), findsNothing);
    expect(find.byKey(const Key('pma_in_progress_section')), findsOneWidget);

    for (final role in [
      'admin',
      'technology_engineer',
      'super_admin',
      'production_manager',
      'production_operator',
      'shift_lead',
      'development_engineer',
    ]) {
      await _pump(tester, gateway: _FakeGateway(), role: role);
      expect(find.text('Potvrdi kvalitet'), findsNothing, reason: role);
      expect(find.text('Vrati tehnologiji'), findsNothing, reason: role);
    }
  });

  testWidgets('confirmation moves the record to approved machines', (tester) async {
    final gateway = _FakeGateway();
    await _pump(tester, gateway: gateway, role: 'quality_control');
    await tester.tap(find.byKey(const Key('pma_confirm_quality_OM-2026-0001_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pma_quality_confirmation_dialog')), findsOneWidget);
    expect(find.text('Potvrdi kvalitet'), findsWidgets);
    await tester.tap(find.byKey(const Key('pma_confirm_quality_approval')));
    await tester.pumpAndSettle();

    expect(gateway.confirmCalls, 1);
    expect(find.text('Status: Kvalitet potvrdio'), findsOneWidget);
    expect(find.text('Kvalitet potvrdio: Emina Kvalitet · Menadžer kvaliteta · 10.10.2026. 18:40'), findsOneWidget);
    expect(find.text('Potvrdi kvalitet'), findsNothing);
    expect(find.text('Vrati tehnologiji'), findsNothing);
    expect(find.text('Odobri tehnologiju'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('pma_approved_section')),
        matching: find.text('OM-2026-0001 · rev.1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('pma_in_progress_section')),
        matching: find.text('OM-2026-0001 · rev.1'),
      ),
      findsNothing,
    );
    final visible = _visible(tester);
    expect(visible.contains('user-qc'), isFalse);
    expect(visible.contains('quality_confirmed'), isFalse);
    expect(visible.contains('PLANT_A'), isFalse);
  });

  testWidgets('return stays in progress and closes the revision', (tester) async {
    final gateway = _FakeGateway();
    await _pump(tester, gateway: gateway, role: 'quality_control');
    await tester.tap(find.byKey(const Key('pma_return_technology_OM-2026-0001_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pma_quality_return_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pma_confirm_quality_return')));
    await tester.pumpAndSettle();

    expect(gateway.returnCalls, 1);
    expect(find.text('Status: Otkazano'), findsOneWidget);
    expect(find.text('Vraćeno od Kontrole kvaliteta.'), findsOneWidget);
    expect(find.text('Technology odobrio: Ana Anić · Inženjer tehnologije · 10.10.2026. 16:28'), findsOneWidget);
    expect(find.text('Potvrdi kvalitet'), findsNothing);
    expect(find.text('Vrati tehnologiji'), findsNothing);
    expect(find.text('Odobri tehnologiju'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('pma_in_progress_section')),
        matching: find.text('Status: Otkazano'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('pma_approved_section')),
        matching: find.text('OM-2026-0001 · rev.1'),
      ),
      findsNothing,
    );
    expect(_visible(tester).contains('quality_return'), isFalse);
  });

  testWidgets('draft rendering and technology action stay unchanged', (tester) async {
    await _pump(tester, gateway: _FakeGateway(initial: _draft), role: 'technology_engineer');
    expect(find.text('Status: Nacrt'), findsOneWidget);
    expect(find.text('Priprema odobrenja. Mašina još nije odobrena.'), findsOneWidget);
    expect(find.text('Odobri tehnologiju'), findsOneWidget);
    expect(find.text('Potvrdi kvalitet'), findsNothing);
    expect(find.text('Vrati tehnologiji'), findsNothing);
    expect(
      find.text('Trenutno nema potvrđenih odobrenih mašina za ovaj proizvod.'),
      findsOneWidget,
    );
  });
}

PmaApprovalView _view({
  required String state,
  required String statusLabel,
}) {
  return PmaApprovalView(
    omNumber: 'OM-2026-0001',
    revision: 1,
    title: 'OM-2026-0001 · rev.1',
    statusLabel: statusLabel,
    plantName: 'Brčko (BR)',
    productScopeLabel: 'Odabrani proizvodi',
    products: const ['P-1 · Kućište'],
    machineScopeLabel: 'Odabrane mašine',
    machines: const ['M-1 · Presa'],
    createdAtLabel: '10.10.2026. 12:00',
    creatorLabel: 'Ana Anić · Inženjer tehnologije',
    state: state,
    technologyApproverLabel: 'Ana Anić · Inženjer tehnologije',
    technologyApprovedAtLabel: '10.10.2026. 16:28',
  );
}

final _draft = _view(state: 'draft', statusLabel: 'Nacrt');
final _signed = _view(state: 'technology_approved', statusLabel: 'Tehnologija odobrena');
final _confirmed = PmaApprovalView(
  omNumber: 'OM-2026-0001',
  revision: 1,
  title: 'OM-2026-0001 · rev.1',
  statusLabel: 'Kvalitet potvrdio',
  plantName: 'Brčko (BR)',
  productScopeLabel: 'Odabrani proizvodi',
  products: const ['P-1 · Kućište'],
  machineScopeLabel: 'Odabrane mašine',
  machines: const ['M-1 · Presa'],
  createdAtLabel: '10.10.2026. 12:00',
  creatorLabel: 'Ana Anić · Inženjer tehnologije',
  state: 'quality_confirmed',
  technologyApproverLabel: 'Ana Anić · Inženjer tehnologije',
  technologyApprovedAtLabel: '10.10.2026. 16:28',
  qualityApproverLabel: 'Emina Kvalitet · Menadžer kvaliteta',
  qualityApprovedAtLabel: '10.10.2026. 18:40',
);
final _returned = _view(state: 'cancelled', statusLabel: 'Otkazano');

class _FakeGateway implements ProductMachineApprovalGateway {
  _FakeGateway({PmaApprovalView? initial}) : _approvals = [initial ?? _signed];

  List<PmaApprovalView> _approvals;
  int confirmCalls = 0;
  int returnCalls = 0;

  @override
  Future<PmaApprovalView> confirmQuality({
    required String omNumber,
    required int revision,
  }) async {
    confirmCalls += 1;
    _approvals = [_confirmed];
    return _confirmed;
  }

  @override
  Future<PmaApprovalView> returnToTechnology({
    required String omNumber,
    required int revision,
  }) async {
    returnCalls += 1;
    _approvals = [_returned];
    return _returned;
  }

  @override
  Future<PmaApprovalView> approveTechnology({
    required String omNumber,
    required int revision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PmaApprovalView> createDraft(PmaDraftRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<List<PmaApprovalView>> listForProduct({required String productId}) async {
    return List<PmaApprovalView>.from(_approvals);
  }

  @override
  Future<List<PmaMachineOption>> listMachines({
    required String companyId,
    required String plantKey,
  }) async {
    return const [];
  }

  @override
  Future<List<PmaPlantOption>> listPlants(String companyId) async {
    return const [];
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required ProductMachineApprovalGateway gateway,
  required String role,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductMachineApprovalTab(
          gateway: gateway,
          companyData: {'companyId': 'co-1', 'role': role, 'plantKey': ''},
          productId: 'prod-1',
          productCode: 'P-1',
          productName: 'Kućište',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _visible(WidgetTester tester) {
  return tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data ?? '').join('\n');
}
