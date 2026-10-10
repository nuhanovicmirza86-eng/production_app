import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/products/product_machine_approval/pma_gateway.dart';
import 'package:production_app/modules/production/products/product_machine_approval/pma_models.dart';
import 'package:production_app/modules/production/products/product_machine_approval/product_machine_approval_tab.dart';

void main() {
  test('Product Details ends with Odobrene mašine', () {
    expect(productDetailsTabLabels.length, 8);
    expect(productDetailsTabLabels.last, 'Odobrene mašine');
    expect(productDetailsTabLabels, [
      'Osnovni podaci',
      'BOM',
      'Routing',
      'Nalozi',
      'Zaliha',
      'Dokumentacija',
      'Reklamacije',
      'Odobrene mašine',
    ]);
  });

  test('business view keeps codes and drops technical identity', () {
    final view = PmaApprovalView.fromCallable({
      'omNumber': 'OM-2026-0001',
      'revision': 1,
      'title': 'OM-2026-0001 · rev.1',
      'state': 'draft',
      'statusLabel': 'Nacrt',
      'plantName': 'Brčko (BR)',
      'productScopeLabel': 'Odabrani proizvodi',
      'products': [
        {'productCode': 'P-1', 'productName': 'Kućište', 'productId': 'prod-1'},
      ],
      'machineScopeLabel': 'Odabrane mašine',
      'machines': [
        {'machineCode': 'M-1', 'machineName': 'Presa', 'machineId': 'mach-1'},
      ],
      'createdAt': '2026-10-10T10:00:00.000Z',
      'creatorName': 'Ana Anić',
      'creatorRoleLabel': 'Inženjer tehnologije',
      'companyId': 'co-1',
      'plantKey': 'PLANT_A',
      'uid': 'user-ana',
    });
    final shown = [
      view.title,
      view.statusLabel,
      view.plantName,
      view.products.join(' '),
      view.machines.join(' '),
      view.creatorLabel,
      view.createdAtLabel,
    ].join(' ');
    expect(view.title, 'OM-2026-0001 · rev.1');
    expect(view.creatorLabel, 'Ana Anić · Inženjer tehnologije');
    expect(shown.contains('prod-1'), isFalse);
    expect(shown.contains('mach-1'), isFalse);
    expect(shown.contains('PLANT_A'), isFalse);
    expect(shown.contains('co-1'), isFalse);
    expect(shown.contains('user-ana'), isFalse);
    expect(shown.contains('@'), isFalse);
  });

  testWidgets('technology engineer creates a draft and sees it after refresh', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _pump(
      tester,
      gateway: gateway,
      role: 'technology_engineer',
    );
    expect(
      find.text('Trenutno nema potvrđenih odobrenih mašina za ovaj proizvod.'),
      findsOneWidget,
    );
    expect(find.text('Nema odobrenja u toku.'), findsOneWidget);
    expect(find.text('Dodijeli novu mašinu'), findsOneWidget);
    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('Kućište'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pma_create_approval')));
    await tester.pumpAndSettle();

    expect(find.text('Odabrani proizvodi'), findsNothing);
    expect(find.text('Svi proizvodi'), findsNothing);
    expect(find.text('P-2 · Poklopac'), findsNothing);
    expect(find.text('M-1 · Presa'), findsOneWidget);
    expect(find.text('M-2 · Linija'), findsOneWidget);

    await tester.ensureVisible(find.text('M-1 · Presa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M-1 · Presa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pma_save_draft')));
    await tester.pumpAndSettle();

    expect(gateway.lastRequest!.productId, 'prod-1');
    expect(gateway.lastRequest!.machineScopeMode, 'selected_machines');
    expect(gateway.lastRequest!.machineIds, ['mach-1']);
    expect(find.text('OM-2026-0001 · rev.1'), findsOneWidget);
    expect(find.text('Status: Nacrt'), findsOneWidget);
    expect(find.text('Priprema odobrenja. Mašina još nije odobrena.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pma_approved_section')),
        matching: find.text('OM-2026-0001 · rev.1'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('pma_in_progress_section')),
        matching: find.text('OM-2026-0001 · rev.1'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Trenutno nema potvrđenih odobrenih mašina za ovaj proizvod.'),
      findsOneWidget,
    );
    expect(find.text('Pogon: Brčko (BR)'), findsOneWidget);
    expect(find.textContaining('Ana Anić'), findsOneWidget);
    expect(_visibleText(tester).contains('prod-1'), isFalse);
    expect(_visibleText(tester).contains('mach-1'), isFalse);
    expect(_visibleText(tester).contains('PLANT_A'), isFalse);
  });

  testWidgets('several machines can be assigned to the current product', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _pump(tester, gateway: gateway, role: 'quality_control');
    await tester.tap(find.byKey(const Key('pma_create_approval')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M-1 · Presa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M-2 · Linija'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pma_save_draft')));
    await tester.pumpAndSettle();
    expect(gateway.lastRequest!.productId, 'prod-1');
    expect(gateway.lastRequest!.machineIds.toSet(), {'mach-1', 'mach-2'});
    expect(find.text('OM-2026-0001 · rev.1'), findsOneWidget);
  });

  testWidgets('all machines in the plant stay on the current product', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _pump(tester, gateway: gateway, role: 'admin');
    await tester.tap(find.byKey(const Key('pma_create_approval')));
    await tester.pumpAndSettle();
    expect(find.text('Svi proizvodi'), findsNothing);
    await tester.tap(find.text('Sve mašine u pogonu'));
    await tester.pumpAndSettle();
    expect(find.text('M-1 · Presa'), findsNothing);
    expect(
      find.textContaining('Snima se tačan popis'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pma_save_draft')));
    await tester.pumpAndSettle();
    expect(gateway.lastRequest!.productId, 'prod-1');
    expect(gateway.lastRequest!.machineScopeMode, 'all_machines');
    expect(gateway.lastRequest!.machineIds, isEmpty);
    expect(find.text('Sve mašine u pogonu'), findsWidgets);
    expect(find.textContaining('M-1 · Presa'), findsOneWidget);
    expect(find.textContaining('M-2 · Linija'), findsOneWidget);
  });

  testWidgets('plant-bound preparer keeps the session plant', (tester) async {
    final gateway = _FakeGateway();
    await _pump(
      tester,
      gateway: gateway,
      role: 'production_manager',
      plantKey: 'PLANT_A',
    );
    await tester.tap(find.byKey(const Key('pma_create_approval')));
    await tester.pumpAndSettle();
    expect(find.text('Pogon: Brčko (BR)'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(_visibleText(tester).contains('PLANT_A'), isFalse);
  });

  testWidgets('raw internal from the list callable is not shown', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: _FakeGateway(
        listError: FirebaseFunctionsException(
          code: 'internal',
          message: 'internal',
        ),
      ),
      role: 'technology_engineer',
    );
    expect(find.text('internal'), findsNothing);
    expect(find.text('FirebaseFunctionsException'), findsNothing);
    expect(find.text(pmaDataUnavailableMessage), findsOneWidget);
  });

  testWidgets('raw internal under the machine list is not shown', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      createError: FirebaseFunctionsException(
        code: 'internal',
        message: 'internal',
      ),
    );
    await _pump(tester, gateway: gateway, role: 'technology_engineer');
    await tester.tap(find.byKey(const Key('pma_create_approval')));
    await tester.pumpAndSettle();
    expect(find.text('M-1 · Presa'), findsOneWidget);
    await tester.tap(find.text('M-1 · Presa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pma_save_draft')));
    await tester.pumpAndSettle();
    expect(find.text('M-1 · Presa'), findsOneWidget);
    expect(find.text('internal'), findsNothing);
    expect(find.text('FirebaseFunctionsException'), findsNothing);
    expect(find.text(pmaDataUnavailableMessage), findsOneWidget);
  });

  testWidgets('business callable message stays visible', (tester) async {
    const business = 'U odabranom pogonu nema aktivnih mašina za odobrenje.';
    final gateway = _FakeGateway(
      createError: FirebaseFunctionsException(
        code: 'failed-precondition',
        message: business,
      ),
    );
    await _pump(tester, gateway: gateway, role: 'admin');
    await tester.tap(find.byKey(const Key('pma_create_approval')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M-1 · Presa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pma_save_draft')));
    await tester.pumpAndSettle();
    expect(find.text(business), findsOneWidget);
    expect(find.text('failed-precondition'), findsNothing);
    expect(find.text(pmaDataUnavailableMessage), findsNothing);
  });

  testWidgets('unauthorized roles do not see create', (tester) async {
    for (final role in [
      'super_admin',
      'development_engineer',
      'production_operator',
    ]) {
      await _pump(tester, gateway: _FakeGateway(), role: role);
      expect(find.byKey(const Key('pma_create_approval')), findsNothing);
      expect(
        find.text('Trenutno nema potvrđenih odobrenih mašina za ovaj proizvod.'),
        findsOneWidget,
      );
      expect(find.text('Dodijeli novu mašinu'), findsNothing);
    }
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required ProductMachineApprovalGateway gateway,
  required String role,
  String plantKey = '',
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
          companyData: {
            'companyId': 'co-1',
            'role': role,
            'plantKey': plantKey,
          },
          productId: 'prod-1',
          productCode: 'P-1',
          productName: 'Kućište',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _visibleText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .join('\n');
}

class _FakeGateway implements ProductMachineApprovalGateway {
  _FakeGateway({this.listError, this.createError});

  PmaDraftRequest? lastRequest;
  final Object? listError;
  final Object? createError;
  final List<PmaApprovalView> _approvals = [];

  @override
  Future<PmaApprovalView> createDraft(PmaDraftRequest request) async {
    final error = createError;
    if (error != null) throw error;
    lastRequest = request;
    final allMachines = request.machineScopeMode == 'all_machines';
    final view = PmaApprovalView(
      omNumber: 'OM-2026-0001',
      revision: 1,
      title: 'OM-2026-0001 · rev.1',
      statusLabel: 'Nacrt',
      plantName: 'Brčko (BR)',
      productScopeLabel: 'Odabrani proizvodi',
      products: const ['P-1 · Kućište'],
      machineScopeLabel: allMachines
          ? 'Sve mašine u pogonu'
          : 'Odabrane mašine',
      machines: allMachines
          ? const ['M-1 · Presa', 'M-2 · Linija']
          : request.machineIds.length > 1
          ? const ['M-1 · Presa', 'M-2 · Linija']
          : const ['M-1 · Presa'],
      createdAtLabel: '10.10.2026. 12:00',
      creatorLabel: 'Ana Anić · Inženjer tehnologije',
    );
    _approvals
      ..clear()
      ..add(view);
    return view;
  }

  @override
  Future<PmaApprovalView> approveTechnology({
    required String omNumber,
    required int revision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<PmaApprovalView>> listForProduct({
    required String productId,
  }) async {
    final error = listError;
    if (error != null) throw error;
    return List<PmaApprovalView>.from(_approvals);
  }

  @override
  Future<List<PmaMachineOption>> listMachines({
    required String companyId,
    required String plantKey,
  }) async {
    return const [
      PmaMachineOption(machineId: 'mach-1', machineCode: 'M-1', machineName: 'Presa'),
      PmaMachineOption(machineId: 'mach-2', machineCode: 'M-2', machineName: 'Linija'),
    ];
  }

  @override
  Future<List<PmaPlantOption>> listPlants(String companyId) async {
    return const [
      PmaPlantOption(plantKey: 'PLANT_A', plantName: 'Brčko (BR)'),
      PmaPlantOption(plantKey: 'PLANT_B', plantName: 'Tuzla (TZ)'),
    ];
  }

}
