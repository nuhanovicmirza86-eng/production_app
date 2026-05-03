import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../utils/development_module_permissions_catalog.dart';

/// Referentni pregled dozvola modula Razvoj po ulogama (izdvojeni ekran, ograničen pristup).
class DevelopmentRolesPermissionsScreen extends StatelessWidget {
  const DevelopmentRolesPermissionsScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    if (!ProductionAccessHelper.isSuperAdminEffectiveSession(companyData)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Razvoj — matrica dozvola')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Ovaj referentni pregled nije dio tvoje trenutačne sesije.'),
          ),
        ),
      );
    }

    final roles = ProductionAccessHelper.allMatrixRolesSorted();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Razvoj — matrica dozvola'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Informativni pregled iz istih pravila kao UI i Cloud Functions. '
            'Entitlementi u company dokumentu ove sesije utječu na redove ovisne o pretplati (npr. AI).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ...roles.map((roleCode) {
            final label = ProductionAccessHelper.displayRoleLabel(roleCode);
            final codeLine = roleCode.isEmpty ? '' : ' (${ProductionAccessHelper.normalizeRole(roleCode)})';
            final rows = DevelopmentModulePermissionsCatalog.rowsForRole(
              roleCode: roleCode,
              companyData: companyData,
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded:
                    roleCode == ProductionAccessHelper.roleSuperAdmin ||
                        roleCode == ProductionAccessHelper.roleAdmin,
                title: Text(
                  '$label$codeLine',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                children: [
                  for (final row in rows)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        row.allowed ? Icons.check_circle : Icons.cancel_outlined,
                        color: row.allowed
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        size: 22,
                      ),
                      title: Text(row.capability),
                      subtitle: Text(row.where),
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
