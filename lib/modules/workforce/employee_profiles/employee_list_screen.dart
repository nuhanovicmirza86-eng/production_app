import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../models/workforce_employee.dart';
import 'employee_edit_screen.dart';
import 'workforce_employee_qr_scan_screen.dart';

/// Lista radnika. Admin / super admin u kompaniji: pregled svih pogona, filtar pogona,
/// novi radnik dobiva odabrani pogon (vidi i [EmployeeEditScreen]).
class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<({String plantKey, String label})> _plants = [];
  bool _plantsLoading = true;

  /// `null` = svi pogoni (samo globalni admin). Inače filtar po [plantKey].
  String? _filterPlantKey;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _sessionPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _globalTenantAdmin =>
      ProductionAccessHelper.isAdminRole(_role) ||
      ProductionAccessHelper.isSuperAdminRole(_role);

  bool get _canManage => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.shifts,
      );

  Map<String, dynamic> _effectiveCompanyData() {
    final m = Map<String, dynamic>.from(widget.companyData);
    final pk = _filterPlantKey ?? _sessionPlantKey;
    if (pk.isNotEmpty) {
      m['plantKey'] = pk;
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    _initPlants();
  }

  Future<void> _initPlants() async {
    if (!_globalTenantAdmin) {
      _filterPlantKey = _sessionPlantKey;
      if (mounted) setState(() => _plantsLoading = false);
      return;
    }

    final list = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _companyId,
    );
    if (!mounted) return;
    setState(() {
      _plants = list;
      _plantsLoading = false;
      // Zadano: svi pogoni; korisnik može suziti filtar.
      _filterPlantKey = null;
    });
  }

  Query<Map<String, dynamic>> _query() {
    final col = FirebaseFirestore.instance.collection('workforce_employees');
    if (_globalTenantAdmin && _filterPlantKey == null) {
      return col
          .where('companyId', isEqualTo: _companyId)
          .orderBy('displayName')
          .limit(500);
    }
    final pk = _filterPlantKey ?? _sessionPlantKey;
    return col
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: pk)
        .orderBy('displayName')
        .limit(200);
  }

  String _plantSubtitle(WorkforceEmployee e) {
    if (!_globalTenantAdmin) return '';
    final key = e.plantKey.trim();
    if (key.isEmpty) return '';
    for (final p in _plants) {
      if (p.plantKey == key) return p.label;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    if (_plantsLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operativni profil radnika')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_globalTenantAdmin && _plants.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operativni profil radnika')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'U kompaniji nema pogona (company_plants). Dodaj pogon prije evidencije radnika.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final q = _query();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operativni profil radnika'),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'Skeniraj bedž radnika',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => WorkforceEmployeeQrScanScreen(
                      companyData: _effectiveCompanyData(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => EmployeeEditScreen(
                      companyData: _effectiveCompanyData(),
                      existing: null,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_globalTenantAdmin) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_filterPlantKey),
                initialValue: _filterPlantKey,
                decoration: const InputDecoration(
                  labelText: 'Pogon (filtar liste)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Svi pogoni'),
                  ),
                  ..._plants.map(
                    (p) => DropdownMenuItem<String?>(
                      value: p.plantKey,
                      child: Text(p.label),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _filterPlantKey = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Kao Admin vidiš radnike u cijeloj kompaniji. Za novog radnika koristi filtar pogona '
                '(ili odabir u formi) da ga vežeš na ispravan pogon.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Greška: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _canManage
                          ? 'Nema radnika za ovaj prikaz. Dodaj prvog (+).'
                          : 'Nema evidentiranih radnika u pogonu.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = WorkforceEmployee.fromDoc(docs[i]);
                    final plantLine = _plantSubtitle(e);
                    return ListTile(
                      title: Text(
                        e.displayName.isEmpty ? e.catalogCode : e.displayName,
                      ),
                      subtitle: Text(
                        plantLine.isEmpty
                            ? '${e.catalogCode} · ${e.active ? 'aktivan' : 'neaktivan'}'
                            : '${e.catalogCode} · $plantLine · ${e.active ? 'aktivan' : 'neaktivan'}',
                      ),
                      trailing: e.active
                          ? const Icon(Icons.circle,
                              color: Colors.green, size: 12)
                          : const Icon(Icons.circle_outlined, size: 12),
                      onTap: _canManage
                          ? () async {
                              final merged = Map<String, dynamic>.from(
                                widget.companyData,
                              )..['plantKey'] = e.plantKey;
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => EmployeeEditScreen(
                                    companyData: merged,
                                    existing: e,
                                  ),
                                ),
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
