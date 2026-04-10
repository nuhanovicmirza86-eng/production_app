import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_logo_resolver.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../auth/shared/services/auth_service.dart';
import '../../../auth/register/screens/pending_users_screen.dart';
import '../../../commercial/partners/screens/partners_screen.dart';
import '../../../commercial/orders/screens/orders_list_screen.dart';
import '../../products/screens/products_list_screen.dart';
import '../../../logistics/receipt/screens/production_label_receipt_screen.dart';
import '../../../sustainability/screens/carbon_footprint_screen.dart';
import '../../production_orders/screens/production_order_details_screen.dart';
import '../../production_orders/screens/production_orders_list_screen.dart';
import '../../qr/production_qr_resolver.dart';
import '../../qr/screens/production_qr_scan_screen.dart';

class ProductionDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ProductionDashboardScreen({super.key, required this.companyData});

  String get _companyId => (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey => (companyData['plantKey'] ?? '').toString().trim();

  String get _companyDisplayName {
    final n = (companyData['name'] ?? companyData['companyName'] ?? '')
        .toString()
        .trim();
    if (n.isNotEmpty) return n;
    return _companyId;
  }

  String get _role =>
      (companyData['role'] ?? '').toString().trim().toLowerCase();

  static String _prettyRoleLabel(String role) {
    final r = role.trim().toLowerCase();
    switch (r) {
      case ProductionAccessHelper.roleAdmin:
        return 'Administrator';
      case ProductionAccessHelper.roleProductionManager:
        return 'Menadžer proizvodnje';
      case ProductionAccessHelper.roleSupervisor:
        return 'Supervizor';
      case ProductionAccessHelper.roleProductionOperator:
        return 'Operater proizvodnje';
      case ProductionAccessHelper.roleMaintenanceManager:
        return 'Menadžer održavanja';
      default:
        return r.isEmpty ? '-' : role;
    }
  }

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

  static const double _tileGap = 10;

  List<Widget> _buildProductionActions(BuildContext context) {
    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    return [
      _DashboardActionTile(
        icon: Icons.qr_code_scanner,
        title: 'Skeniraj QR',
        subtitle: 'Nalog ili naljepnica s proizvodnog poda.',
        onTap: () => _openProductionQrScan(context),
      ),
      if (_canViewCard(ProductionDashboardCard.products))
        _DashboardActionTile(
          icon: Icons.inventory_2_outlined,
          title: 'Proizvodi',
          subtitle: 'Pregled i upravljanje proizvodima.',
          onTap: () => open(ProductsListScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.productionOrders))
        _DashboardActionTile(
          icon: Icons.assignment,
          title: 'Proizvodni nalozi',
          subtitle: 'Lista naloga, detalji i statusi.',
          onTap: () =>
              open(ProductionOrdersListScreen(companyData: companyData)),
        ),
      _DashboardActionTile(
        icon: Icons.receipt_long_outlined,
        title: 'Narudžbe',
        subtitle: 'Pregled i rad s narudžbama.',
        onTap: () => open(OrdersListScreen(companyData: companyData)),
      ),
      _DashboardActionTile(
        icon: Icons.groups_outlined,
        title: 'Kupci / dobavljači',
        subtitle: 'Partneri i poslovne veze.',
        onTap: () => open(PartnersScreen(companyData: companyData)),
      ),
      if (_canViewCard(ProductionDashboardCard.carbonFootprint))
        _DashboardActionTile(
          icon: Icons.eco_outlined,
          title: 'Karbonski otisak',
          subtitle: 'Praćenje i evidencija utjecaja.',
          onTap: () => open(CarbonFootprintScreen(companyData: companyData)),
        ),
      if (_canViewCard(ProductionDashboardCard.productionTracking))
        _DashboardActionTile(
          icon: Icons.play_circle_outline,
          title: 'Praćenje proizvodnje',
          subtitle: 'Nalozi u tijeku i aktivnosti.',
          onTap: () => open(
            ProductionOrdersListScreen(
              companyData: companyData,
              initialStatusFilter: ProductionOrderStatusFilter.inProgress,
            ),
          ),
        ),
      if (_canViewCard(ProductionDashboardCard.workCenters))
        _DashboardActionTile(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Radni centri',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canViewCard(ProductionDashboardCard.shifts))
        _DashboardActionTile(
          icon: Icons.schedule,
          title: 'Smjene',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canViewCard(ProductionDashboardCard.downtime))
        _DashboardActionTile(
          icon: Icons.warning_amber_outlined,
          title: 'Zastoji',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canViewCard(ProductionDashboardCard.problemReporting))
        _DashboardActionTile(
          icon: Icons.report_problem_outlined,
          title: 'Prijava problema',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canViewCard(ProductionDashboardCard.processExecution))
        _DashboardActionTile(
          icon: Icons.science_outlined,
          title: 'Evidencija procesa',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
      if (_canShowReportsCard())
        _DashboardActionTile(
          icon: Icons.assessment_outlined,
          title: 'Izvještaji',
          subtitle: 'Uskoro u aplikaciji.',
          onTap: () => _notImplemented(context),
        ),
    ];
  }

  List<Widget> _withTileGaps(List<Widget> tiles) {
    if (tiles.isEmpty) return const [];
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) out.add(const SizedBox(height: _tileGap));
      out.add(tiles[i]);
    }
    return out;
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

    final productionTiles = _buildProductionActions(context);

    final gap = kIsWeb ? 12.0 : 16.0;
    final pad = kIsWeb ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proizvodnja'),
        actions: [
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          _SessionHeaderCard(
            logoCandidates:
                CompanyLogoResolver.resolveLogoImageCandidates(companyData),
            roleLabel: _prettyRoleLabel(_role),
            companyId: _companyId,
            plantKey: _plantKey,
            companyLine: _companyDisplayName,
          ),
          SizedBox(height: gap),
          if (showAdminSection) ...[
            const _SectionTitle(title: 'Administracija'),
            SizedBox(height: gap * 0.75),
            _DashboardActionTile(
              icon: Icons.person_add_alt_1,
              title: 'Registracije',
              subtitle: 'Odobri nove korisnike (pending).',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PendingUsersScreen(),
                  ),
                );
              },
            ),
            SizedBox(height: gap * 1.5),
          ],
          if (showProductionModule && productionTiles.isNotEmpty) ...[
            const _SectionTitle(title: 'Proizvodnja'),
            SizedBox(height: gap * 0.75),
            ..._withTileGaps(productionTiles),
          ],
          if (!showProductionModule || productionTiles.isEmpty)
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

