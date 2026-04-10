import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../auth/register/screens/pending_users_screen.dart';
import '../../../commercial/partners/screens/partners_screen.dart';
import '../../../commercial/orders/screens/orders_list_screen.dart';
import '../../products/screens/products_list_screen.dart';
import '../../../logistics/receipt/screens/production_label_receipt_screen.dart';
import '../../production_orders/screens/production_order_details_screen.dart';
import '../../production_orders/screens/production_orders_list_screen.dart';
import '../../qr/production_qr_resolver.dart';
import '../../qr/screens/production_qr_scan_screen.dart';

class ProductionDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ProductionDashboardScreen({super.key, required this.companyData});

  String get _companyId => (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey => (companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      (companyData['role'] ?? '').toString().trim().toLowerCase();

  List<String> get _enabledModules {
    final raw = companyData['enabledModules'];

    if (raw is List) {
      return raw.map((e) => e.toString().trim().toLowerCase()).toList();
    }

    return const [];
  }

  bool _hasModule(String moduleKey) {
    final normalized = moduleKey.trim().toLowerCase();

    if (_enabledModules.isEmpty) {
      return normalized == 'production';
    }

    return _enabledModules.contains(normalized);
  }

  bool _canViewCard(ProductionDashboardCard card) {
    return ProductionAccessHelper.canView(role: _role, card: card);
  }

  bool _canShowReportsCard() {
    return _canViewCard(ProductionDashboardCard.reports) &&
        ProductionAccessHelper.hasAnyReports(companyData);
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proizvodnja')),
        body: const Center(child: Text('Nedostaje companyData')),
      );
    }

    final showProductionModule = _hasModule('production');
    final showAdminSection = _canViewCard(
      ProductionDashboardCard.registrations,
    );

    final productionCards = <Widget>[
      _DashboardCard(
        title: 'Skeniraj QR',
        icon: Icons.qr_code_scanner,
        onTap: () => _openProductionQrScan(context),
      ),
      if (_canViewCard(ProductionDashboardCard.products))
        _DashboardCard(
          title: 'Proizvodi',
          icon: Icons.inventory_2_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductsListScreen(companyData: companyData),
              ),
            );
          },
        ),

      if (_canViewCard(ProductionDashboardCard.productionOrders))
        _DashboardCard(
          title: 'Proizvodni nalozi',
          icon: Icons.assignment,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProductionOrdersListScreen(companyData: companyData),
              ),
            );
          },
        ),

      // ✅ FIX: Narudžbe više NE zavise od productionOrders permission
      _DashboardCard(
        title: 'Narudžbe',
        icon: Icons.receipt_long_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrdersListScreen(companyData: companyData),
            ),
          );
        },
      ),

      _DashboardCard(
        title: 'Kupci / dobavljači',
        icon: Icons.groups_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartnersScreen(companyData: companyData),
            ),
          );
        },
      ),

      if (_canViewCard(ProductionDashboardCard.productionTracking))
        _DashboardCard(
          title: 'Praćenje proizvodnje',
          icon: Icons.play_circle_outline,
          onTap: () {
            _notImplemented(context);
          },
        ),

      if (_canViewCard(ProductionDashboardCard.workCenters))
        _DashboardCard(
          title: 'Radni centri',
          icon: Icons.precision_manufacturing_outlined,
          onTap: () {
            _notImplemented(context);
          },
        ),

      if (_canViewCard(ProductionDashboardCard.shifts))
        _DashboardCard(
          title: 'Smjene',
          icon: Icons.schedule,
          onTap: () {
            _notImplemented(context);
          },
        ),

      if (_canViewCard(ProductionDashboardCard.downtime))
        _DashboardCard(
          title: 'Zastoji',
          icon: Icons.warning_amber_outlined,
          onTap: () {
            _notImplemented(context);
          },
        ),

      if (_canViewCard(ProductionDashboardCard.problemReporting))
        _DashboardCard(
          title: 'Prijava problema',
          icon: Icons.report_problem_outlined,
          onTap: () {
            _notImplemented(context);
          },
        ),

      if (_canViewCard(ProductionDashboardCard.processExecution))
        _DashboardCard(
          title: 'Evidencija procesa',
          icon: Icons.science_outlined,
          onTap: () {
            _notImplemented(context);
          },
        ),

      if (_canShowReportsCard())
        _DashboardCard(
          title: 'Izvještaji',
          icon: Icons.assessment_outlined,
          onTap: () {
            _notImplemented(context);
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Proizvodnja')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ContextCard(companyId: _companyId, plantKey: _plantKey),
          const SizedBox(height: 16),

          if (showAdminSection) ...[
            const _SectionTitle(title: 'Administracija'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.15,
              children: [
                _DashboardCard(
                  title: 'Registracije',
                  icon: Icons.person_add_alt_1,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PendingUsersScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (showProductionModule && productionCards.isNotEmpty) ...[
            const _SectionTitle(title: 'Proizvodnja'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.15,
              children: productionCards,
            ),
          ],

          if (!showProductionModule || productionCards.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  'Nema dostupnih modula za prikaz.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _notImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ovaj ekran još nije implementiran.')),
    );
  }

  Future<void> _openProductionQrScan(BuildContext context) async {
    final resolution = await Navigator.push<ProductionQrScanResolution>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProductionQrScanScreen(companyData: companyData),
      ),
    );

    if (!context.mounted || resolution == null) return;

    switch (resolution.intent) {
      case ProductionQrIntent.productionOrderReferenceV1:
        final id = resolution.productionOrderId?.trim();
        if (id == null || id.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'QR ne sadrži ID naloga. Koristite noviji ispis (po:v1 sa poljem id).',
              ),
            ),
          );
          return;
        }
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ProductionOrderDetailsScreen(
              companyData: companyData,
              productionOrderId: id,
            ),
          ),
        );
        break;

      case ProductionQrIntent.printedClassificationLabelV1:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ProductionLabelReceiptScreen(
              companyData: companyData,
              resolution: resolution,
            ),
          ),
        );
        break;

      case ProductionQrIntent.nepoznat:
        final raw = resolution.rawPayload;
        final preview = raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nepoznat QR. Sadržaj: $preview'),
          ),
        );
        break;
    }
  }
}

class _ContextCard extends StatelessWidget {
  final String companyId;
  final String plantKey;

  const _ContextCard({required this.companyId, required this.plantKey});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              'Kompanija: $companyId',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Pogon: $plantKey',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
