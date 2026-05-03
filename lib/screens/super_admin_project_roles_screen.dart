import 'package:flutter/material.dart';

import '../core/access/production_access_helper.dart';
import '../core/access/production_app_roles_catalog.dart';
import '../modules/development/screens/development_roles_permissions_screen.dart';

/// Referentni pregled **svih** kanonskih uloga Production aplikacije i matrice kartica.
/// Samo [super_admin] sesija (isti kriterij kao [DevelopmentRolesPermissionsScreen]).
class SuperAdminProjectRolesScreen extends StatelessWidget {
  const SuperAdminProjectRolesScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    if (!ProductionAccessHelper.isSuperAdminFromCompanySession(companyData)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uloge u aplikaciji')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Ovaj pregled je dostupan samo u super admin sesiji.'),
          ),
        ),
      );
    }

    final roles = ProductionAccessHelper.allMatrixRolesSorted();
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uloge i matrica aplikacije'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DevelopmentRolesPermissionsScreen(
                    companyData: companyData,
                  ),
                ),
              );
            },
            child: const Text('Razvoj — detalj'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Kanonske uloge iz ProductionAccessHelper (ista matrica kao kartice na Početnoj). '
            'Pretplata kompanije (moduli) i dalje filtrira što korisnik u praksi vidi.',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 16),
          ...roles.map((roleCode) {
            final label = ProductionAccessHelper.displayRoleLabel(roleCode);
            final norm = ProductionAccessHelper.normalizeRole(roleCode);
            final codeLine = norm.isEmpty ? '' : ' · $norm';
            final brief = ProductionAppRolesCatalog.briefForRole(roleCode);
            final rows = ProductionAppRolesCatalog.capabilitiesForRole(roleCode);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded:
                    norm == ProductionAccessHelper.roleSuperAdmin ||
                        norm == ProductionAccessHelper.roleAdmin,
                title: Text(
                  '$label$codeLine',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    brief,
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
                children: [
                  for (final rowArea in rows)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        rowArea.level == ProductionAccessLevel.manage
                            ? Icons.edit_note_outlined
                            : rowArea.level == ProductionAccessLevel.view
                                ? Icons.visibility_outlined
                                : Icons.block_outlined,
                        size: 22,
                        color: rowArea.level == ProductionAccessLevel.manage
                            ? scheme.primary
                            : rowArea.level == ProductionAccessLevel.view
                                ? scheme.tertiary
                                : scheme.outline,
                      ),
                      title: Text(rowArea.area),
                      subtitle: Text(
                        ProductionAppRolesCatalog.levelDescription(rowArea.level),
                        style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
