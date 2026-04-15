import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/partner_models.dart';
import '../services/suppliers_service.dart';

class PartnerSupplierEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String? supplierId;

  const PartnerSupplierEditScreen({
    super.key,
    required this.companyData,
    this.supplierId,
  });

  @override
  State<PartnerSupplierEditScreen> createState() =>
      _PartnerSupplierEditScreenState();
}

class _PartnerSupplierEditScreenState extends State<PartnerSupplierEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final SuppliersService _service = SuppliersService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  // _model is not strictly needed; controllers hold current values.

  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _legalNameController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _taxIdController;
  late final TextEditingController _leadTimeDaysController;
  late final TextEditingController _notesController;
  late final TextEditingController _nonconformanceController;
  late final TextEditingController _claimCountController;
  late final TextEditingController _certificatesController;
  late final TextEditingController _approvedGroupsController;
  late final TextEditingController _approvedProcessesController;
  late final TextEditingController _changeReasonController;

  String _status = 'active';
  String _supplierType = 'material';
  String _supplierCategory = 'approved';
  String _approvalStatus = 'pending';
  String _riskLevel = 'medium';
  bool _isStrategic = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool get _isEdit => (widget.supplierId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _nameController = TextEditingController();
    _legalNameController = TextEditingController();
    _countryController = TextEditingController();
    _cityController = TextEditingController();
    _addressController = TextEditingController();
    _taxIdController = TextEditingController();
    _leadTimeDaysController = TextEditingController();
    _notesController = TextEditingController();
    _nonconformanceController = TextEditingController(text: '0');
    _claimCountController = TextEditingController(text: '0');
    _certificatesController = TextEditingController();
    _approvedGroupsController = TextEditingController();
    _approvedProcessesController = TextEditingController();
    _changeReasonController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _legalNameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _leadTimeDaysController.dispose();
    _notesController.dispose();
    _nonconformanceController.dispose();
    _claimCountController.dispose();
    _certificatesController.dispose();
    _approvedGroupsController.dispose();
    _approvedProcessesController.dispose();
    _changeReasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje companyId';
      });
      return;
    }

    if (!_isEdit) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final m = await _service.getById(
        companyId: _companyId,
        supplierId: widget.supplierId!.trim(),
      );
      if (!mounted) return;
      if (m == null) {
        setState(() {
          _loading = false;
          _error = 'Dobavljač nije pronađen.';
        });
        return;
      }

      _codeController.text = m.code;
      _nameController.text = m.name;
      _legalNameController.text = m.legalName;
      _countryController.text = m.country ?? '';
      _cityController.text = m.city ?? '';
      _addressController.text = m.address ?? '';
      _taxIdController.text = m.taxId ?? '';
      _leadTimeDaysController.text = m.leadTimeDays?.toString() ?? '';
      _notesController.text = m.notes ?? '';
      _nonconformanceController.text = m.nonconformanceCount.toString();
      _claimCountController.text = m.claimCount.toString();
      _certificatesController.text = m.certificates.join(', ');
      _approvedGroupsController.text = m.approvedMaterialGroups.join(', ');
      _approvedProcessesController.text = m.approvedProcesses.join(', ');
      _status = m.status;
      _supplierType = m.supplierType;
      _supplierCategory = m.supplierCategory;
      _approvalStatus = m.approvalStatus;
      _riskLevel = m.riskLevel;
      _isStrategic = m.isStrategic;

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMapper.toMessage(e);
      });
    }
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label);

  int? _leadTimeDaysOrNull() {
    final t = _leadTimeDaysController.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int _intOrZero(TextEditingController c) {
    return int.tryParse(c.text.trim()) ?? 0;
  }

  List<String> _csvToList(TextEditingController c) {
    return c.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final lead = _leadTimeDaysOrNull();
      if (lead != null && lead < 0) {
        throw Exception('Lead time ne može biti negativan');
      }

      final draft = SupplierModel(
        id: _isEdit ? widget.supplierId!.trim() : '',
        companyId: _companyId,
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
        legalName: _legalNameController.text.trim(),
        status: _status,
        supplierType: _supplierType,
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty
            ? null
            : _taxIdController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        leadTimeDays: lead,
        supplierCategory: _supplierCategory,
        isStrategic: _isStrategic,
        approvalStatus: _approvalStatus,
        riskLevel: _riskLevel,
        nonconformanceCount: _intOrZero(_nonconformanceController),
        claimCount: _intOrZero(_claimCountController),
        certificates: _csvToList(_certificatesController),
        approvedMaterialGroups: _csvToList(_approvedGroupsController),
        approvedProcesses: _csvToList(_approvedProcessesController),
      );

      if (_isEdit) {
        await _service.updateSupplier(
          companyData: widget.companyData,
          supplier: draft,
          changeReason: _changeReasonController.text.trim().isEmpty
              ? null
              : _changeReasonController.text.trim(),
        );
      } else {
        await _service.createSupplier(
          companyData: widget.companyData,
          draft: draft,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppErrorMapper.toMessage(e);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Uredi dobavljača' : 'Novi dobavljač'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_saving) const LinearProgressIndicator(minHeight: 2),
                if (_error != null) ...[
                  Material(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _codeController,
                        readOnly: true,
                        decoration: _dec('Šifra').copyWith(
                          helperText: _isEdit
                              ? 'Sistemska šifra (ne može se mijenjati).'
                              : 'Dodjeljuje se automatski pri snimanju.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: _dec('Naziv'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Obavezno' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _legalNameController,
                        decoration: _dec('Pravni naziv'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Obavezno' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('status_$_status'),
                        initialValue: _status,
                        decoration: _dec('Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('active'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('inactive'),
                          ),
                          DropdownMenuItem(
                            value: 'blocked',
                            child: Text('blocked'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'active'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('type_$_supplierType'),
                        initialValue: _supplierType,
                        decoration: _dec('Tip dobavljača'),
                        items: const [
                          DropdownMenuItem(
                            value: 'material',
                            child: Text('material'),
                          ),
                          DropdownMenuItem(
                            value: 'packaging',
                            child: Text('packaging'),
                          ),
                          DropdownMenuItem(
                            value: 'service',
                            child: Text('service'),
                          ),
                          DropdownMenuItem(
                            value: 'tooling',
                            child: Text('tooling'),
                          ),
                          DropdownMenuItem(
                            value: 'transport',
                            child: Text('transport'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _supplierType = v ?? 'material'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('cat_$_supplierCategory'),
                        initialValue: _supplierCategory,
                        decoration: _dec('Supplier category'),
                        items: const [
                          DropdownMenuItem(
                            value: 'strategic',
                            child: Text('strategic'),
                          ),
                          DropdownMenuItem(
                            value: 'approved',
                            child: Text('approved'),
                          ),
                          DropdownMenuItem(
                            value: 'conditional',
                            child: Text('conditional'),
                          ),
                          DropdownMenuItem(
                            value: 'blocked',
                            child: Text('blocked'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _supplierCategory = v ?? 'approved'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('approval_$_approvalStatus'),
                        initialValue: _approvalStatus,
                        decoration: _dec('Approval status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('pending'),
                          ),
                          DropdownMenuItem(
                            value: 'approved',
                            child: Text('approved'),
                          ),
                          DropdownMenuItem(
                            value: 'conditional',
                            child: Text('conditional'),
                          ),
                          DropdownMenuItem(
                            value: 'disqualified',
                            child: Text('disqualified'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _approvalStatus = v ?? 'pending'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('risk_$_riskLevel'),
                        initialValue: _riskLevel,
                        decoration: _dec('Risk level'),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('low')),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('medium'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('high')),
                        ],
                        onChanged: (v) =>
                            setState(() => _riskLevel = v ?? 'medium'),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Strateški dobavljač'),
                        value: _isStrategic,
                        onChanged: (v) => setState(() => _isStrategic = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _leadTimeDaysController,
                        decoration: _dec('Lead time (dana)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nonconformanceController,
                        decoration: _dec('Nonconformance count'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _claimCountController,
                        decoration: _dec('Claim count'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _approvedGroupsController,
                        decoration: _dec('Approved material groups (csv)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _approvedProcessesController,
                        decoration: _dec('Approved processes (csv)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _certificatesController,
                        decoration: _dec('Certificates (csv)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _countryController,
                        decoration: _dec('Država'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cityController,
                        decoration: _dec('Grad'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: _dec('Adresa'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _taxIdController,
                        decoration: _dec('PIB / Tax ID'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: _dec('Napomena'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _changeReasonController,
                        decoration: _dec(
                          'Razlog promjene (obavezno za risk/approval/strategic)',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Sačuvaj'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
