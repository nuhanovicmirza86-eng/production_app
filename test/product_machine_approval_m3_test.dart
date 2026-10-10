import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/products/product_machine_approval/pma_gateway.dart';
import 'package:production_app/modules/production/products/product_machine_approval/pma_models.dart';
import 'package:production_app/modules/production/products/product_machine_approval/product_machine_approval_tab.dart';

void main() {
  test('technology approval view keeps the business signature only', () {
    final view = PmaApprovalView.fromCallable({
      'omNumber': 'OM-2026-0001',
      'revision': 1,
      'title': 'OM-2026-0001 · rev.1',
      'state': 'technology_approved',
      'statusLabel': 'Tehnologija odobrena',
      'plantName': 'Brčko (BR)',
      'products': [
        {'productCode': 'P-1', 'productName': 'Kućište', 'productId': 'prod-1'},
      ],
      'machines': [
        {
          'machineCode': 'M-1',
          'machineName': 'Presa',
          'machineId': 'mach-1',
        },
      ],
      'technologyApproval': {
        'displayName': 'Ana Anić',
        'roleLabel': 'Inženjer tehnologije',
        'approvedAt': '2026-10-10T14:28:00.000Z',
        'uid': 'user-ana',
        'email': 'ana@example.com',
      },
      'companyId': 'co-1',
      'plantKey': 'PLANT_A',
    });
    final shown = [
      view.title,
      view.statusLabel,
      view.technologySignatureLabel,
      view.products.join(' '),
      view.machines.join(' '),
    ].join(' ');
    expect(view.statusLabel, 'Tehnologija odobrena');
    expect(shown.contains('Ana Anić'), isTrue);
    expect(shown.contains('Inženjer tehnologije'), isTrue);
    expect(shown.contains('user-ana'), isFalse);
    expect(shown.contains('ana@example.com'), isFalse);
    expect(shown.contains('prod-1'), isFalse);
    expect(shown.contains('mach-1'), isFalse);
    expect(shown.contains('PLANT_A'), isFalse);
    expect(shown.contains('co-1'), isFalse);
    expect(shown.contains('technology_approved'), isFalse);
  });

  testWidgets('only the technology engineer sees the approval action', (
    tester,
  ) async {
    await _pump(tester, gateway: _FakeGateway(), role: 'technology_engineer');
    expect(find.byKey(_approveKey), findsOneWidget);
    expect(find.text('Odobri tehnologiju'), findsOneWidget);

    for (final role in [
      'admin',
      'quality_control',
      'super_admin',
      'development_engineer',
      'production_manager',
      'production_operator',
      'shift_lead',
    ]) {
      await _pump(tester, gateway: _FakeGateway(), role: role);
      expect(find.byKey(_approveKey), findsNothing, reason: role);
      expect(find.text('Odobri tehnologiju'), findsNothing, reason: role);
    }
  });

  testWidgets('confirmation shows the scope and signs it once', (tester) async {
    final gateway = _FakeGateway();
    await _pump(tester, gateway: gateway, role: 'technology_engineer');
    await tester.tap(find.byKey(_approveKey));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const Key('pma_technology_approval_dialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('OM-2026-0001 · rev.1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('P-1 · Kućište')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('Pogon: Brčko (BR)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('M-1 · Presa')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Status: Nacrt')),
      findsOneWidget,
    );
    expect(gateway.approveCalls, 0);

    await tester.tap(find.byKey(const Key('pma_confirm_technology_approval')));
    await tester.pumpAndSettle();

    expect(gateway.approveCalls, 1);
    expect(gateway.lastOmNumber, 'OM-2026-0001');
    expect(gateway.lastRevision, 1);
    expect(find.text('Status: Tehnologija odobrena'), findsOneWidget);
    expect(
      find.text(
        'Technology odobrio: Ana Anić · Inženjer tehnologije · 10.10.2026. 16:40',
      ),
      findsOneWidget,
    );
    expect(find.text('Čeka potvrdu Kontrole kvaliteta.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pma_in_progress_section')),
        matching: find.text('OM-2026-0001 · rev.1'),
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
    expect(
      find.text('Trenutno nema potvrđenih odobrenih mašina za ovaj proizvod.'),
      findsOneWidget,
    );
    expect(find.byKey(_approveKey), findsNothing);
    expect(find.text('Odobri tehnologiju'), findsNothing);
    final visible = _visibleText(tester);
    expect(visible.contains('technology_approved'), isFalse);
    expect(visible.contains('user-ana'), isFalse);
    expect(visible.contains('prod-1'), isFalse);
    expect(visible.contains('mach-1'), isFalse);
    expect(visible.contains('PLANT_A'), isFalse);
    expect(visible.contains('co-1'), isFalse);
  });

  testWidgets('raw technical approval errors stay hidden', (tester) async {
    final gateway = _FakeGateway(
      approveError: FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'internal',
      ),
    );
    await _pump(tester, gateway: gateway, role: 'technology_engineer');
    await tester.tap(find.byKey(_approveKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pma_confirm_technology_approval')));
    await tester.pumpAndSettle();
    expect(find.text(pmaDataUnavailableMessage), findsOneWidget);
    expect(find.text('internal'), findsNothing);
    expect(find.text('permission-denied'), findsNothing);
    expect(find.text('Status: Nacrt'), findsWidgets);
    expect(find.text('Status: Tehnologija odobrena'), findsNothing);
  });
}

