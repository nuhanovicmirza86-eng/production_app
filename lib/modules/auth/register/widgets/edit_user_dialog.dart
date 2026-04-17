import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';

class EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String companyId;

  const EditUserDialog({
    super.key,
    required this.userData,
    required this.companyId,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static const List<String> _productionRoles = <String>[
    'production_operator',
    'quality_operator',
    'logistics_operator',
    'logistics_manager',
    'shift_lead',
    'production_manager',
  ];

  static const List<String> _allowedStatuses = <String>['active', 'inactive'];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _selectedRole = 'production_operator';
  String _selectedStatus = 'active';
  String _selectedPlantKey = '';

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _plants =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  String _s(dynamic v) => (v ?? '').toString().trim();

  int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  String _roleLabel(String role) {
    final r = ProductionAccessHelper.normalizeRole(role);
    switch (r) {
      case 'admin':
        return 'Admin';
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
      default:
        return role;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktivan';
      case 'inactive':
        return 'Neaktivan';
      default:
        return status;
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

  Future<void> _loadInitialState() async {
    try {
      final currentRole = _s(widget.userData['role']).toLowerCase();
      final currentStatus = _s(widget.userData['status']).toLowerCase();
      final currentPlantKey = _s(widget.userData['plantKey']);

      final query = await _db
          .collection('company_plants')
          .where('active', isEqualTo: true)
          .where('companyId', isEqualTo: widget.companyId)
          .get();

      final docs = [...query.docs];
      docs.sort((a, b) {
        final ao = _i(a.data()['order']);
        final bo = _i(b.data()['order']);
        if (ao != bo) return ao.compareTo(bo);

        final al = _plantLabel(a.data(), a.id).toLowerCase();
        final bl = _plantLabel(b.data(), b.id).toLowerCase();
        return al.compareTo(bl);
      });

      if (!mounted) return;
      setState(() {
        _plants = docs;
        _selectedRole = _productionRoles.contains(currentRole)
            ? currentRole
            : 'production_operator';
        _selectedStatus = _allowedStatuses.contains(currentStatus)
            ? currentStatus
            : 'active';

        final hasCurrentPlant = docs.any((doc) {
          final data = doc.data();
          final plantKey = _s(data['plantKey']).isNotEmpty
              ? _s(data['plantKey'])
              : doc.id;
          return plantKey == currentPlantKey;
        });

        if (hasCurrentPlant) {
          _selectedPlantKey = currentPlantKey;
        } else if (docs.isNotEmpty) {
          final first = docs.first;
          _selectedPlantKey = _s(first.data()['plantKey']).isNotEmpty
              ? _s(first.data()['plantKey'])
              : first.id;
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Greška pri učitavanju pogona: $e';
        _loading = false;
      });
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _findSelectedPlant() {
    for (final doc in _plants) {
      final data = doc.data();
      final plantKey = _s(data['plantKey']).isNotEmpty
          ? _s(data['plantKey'])
          : doc.id;
      if (plantKey == _selectedPlantKey) return doc;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_productionRoles.contains(_selectedRole)) {
      setState(() {
        _error = 'Odaberi validnu production ulogu.';
      });
      return;
    }

    if (!_allowedStatuses.contains(_selectedStatus)) {
      setState(() {
        _error = 'Odaberi validan status.';
      });
      return;
    }

    final selectedPlantDoc = _findSelectedPlant();
    if (selectedPlantDoc == null) {
      setState(() {
        _error = 'Odaberi validan pogon.';
      });
      return;
    }

    final uid = _s(widget.userData['uid']);
    if (uid.isEmpty) {
      setState(() {
        _error = 'Nedostaje UID korisnika.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final callable = _functions.httpsCallable('updateUserAccessAssignment');
      final result = await callable.call(<String, dynamic>{
        'companyId': widget.companyId,
        'targetUid': uid,
        'selectedRole': _selectedRole,
        'selectedStatus': _selectedStatus,
        'companyPlantDocId': selectedPlantDoc.id,
      });
      final raw = result.data;
      if (raw is! Map || raw['success'] != true) {
        throw StateError('Neuspjelo spremanje.');
      }

      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Greška (${e.code}).';
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Greška pri spremanju izmjena: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _s(widget.userData['displayName']).isNotEmpty
        ? _s(widget.userData['displayName'])
        : _s(widget.userData['fullName']).isNotEmpty
        ? _s(widget.userData['fullName'])
        : _s(widget.userData['email']);

    return AlertDialog(
      title: const Text('Uredi korisnika'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isEmpty ? 'Korisnik' : displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _s(widget.userData['email']).isEmpty
                          ? '-'
                          : _s(widget.userData['email']),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Production uloga',
                      ),
                      items: _productionRoles
                          .map(
                            (role) => DropdownMenuItem<String>(
                              value: role,
                              child: Text(_roleLabel(role)),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _selectedRole = (value ?? 'production_operator')
                                    .trim();
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPlantKey.isEmpty
                          ? null
                          : _selectedPlantKey,
                      decoration: const InputDecoration(labelText: 'Pogon'),
                      items: _plants.map((p) {
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
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _selectedPlantKey = (value ?? '').trim();
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: _allowedStatuses
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _selectedStatus = (value ?? 'active').trim();
                              });
                            },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: (_saving || _loading) ? null : _save,
          child: Text(_saving ? 'Spremam...' : 'Sačuvaj'),
        ),
      ],
    );
  }
}
