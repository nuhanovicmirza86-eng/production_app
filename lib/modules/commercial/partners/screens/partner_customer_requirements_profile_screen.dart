import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/customer_requirements_profile_model.dart';
import '../services/customers_service.dart';

/// Uređivanje `customer_requirements_profiles/{customerId}` (Callable + Firestore read).
class PartnerCustomerRequirementsProfileScreen extends StatefulWidget {
  const PartnerCustomerRequirementsProfileScreen({
    super.key,
    required this.companyData,
    required this.customerId,
    required this.customerDisplayName,
  });

  final Map<String, dynamic> companyData;
  final String customerId;
  final String customerDisplayName;

  @override
  State<PartnerCustomerRequirementsProfileScreen> createState() =>
      _PartnerCustomerRequirementsProfileScreenState();
}

class _PartnerCustomerRequirementsProfileScreenState
    extends State<PartnerCustomerRequirementsProfileScreen> {
  final _service = CustomersService();
  bool _saving = false;
  bool _loading = true;
  String? _error;

  late String _ppapLevel;
  late final TextEditingController _specialCtrl;
  late final TextEditingController _weeksCtrl;
  late final TextEditingController _packCtrl;
  late final TextEditingController _docCtrl;
  late final TextEditingController _reactionCtrl;
  late final TextEditingController _toleranceCtrl;
  late final TextEditingController _csrRefCtrl;

  final List<_ContactRow> _contacts = [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _ppapLevel = 'none';
    _specialCtrl = TextEditingController();
    _weeksCtrl = TextEditingController();
    _packCtrl = TextEditingController();
    _docCtrl = TextEditingController();
    _reactionCtrl = TextEditingController();
    _toleranceCtrl = TextEditingController();
    _csrRefCtrl = TextEditingController();
    _contacts.add(_ContactRow());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _service.getCustomerRequirementsProfile(
        companyId: _companyId,
        customerId: widget.customerId.trim(),
      );
      if (!mounted) return;
      _applyModel(m);
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppErrorMapper.toMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _specialCtrl.dispose();
    _weeksCtrl.dispose();
    _packCtrl.dispose();
    _docCtrl.dispose();
    _reactionCtrl.dispose();
    _toleranceCtrl.dispose();
    _csrRefCtrl.dispose();
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyModel(CustomerRequirementsProfileModel? m) {
    setState(() {
      _ppapLevel = m?.ppapLevel ?? 'none';
      _specialCtrl.text = m?.specialRequirements ?? '';
      _weeksCtrl.text =
          m?.changeNotificationWeeks != null ? '${m!.changeNotificationWeeks}' : '';
      _packCtrl.text = m?.packagingNotes ?? '';
      _docCtrl.text = m?.documentationRequirements ?? '';
      _reactionCtrl.text = m?.reactionPlanPolicy ?? '';
      _toleranceCtrl.text = m?.tolerancePolicy ?? '';
      _csrRefCtrl.text = m?.csrDocumentReference ?? '';
      for (final c in _contacts) {
        c.dispose();
      }
      _contacts.clear();
      final list = m?.communicationContacts ?? const <CustomerRequirementsContact>[];
      for (final c in list) {
        _contacts.add(
          _ContactRow(
            name: c.name,
            role: c.role,
            email: c.email,
            phone: c.phone,
          ),
        );
      }
      if (_contacts.isEmpty) {
        _contacts.add(_ContactRow());
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final weeksText = _weeksCtrl.text.trim();
      int? weeks;
      if (weeksText.isNotEmpty) {
        weeks = int.tryParse(weeksText);
        if (weeks == null || weeks < 0) {
          throw Exception('Sedmicama obavještenja mora biti broj ≥ 0.');
        }
      }
      final contacts = _contacts
          .map(
            (r) => CustomerRequirementsContact(
              name: r.nameCtrl.text.trim(),
              role: r.roleCtrl.text.trim(),
              email: r.emailCtrl.text.trim(),
              phone: r.phoneCtrl.text.trim(),
            ),
          )
          .where(
            (c) =>
                c.name.isNotEmpty ||
                c.role.isNotEmpty ||
                c.email.isNotEmpty ||
                c.phone.isNotEmpty,
          )
          .toList();
      final patch = CustomerRequirementsProfileModel(
        customerId: widget.customerId.trim(),
        companyId: _companyId,
        customerNameSnapshot: widget.customerDisplayName.trim().isEmpty
            ? null
            : widget.customerDisplayName.trim(),
        ppapLevel: _ppapLevel,
        specialRequirements: _specialCtrl.text.trim(),
        changeNotificationWeeks: weeks,
        packagingNotes: _packCtrl.text.trim(),
        documentationRequirements: _docCtrl.text.trim(),
        reactionPlanPolicy: _reactionCtrl.text.trim(),
        tolerancePolicy: _toleranceCtrl.text.trim(),
        csrDocumentReference: _csrRefCtrl.text.trim(),
        communicationContacts: contacts,
      );
      await _service.upsertCustomerRequirementsProfile(
        companyId: _companyId,
        customerId: widget.customerId.trim(),
        profile: patch,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSR profil je sačuvan.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppErrorMapper.toMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zahtjevi kupca (CSR)'),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Osvježi',
          ),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            tooltip: 'Sačuvaj',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.customerDisplayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Šifra / id: ${widget.customerId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Profil se čita u Razvoju i koristi za Launch Intelligence (CSR, PPAP, kontrola promjena).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                  if (_saving) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'csr_ppap_${widget.customerId}_$_ppapLevel',
                    ),
                    initialValue: _ppapLevel,
                    decoration: const InputDecoration(
                      labelText: 'PPAP nivo (reference)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('— Nije definisano —')),
                      DropdownMenuItem(value: 'level_1', child: Text('Level 1')),
                      DropdownMenuItem(value: 'level_2', child: Text('Level 2')),
                      DropdownMenuItem(value: 'level_3', child: Text('Level 3')),
                      DropdownMenuItem(value: 'level_4', child: Text('Level 4')),
                      DropdownMenuItem(value: 'level_5', child: Text('Level 5')),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _ppapLevel = v ?? 'none'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weeksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Obavještenje o promjeni (sedmice unaprijed)',
                      border: OutlineInputBorder(),
                      helperText: 'Npr. 12 sedmica prije promjene.',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _specialCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Posebni zahtjevi kupca',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _packCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pakovanje / ambalaža',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _docCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dokumentacija (npr. MSA, Cp/Cpk)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reactionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reakcioni plan (npr. obavezan 8D)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _toleranceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tolerancije / posebna pravila',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _csrRefCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Referenca na CSR dokument / ugovor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Kontakti za komunikaciju',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _contacts.add(_ContactRow())),
                        icon: const Icon(Icons.add),
                        label: const Text('Red'),
                      ),
                    ],
                  ),
                  ..._contacts.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text('#${i + 1}'),
                                const Spacer(),
                                if (_contacts.length > 1)
                                  IconButton(
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() {
                                              row.dispose();
                                              _contacts.removeAt(i);
                                            }),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                              ],
                            ),
                            TextField(
                              controller: row.nameCtrl,
                              decoration: const InputDecoration(labelText: 'Ime'),
                            ),
                            TextField(
                              controller: row.roleCtrl,
                              decoration: const InputDecoration(labelText: 'Uloga'),
                            ),
                            TextField(
                              controller: row.emailCtrl,
                              decoration: const InputDecoration(labelText: 'E-pošta'),
                            ),
                            TextField(
                              controller: row.phoneCtrl,
                              decoration: const InputDecoration(labelText: 'Telefon'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Sačuvaj'),
            ),
    );
  }
}

class _ContactRow {
  _ContactRow({
    String name = '',
    String role = '',
    String email = '',
    String phone = '',
  })  : nameCtrl = TextEditingController(text: name),
        roleCtrl = TextEditingController(text: role),
        emailCtrl = TextEditingController(text: email),
        phoneCtrl = TextEditingController(text: phone);

  final TextEditingController nameCtrl;
  final TextEditingController roleCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;

  void dispose() {
    nameCtrl.dispose();
    roleCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
  }
}