const _approveKey = Key('pma_approve_technology_OM-2026-0001_1');

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

String _visibleText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .join('\n');
}

class _FakeGateway implements ProductMachineApprovalGateway {
  _FakeGateway({this.approveError});

  final Object? approveError;
  int approveCalls = 0;
  String? lastOmNumber;
  int? lastRevision;
  List<PmaApprovalView> _approvals = [_draft];

  @override
  Future<PmaApprovalView> approveTechnology({
    required String omNumber,
    required int revision,
  }) async {
    final error = approveError;
    if (error != null) throw error;
    approveCalls += 1;
    lastOmNumber = omNumber;
    lastRevision = revision;
    _approvals = [_approved];
    return _approved;
  }

  @override
  Future<PmaApprovalView> createDraft(PmaDraftRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<PmaApprovalView> confirmQuality({
    required String omNumber,
    required int revision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PmaApprovalView> returnToTechnology({
    required String omNumber,
    required int revision,
  }) {
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

const _draft = PmaApprovalView(
  omNumber: 'OM-2026-0001',
  revision: 1,
  title: 'OM-2026-0001 · rev.1',
  statusLabel: 'Nacrt',
  state: 'draft',
  plantName: 'Brčko (BR)',
  productScopeLabel: 'Odabrani proizvodi',
  products: ['P-1 · Kućište'],
  machineScopeLabel: 'Odabrane mašine',
  machines: ['M-1 · Presa'],
  createdAtLabel: '10.10.2026. 12:00',
  creatorLabel: 'Ana Anić · Inženjer tehnologije',
);

const _approved = PmaApprovalView(
  omNumber: 'OM-2026-0001',
  revision: 1,
  title: 'OM-2026-0001 · rev.1',
  statusLabel: 'Tehnologija odobrena',
  state: 'technology_approved',
  plantName: 'Brčko (BR)',
  productScopeLabel: 'Odabrani proizvodi',
  products: ['P-1 · Kućište'],
  machineScopeLabel: 'Odabrane mašine',
  machines: ['M-1 · Presa'],
  createdAtLabel: '10.10.2026. 12:00',
  creatorLabel: 'Ana Anić · Inženjer tehnologije',
  technologyApproverLabel: 'Ana Anić · Inženjer tehnologije',
  technologyApprovedAtLabel: '10.10.2026. 16:40',
);
