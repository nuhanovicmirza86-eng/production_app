import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../widgets/edit_user_dialog.dart';

class PendingUsersScreen extends StatefulWidget {
  const PendingUsersScreen({super.key});

  @override
  State<PendingUsersScreen> createState() => _PendingUsersScreenState();
}

class _PendingUsersScreenState extends State<PendingUsersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  bool _loadingMe = true;
  String? _error;

  String _myRole = '';
  String _myCompanyId = '';
  String _usersStatusFilter = 'all';
  /// 'all' ili kanonski kod uloge (npr. [admin], [production_operator]).
  String _roleFilter = 'all';

  /// Prošireni redovi u listi korisnika (ključ = uid ili email).
  final Set<String> _expandedUserCardKeys = <String>{};

  final Set<String> _busyIds = <String>{};
  final Set<String> _loadingPlantsFor = <String>{};

  final Map<String, String> _selectedRolesByRequestId = <String, String>{};
  final Map<String, String> _selectedPlantKeysByRequestId = <String, String>{};
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _plantsByRequestId =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

  static const List<String> _productionRoles = <String>[
    'production_operator',
    'quality_operator',
    'logistics_operator',
    'logistics_manager',
    'shift_lead',
    'production_manager',
  ];

  static const List<String> _userStatusFilters = <String>[
    'all',
    'active',
    'inactive',
  ];

  /// Redoslijed grupiranja u listi; nepoznate uloge dolaze na kraju abecedno.
  static const List<String> _rolesDisplayOrder = <String>[
    ProductionAccessHelper.roleSuperAdmin,
    ProductionAccessHelper.roleAdmin,
    ProductionAccessHelper.roleProductionManager,
    ProductionAccessHelper.roleSupervisor,
    ProductionAccessHelper.roleLogisticsManager,
    'shift_lead',
    'quality_operator',
    ProductionAccessHelper.roleProductionOperator,
    'logistics_operator',
    ProductionAccessHelper.roleMaintenanceManager,
  ];

  bool get _isAdmin => ProductionAccessHelper.isAdminRole(_myRole);

  String _s(dynamic v) => (v ?? '').toString().trim();

  int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Nisi prijavljen.';
          _loadingMe = false;
        });
        return;
      }

      final meSnap = await _db.collection('users').doc(currentUser.uid).get();
      final meData = meSnap.data() ?? <String, dynamic>{};

      setState(() {
        _myRole = ProductionAccessHelper.normalizeRole(meData['role']);
        _myCompanyId = _s(meData['companyId']);
        _loadingMe = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Greška pri učitavanju admin konteksta: $e';
        _loadingMe = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _roleLabel(String role) {
    final r = ProductionAccessHelper.normalizeRole(role);
    switch (r) {
      case 'admin':
        return 'Admin';
      case 'super_admin':
        return 'Super admin';
      case 'supervisor':
        return 'Supervizor';
      case 'production_operator':
        return 'Operater proizvodnje';
      case 'quality_operator':
        return 'Operater kvaliteta';
      case 'logistics_operator':
        return 'Operater logistike';
      case 'logistics_manager':
        return 'Menadžer logistike';
      case 'shift_lead':
        return 'Vođa smjene';
      case 'production_manager':
        return 'Menadžer proizvodnje';
      case 'maintenance_manager':
        return 'Menadžer održavanja';
      default:
        return role.isEmpty ? '—' : role;
    }
  }

  String _roleFilterDropdownLabel(String value) {
    if (value == 'all') return 'Sve uloge';
    return _roleLabel(value);
  }

  List<String> _rolesForSections(Iterable<String> normalizedRoles) {
    final present = normalizedRoles.toSet();
    final out = <String>[];
    for (final r in _rolesDisplayOrder) {
      if (present.contains(r)) out.add(r);
    }
    final rest = present.difference(out.toSet()).toList()..sort();
    out.addAll(rest);
    return out;
  }

  String _statusFilterLabel(String status) {
    switch (status) {
      case 'all':
        return 'Svi';
      case 'active':
        return 'Aktivni';
      case 'inactive':
        return 'Neaktivni';
      default:
        return status;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktivan';
      case 'inactive':
        return 'Neaktivan';
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  String _plantLabel(Map<String, dynamic> data, String fallbackKey) {
    final displayName = _s(data['displayName']);
    final defaultName = _s(data['defaultName']);
    final plantCode = _s(data['plantCode']);
    final plantKey = _s(data['plantKey']);

    final base = displayName.isNotEmpty
        ? displayName
        : defaultName.isNotEmpty
        ? defaultName
        : plantKey.isNotEmpty
        ? plantKey
        : fallbackKey;

    if (plantCode.isNotEmpty) return '$base ($plantCode)';
    return base;
  }

  String _requestDisplayName(Map<String, dynamic> d) {
    final fullName = _s(d['fullName']);
    if (fullName.isNotEmpty) return fullName;

    final displayName = _s(d['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final email = _s(d['email']);
    if (email.isNotEmpty) return email;

    return 'Korisnik';
  }

  String _userDisplayName(Map<String, dynamic> d) {
    final displayName = _s(d['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final fullName = _s(d['fullName']);
    if (fullName.isNotEmpty) return fullName;

    final name = _s(d['name']);
    if (name.isNotEmpty) return name;

    final email = _s(d['email']);
    if (email.isNotEmpty) return email;

    return 'Korisnik';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  Query<Map<String, dynamic>> _pendingRequestsQuery() {
    Query<Map<String, dynamic>> query = _db
        .collection('registration_requests')
        .where('requestedApp', isEqualTo: 'production')
        .where('status', isEqualTo: 'pending');

    if (_myCompanyId.isNotEmpty) {
      query = query.where('companyId', isEqualTo: _myCompanyId);
    }

    return query.orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _productionUsersQuery() {
    Query<Map<String, dynamic>> query = _db.collection('users');

    if (_myCompanyId.isNotEmpty) {
      query = query.where('companyId', isEqualTo: _myCompanyId);
    }

    return query.orderBy('displayName');
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadCompanyPlants(
    String companyId,
  ) async {
    Query<Map<String, dynamic>> query = _db
        .collection('company_plants')
        .where('active', isEqualTo: true)
        .where('companyId', isEqualTo: companyId);

    final snap = await query.get();
    final docs = [...snap.docs];

    docs.sort((a, b) {
      final ao = _i(a.data()['order']);
      final bo = _i(b.data()['order']);
      if (ao != bo) return ao.compareTo(bo);

      final al = _plantLabel(a.data(), a.id).toLowerCase();
      final bl = _plantLabel(b.data(), b.id).toLowerCase();
      return al.compareTo(bl);
    });

    return docs;
  }

  Future<void> _ensurePlantsLoadedForRequest(
    DocumentSnapshot<Map<String, dynamic>> requestDoc,
  ) async {
    final requestId = requestDoc.id;
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    final companyId = _s(requestData['companyId']);

    if (companyId.isEmpty) return;
    if (_plantsByRequestId.containsKey(requestId) ||
        _loadingPlantsFor.contains(requestId)) {
      return;
    }

    setState(() {
      _loadingPlantsFor.add(requestId);
    });

    try {
      final plants = await _loadCompanyPlants(companyId);

      if (!mounted) return;
      setState(() {
        _plantsByRequestId[requestId] = plants;
        _selectedRolesByRequestId.putIfAbsent(
          requestId,
          () => 'production_operator',
        );
      });
    } catch (e) {
      _snack('Greška pri učitavanju pogona: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingPlantsFor.remove(requestId);
        });
      }
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _findPlantDocForRequest(
    String requestId,
  ) {
    final selectedPlantKey = _selectedPlantKeysByRequestId[requestId] ?? '';
    final plants = _plantsByRequestId[requestId] ?? const [];

    for (final p in plants) {
      final pd = p.data();
      final pk = _s(pd['plantKey']).isNotEmpty ? _s(pd['plantKey']) : p.id;
      if (pk == selectedPlantKey) return p;
    }

    return null;
  }

  Future<void> _approveRequest(
    DocumentSnapshot<Map<String, dynamic>> requestDoc,
  ) async {
    final requestId = requestDoc.id;
    if (_busyIds.contains(requestId)) return;

    final requestData = requestDoc.data() ?? <String, dynamic>{};
    final companyId = _s(requestData['companyId']);

    final uid = _s(requestData['uid']);
    if (uid.isEmpty) {
      _snack('Nedostaje UID u registration request.');
      return;
    }

    final selectedRole = _selectedRolesByRequestId[requestId] ?? '';
    if (!_productionRoles.contains(selectedRole)) {
      _snack('Odaberi validnu production ulogu.');
      return;
    }

    final selectedPlantDoc = _findPlantDocForRequest(requestId);
    if (selectedPlantDoc == null) {
      _snack('Odaberi pogon.');
      return;
    }

    setState(() {
      _busyIds.add(requestId);
    });

    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      if (!userSnap.exists) {
        _snack('Korisnik ne postoji.');
        return;
      }

      final callable = _functions.httpsCallable('approveProductionUser');
      final result = await callable.call(<String, dynamic>{
        'requestId': requestId,
        'companyId': companyId,
        'targetUid': uid,
        'selectedRole': selectedRole,
        'companyPlantDocId': selectedPlantDoc.id,
      });
      final raw = result.data;
      if (raw is! Map || raw['success'] != true) {
        throw StateError('Neuspjelo odobrenje.');
      }

      _snack('Korisnik je odobren i aktiviran za Production.');
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Greška pri odobrenju (${e.code}).');
    } catch (e) {
      _snack('Greška pri odobrenju: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _rejectRequest(
    DocumentSnapshot<Map<String, dynamic>> requestDoc,
  ) async {
    final requestId = requestDoc.id;
    if (_busyIds.contains(requestId)) return;

    final requestData = requestDoc.data() ?? <String, dynamic>{};
    final email = _s(requestData['email']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Odbij zahtjev'),
        content: Text(
          'Da li sigurno želiš odbiti zahtjev korisnika ${email.isEmpty ? requestId : email}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Da, odbij'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _busyIds.add(requestId);
    });

    final companyId = _s(requestData['companyId']);

    try {
      final callable = _functions.httpsCallable('rejectProductionUser');
      final result = await callable.call(<String, dynamic>{
        'requestId': requestId,
        'companyId': companyId,
      });
      final raw = result.data;
      if (raw is! Map || raw['success'] != true) {
        throw StateError('Neuspjelo odbijanje.');
      }

      _snack('Zahtjev je odbijen.');
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Greška pri odbijanju (${e.code}).');
    } catch (e) {
      _snack('Greška pri odbijanju: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> userData) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          EditUserDialog(userData: userData, companyId: _myCompanyId),
    );

    if (changed == true && mounted) {
      _snack('Korisnik je uspješno ažuriran.');
    }
  }

  Widget _requestCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final requestId = doc.id;
    final busy = _busyIds.contains(requestId);
    final loadingPlants = _loadingPlantsFor.contains(requestId);

    final email = _s(d['email']);
    final companyId = _s(d['companyId']);
    final companyName = _s(d['companyName']);
    final companyCode = _s(d['companyCode']);
    final workEmail = _s(d['workEmail']);
    final createdAt = _ts(d['createdAt']);

    final plants = _plantsByRequestId[requestId] ?? const [];
    final selectedRole =
        _selectedRolesByRequestId[requestId] ?? 'production_operator';
    final selectedPlantKey = _selectedPlantKeysByRequestId[requestId] ?? '';

    final canApprove =
        !busy &&
        !loadingPlants &&
        _productionRoles.contains(selectedRole) &&
        selectedPlantKey.trim().isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePlantsLoadedForRequest(doc);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _requestDisplayName(d),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(email.isEmpty ? '-' : email),
            if (workEmail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Poslovni email: $workEmail'),
            ],
            const SizedBox(height: 4),
            Text(
              companyName.isEmpty
                  ? (companyCode.isEmpty
                        ? 'Kompanija: -'
                        : 'Kompanija: $companyCode')
                  : (companyCode.isEmpty
                        ? 'Kompanija: $companyName'
                        : 'Kompanija: $companyName ($companyCode)'),
            ),
            const SizedBox(height: 4),
            Text('CompanyId: ${companyId.isEmpty ? '-' : companyId}'),
            const SizedBox(height: 4),
            Text('Zahtjev kreiran: ${_formatDateTime(createdAt)}'),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: const InputDecoration(labelText: 'Production uloga'),
              items: _productionRoles
                  .map(
                    (role) => DropdownMenuItem<String>(
                      value: role,
                      child: Text(_roleLabel(role)),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() {
                        _selectedRolesByRequestId[requestId] =
                            (value ?? 'production_operator').trim();
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedPlantKey.isEmpty ? null : selectedPlantKey,
              decoration: InputDecoration(
                labelText: loadingPlants ? 'Učitavam pogone...' : 'Pogon',
              ),
              items: plants.map((p) {
                final pd = p.data();
                final pk = _s(pd['plantKey']).isNotEmpty
                    ? _s(pd['plantKey'])
                    : p.id;
                return DropdownMenuItem<String>(
                  value: pk,
                  child: Text(
                    _plantLabel(pd, pk),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (busy || loadingPlants || plants.isEmpty)
                  ? null
                  : (value) {
                      setState(() {
                        _selectedPlantKeysByRequestId[requestId] = (value ?? '')
                            .trim();
                      });
                    },
            ),
            const SizedBox(height: 10),
            const Text(
              'Admin mora odabrati production ulogu i pogon prije odobrenja korisnika.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canApprove ? () => _approveRequest(doc) : null,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified),
                    label: const Text('Odobri'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _rejectRequest(doc),
                    icon: const Icon(Icons.close),
                    label: const Text('Odbij'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingRequestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingRequestsQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Greška: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text('Nema novih zahtjeva za registraciju.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _requestCard(docs[index]),
        );
      },
    );
  }

  Widget _roleSection(String role, List<Map<String, dynamic>> users) {
    if (users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_roleLabel(role)} (${users.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final u in users) ...[
          _registeredUserCard(u),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  String _userCardKey(Map<String, dynamic> data) {
    final u = _s(data['uid']);
    if (u.isNotEmpty) return u;
    final e = _s(data['email']);
    if (e.isNotEmpty) return e;
    return _userDisplayName(data);
  }

  Widget _registeredUserCard(Map<String, dynamic> data) {
    final cardKey = _userCardKey(data);
    final expanded = _expandedUserCardKeys.contains(cardKey);
    final displayName = _userDisplayName(data);
    final email = _s(data['email']);
    final workEmail = _s(data['workEmail']);
    final plantKey = _s(data['plantKey']);
    final status = _s(data['status']).toLowerCase();
    final approvedAt = _ts(data['approvedAt']);
    final isActive = status == 'active';
    final roleLabel = _roleLabel(
      ProductionAccessHelper.normalizeRole(data['role']),
    );

    final borderColor = isActive ? Colors.green.shade600 : Colors.black12;
    final bgColor = isActive ? Colors.green.shade50 : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: isActive ? 1.5 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_expandedUserCardKeys.contains(cardKey)) {
                _expandedUserCardKeys.remove(cardKey);
              } else {
                _expandedUserCardKeys.add(cardKey);
              }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: expanded ? 12 : 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isActive)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.shade700,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Aktivan',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!expanded) ...[
                  const SizedBox(height: 2),
                  Text(
                    email.isEmpty ? '—' : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
                if (expanded) ...[
                  const SizedBox(height: 8),
                  Text(email.isEmpty ? '-' : email),
                  if (workEmail.isNotEmpty && workEmail != email) ...[
                    const SizedBox(height: 4),
                    Text('Poslovni email: $workEmail'),
                  ],
                  const SizedBox(height: 4),
                  Text('Rola: $roleLabel'),
                  const SizedBox(height: 4),
                  Text('Pogon: ${plantKey.isEmpty ? '-' : plantKey}'),
                  const SizedBox(height: 4),
                  Text('Status: ${_statusLabel(status)}'),
                  const SizedBox(height: 4),
                  Text('Odobren: ${_formatDateTime(approvedAt)}'),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _openEditUserDialog(data),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Uredi'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _usersByRoleTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productionUsersQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Greška: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;

        final companyUsers = allDocs.where((doc) {
          final data = doc.data();
          final status = _s(data['status']).toLowerCase();

          if (_usersStatusFilter == 'all') {
            return true;
          }

          return status == _usersStatusFilter;
        }).toList();

        final filtered = companyUsers.where((doc) {
          if (_roleFilter == 'all') return true;
          final data = doc.data();
          final nr = ProductionAccessHelper.normalizeRole(data['role']);
          return nr ==
              ProductionAccessHelper.normalizeRole(_roleFilter);
        });

        final List<Map<String, dynamic>> productionUsers = filtered
            .map(
              (doc) => <String, dynamic>{
                ...doc.data(),
                'uid': doc.id,
              },
            )
            .toList();

        final Map<String, List<Map<String, dynamic>>> grouped =
            <String, List<Map<String, dynamic>>>{};

        for (final user in productionUsers) {
          final normalizedRole = ProductionAccessHelper.normalizeRole(
            user['role'],
          );
          grouped
              .putIfAbsent(normalizedRole, () => <Map<String, dynamic>>[])
              .add(user);
        }

        final sectionRoles = _rolesForSections(grouped.keys);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Korisnici u kompaniji',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('status_$_usersStatusFilter'),
                    initialValue: _usersStatusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status naloga',
                      isDense: true,
                    ),
                    items: _userStatusFilters
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(_statusFilterLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _usersStatusFilter = (value ?? 'all').trim();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('role_$_roleFilter'),
                    initialValue: _roleFilter,
                    decoration: const InputDecoration(
                      labelText: 'Uloga',
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'all',
                        child: Text(_roleFilterDropdownLabel('all')),
                      ),
                      for (final role in _rolesDisplayOrder)
                        DropdownMenuItem<String>(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _roleFilter = (value ?? 'all').trim();
                        if (_roleFilter.isEmpty) _roleFilter = 'all';
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Klikni na red za detalje i „Uredi“. Aktivni: zeleno.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: productionUsers.isEmpty
                  ? const Center(
                      child: Text(
                        'Nema korisnika za odabrane filtere.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      children: [
                        for (final role in sectionRoles)
                          if ((grouped[role] ?? const <Map<String, dynamic>>[])
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _roleSection(role, grouped[role]!),
                            ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMe) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registracije')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registracije')),
        body: Center(child: Text(_error!)),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registracije')),
        body: const Center(
          child: Text('Samo admin može upravljati registracijama korisnika.'),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registracije'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Novi zahtjevi'),
              Tab(text: 'Korisnici kompanije'),
            ],
          ),
        ),
        body: TabBarView(children: [_pendingRequestsTab(), _usersByRoleTab()]),
      ),
    );
  }
}
