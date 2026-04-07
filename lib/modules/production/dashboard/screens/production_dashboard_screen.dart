import 'package:flutter/material.dart';

import '../../../auth/register/screens/pending_users_screen.dart';
import '../../production_orders/screens/production_orders_list_screen.dart';

class ProductionDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ProductionDashboardScreen({super.key, required this.companyData});

  String get _companyId => (companyData['companyId'] ?? '').toString();
  String get _plantKey => (companyData['plantKey'] ?? '').toString();
  String get _role => (companyData['role'] ?? '').toString().toLowerCase();

  List<String> get _enabledModules {
    final raw = companyData['enabledModules'];

    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }

    return const [];
  }

  bool _hasModule(String moduleKey) {
    if (_enabledModules.isEmpty) {
      return moduleKey == 'production';
    }

    return _enabledModules.contains(moduleKey);
  }

  bool get _isAdmin => _role == 'admin';

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proizvodnja')),
        body: const Center(child: Text('Nedostaje companyData')),
      );
    }

    final showProduction = _hasModule('production');
    final showQuality = _hasModule('quality');
    final showLogistics = _hasModule('logistics');

    return Scaffold(
      appBar: AppBar(title: const Text('Proizvodnja')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ContextCard(companyId: _companyId, plantKey: _plantKey),
          const SizedBox(height: 16),

          if (_isAdmin) ...[
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

          if (showProduction) ...[
            _SectionTitle(title: 'Proizvodnja'),
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
                  title: 'Proizvodni nalozi',
                  icon: Icons.assignment,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductionOrdersListScreen(
                          companyData: companyData,
                        ),
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  title: 'Praćenje proizvodnje',
                  icon: Icons.play_circle_outline,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Radni centri',
                  icon: Icons.precision_manufacturing_outlined,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Smjene',
                  icon: Icons.schedule,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Zastoji',
                  icon: Icons.warning_amber_outlined,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Proizvodi',
                  icon: Icons.inventory_2_outlined,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'BOM',
                  icon: Icons.account_tree_outlined,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Routing',
                  icon: Icons.alt_route,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (showQuality) ...[
            _SectionTitle(title: 'Kvalitet'),
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
                  title: 'Događaji kvaliteta',
                  icon: Icons.fact_check_outlined,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Zadržavanja kvaliteta',
                  icon: Icons.rule_folder_outlined,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (showLogistics) ...[
            _SectionTitle(title: 'Logistika'),
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
                  title: 'Lotovi zaliha',
                  icon: Icons.qr_code_2,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Kretanja zaliha',
                  icon: Icons.swap_horiz,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
                _DashboardCard(
                  title: 'Skladišta',
                  icon: Icons.warehouse_outlined,
                  onTap: () {
                    _notImplemented(context);
                  },
                ),
              ],
            ),
          ],

          if (!showProduction && !showQuality && !showLogistics)
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
