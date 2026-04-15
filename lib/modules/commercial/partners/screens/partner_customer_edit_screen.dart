import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/partner_models.dart';
import '../services/customers_service.dart';

class PartnerCustomerEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String? customerId;

  const PartnerCustomerEditScreen({
    super.key,
    required this.companyData,
    this.customerId,
  });

  @override
  State<PartnerCustomerEditScreen> createState() =>
      _PartnerCustomerEditScreenState();
}

class _PartnerCustomerEditScreenState extends State<PartnerCustomerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final CustomersService _service = CustomersService();

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
  late final TextEditingController _notesController;

  String _status = 'active';
  String _customerType = 'direct';

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool get _isEdit => (widget.customerId ?? '').trim().isNotEmpty;

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
    _notesController = TextEditingController();
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
    _notesController.dispose();
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
        customerId: widget.customerId!.trim(),
      );
      if (!mounted) return;
      if (m == null) {
        setState(() {
          _loading = false;
          _error = 'Kupac nije pronađen.';
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
      _notesController.text = m.notes ?? '';
      _status = m.status;
      _customerType = m.customerType;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final draft = CustomerModel(
        id: _isEdit ? widget.customerId!.trim() : '',
        companyId: _companyId,
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
        legalName: _legalNameController.text.trim(),
        status: _status,
        customerType: _customerType,
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
      );

      if (_isEdit) {
        await _service.updateCustomer(
          companyData: widget.companyData,
          customer: draft,
        );
      } else {
        await _service.createCustomer(
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
        title: Text(_isEdit ? 'Uredi kupca' : 'Novi kupac'),
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
                        key: ValueKey('type_$_customerType'),
                        initialValue: _customerType,
                        decoration: _dec('Tip kupca'),
                        items: const [
                          DropdownMenuItem(
                            value: 'direct',
                            child: Text('direct'),
                          ),
                          DropdownMenuItem(
                            value: 'distributor',
                            child: Text('distributor'),
                          ),
                          DropdownMenuItem(
                            value: 'internal',
                            child: Text('internal'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('other'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _customerType = v ?? 'direct'),
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
