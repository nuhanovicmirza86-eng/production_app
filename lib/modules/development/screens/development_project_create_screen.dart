// DropdownButtonFormField: kontrolirani `value` (Stateful) — i dalje ispravno do sljedeće API stabilizacije.
// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import 'development_project_details_screen.dart';

/// Korak 4 MVP — obavezna poslovna godina i tenant scope Callable validira.
class DevelopmentProjectCreateScreen extends StatefulWidget {
  const DevelopmentProjectCreateScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<DevelopmentProjectCreateScreen> createState() =>
      _DevelopmentProjectCreateScreenState();
}

class _DevelopmentProjectCreateScreenState
    extends State<DevelopmentProjectCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DevelopmentProjectService();
  final _nameCtrl = TextEditingController();
  final _manualYearCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();

  String _projectType = DevelopmentProjectTypes.customerNewProduct;
  String _priority = DevelopmentPriorities.medium;
  String? _selectedFinancialYearId;
  bool _submitting = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canPickAnotherPm =>
      ProductionAccessHelper.isAdminRole(_role) ||
      ProductionAccessHelper.isSuperAdminRole(_role);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manualYearCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje podatak o organizaciji ili pogonu.'),
        ),
      );
      return;
    }

    final businessYearId = _effectiveBusinessYearId();
    if (businessYearId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odaberite ili unesite poslovnu godinu.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _service.createProjectViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        businessYearId: businessYearId,
        projectName: _nameCtrl.text.trim(),
        projectType: _projectType,
        priority: _priority,
        customerName: _customerCtrl.text.trim().isEmpty
            ? null
            : _customerCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DevelopmentProjectDetailsScreen(
            companyData: widget.companyData,
            projectId: result.projectId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kreiranje nije uspjelo: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Ako postoje financial_years dokumenti, vrijednost je doc.id; inače ručni unos.
  String _effectiveBusinessYearId() {
    return (_selectedFinancialYearId ?? _manualYearCtrl.text.trim()).trim();
  }

  @override
  Widget build(BuildContext context) {
    final fyRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('financial_years');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novi projekat razvoja'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fyRef.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    'Poslovne godine trenutno nisu dostupne za učitavanje.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  );
                }
                final docs = snap.data?.docs ?? [];
                final usable = docs.where((d) {
                  final s = (d.data()['status'] ?? '').toString().toLowerCase();
                  return s == 'active' || s == 'draft';
                }).toList();

                if (usable.isNotEmpty && _selectedFinancialYearId == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedFinancialYearId = usable.first.id;
                      });
                    }
                  });
                }

                if (usable.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Nema definisanih poslovnih godina u šifrarniku — unesi oznaku ručno (Callable prihvaća fallback).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _manualYearCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Poslovna godina *',
                          hintText: 'npr. 2026',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Obavezno polje.';
                          }
                          return null;
                        },
                      ),
                    ],
                  );
                }

                return DropdownButtonFormField<String>(
                  value: _selectedFinancialYearId,
                  decoration: const InputDecoration(
                    labelText: 'Poslovna godina *',
                    border: OutlineInputBorder(),
                  ),
                  items: usable.map((d) {
                    final m = d.data();
                    final code = (m['code'] ?? '').toString();
                    final name = (m['name'] ?? '').toString();
                    final label = name.isNotEmpty
                        ? '$code — $name'
                        : (code.isNotEmpty ? code : d.id);
                    return DropdownMenuItem<String>(
                      value: d.id,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedFinancialYearId = v),
                  validator: (v) {
                    if ((v ?? '').isEmpty) {
                      return 'Odaberi poslovnu godinu.';
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naziv projekta *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Obavezno polje.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _projectType,
              decoration: const InputDecoration(
                labelText: 'Tip projekta *',
                border: OutlineInputBorder(),
              ),
              items: DevelopmentProjectTypes.all
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(DevelopmentDisplay.projectTypeLabel(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _projectType = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Prioritet',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Nizak')),
                DropdownMenuItem(value: 'medium', child: Text('Srednji')),
                DropdownMenuItem(value: 'high', child: Text('Visok')),
                DropdownMenuItem(value: 'critical', child: Text('Kritičan')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerCtrl,
              decoration: const InputDecoration(
                labelText: 'Kupac (opcionalno)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_canPickAnotherPm) ...[
              const SizedBox(height: 8),
              Text(
                'Project Manager se podrazumijeva na tebe; drugog PM možeš dodijeliti kasnije kroz Callable za izmjenu profila.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kreiraj projekat'),
            ),
          ],
        ),
      ),
    );
  }
}