/// Gornji blok: logo (iz `companies.websiteUrl` → favicon, ili izravni `logoUrl`), uloga, pogon, kompanija.
class _SessionHeaderCard extends StatelessWidget {
  final List<String> logoCandidates;
  final String roleLabel;
  final String companyId;
  final String plantKey;
  final String companyLine;

  const _SessionHeaderCard({
    required this.logoCandidates,
    required this.roleLabel,
    required this.companyId,
    required this.plantKey,
    required this.companyLine,
  });

  Widget _plantLine() {
    if (plantKey.trim().isEmpty) {
      return const Text(
        'Pogon: -',
        style: TextStyle(color: Colors.black87),
      );
    }
    if (companyId.trim().isEmpty) {
      return Text(
        'Pogon: $plantKey',
        style: const TextStyle(color: Colors.black87),
      );
    }
    return FutureBuilder<String>(
      key: ValueKey('plant|$companyId|$plantKey'),
      future: CompanyPlantDisplayName.resolve(
        companyId: companyId,
        plantKey: plantKey,
      ),
      builder: (context, snap) {
        final label = snap.connectionState == ConnectionState.waiting
            ? '…'
            : (snap.data ?? plantKey);
        return Text(
          'Pogon: $label',
          style: const TextStyle(color: Colors.black87),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompanyHeaderLogo(candidates: logoCandidates),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uloga: $roleLabel',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _plantLine(),
                  const SizedBox(height: 2),
                  Text(
                    'Kompanija: $companyLine',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyHeaderLogo extends StatefulWidget {
  final List<String> candidates;
  static const double size = 56;

  const _CompanyHeaderLogo({required this.candidates});

  @override
  State<_CompanyHeaderLogo> createState() => _CompanyHeaderLogoState();
}

class _CompanyHeaderLogoState extends State<_CompanyHeaderLogo> {
  int _candidateIndex = 0;

  @override
  void didUpdateWidget(covariant _CompanyHeaderLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidates != widget.candidates) {
      _candidateIndex = 0;
    }
  }

  void _tryNextCandidate() {
    if (!mounted) return;
    if (_candidateIndex + 1 < widget.candidates.length) {
      setState(() => _candidateIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
    );
    final radius = BorderRadius.circular(12);

    Widget placeholder() {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.apartment_outlined,
            size: 30,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final urls = widget.candidates;
    if (urls.isEmpty) {
      return SizedBox(
        width: _CompanyHeaderLogo.size,
        height: _CompanyHeaderLogo.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: border,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: placeholder(),
          ),
        ),
      );
    }

    final safeIndex = _candidateIndex.clamp(0, urls.length - 1);
    final u = urls[safeIndex].trim();

    return SizedBox(
      width: _CompanyHeaderLogo.size,
      height: _CompanyHeaderLogo.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.network(
            u,
            key: ValueKey<String>(u),
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              if (_candidateIndex < widget.candidates.length - 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _tryNextCandidate();
                });
              }
              return placeholder();
            },
          ),
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

/// Kartica prečice kao maintenance [_HomeDashboardScreenState._actionButton].
class _DashboardActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
