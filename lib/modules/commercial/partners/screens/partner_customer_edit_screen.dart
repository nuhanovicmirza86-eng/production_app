import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../data/activity_sector_catalog.dart';
import '../data/activity_sector_visibility.dart';
import '../models/partner_models.dart';
import '../services/customers_service.dart';
import 'activity_sectors_catalog_screen.dart';

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
  late final TextEditingController _countryCodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _taxIdController;
  late final TextEditingController _notesController;
  late final TextEditingController _contractDeliveryController;
  late final TextEditingController _contractPaymentController;
  late final TextEditingController _contractCollectionController;
  late final TextEditingController _contractGraceController;

  String _status = 'active';
  String _customerType = 'direct';
  String _partnerRatingClass = 'unrated';
  bool _isStrategic = false;

  /// Šifra iz [activity_sector_catalog]; `null` = nije odabrano.
  String? _activitySectorCode;

  /// Stari slobodan unos u Firestoreu (nije u šifarniku).
  String? _legacyActivitySector;

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
    _countryCodeController = TextEditingController();
    _cityController = TextEditingController();
    _addressController = TextEditingController();
    _taxIdController = TextEditingController();
    _notesController = TextEditingController();
    _contractDeliveryController = TextEditingController();
    _contractPaymentController = TextEditingController();
    _contractCollectionController = TextEditingController();
    _contractGraceController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _legalNameController.dispose();
    _countryController.dispose();
    _countryCodeController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _notesController.dispose();
    _contractDeliveryController.dispose();
    _contractPaymentController.dispose();
    _contractCollectionController.dispose();
    _contractGraceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
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
      _countryCodeController.text = m.countryCode ?? '';
      _cityController.text = m.city ?? '';
      _addressController.text = m.address ?? '';
      _taxIdController.text = m.taxId ?? '';
      _notesController.text = m.notes ?? '';
      _status = m.status;
      _customerType = m.customerType;
      _contractDeliveryController.text = m.contractDeliveryDays?.toString() ?? '';
      _contractPaymentController.text = m.contractPaymentDays?.toString() ?? '';
      _contractCollectionController.text = m.contractCollectionDays?.toString() ?? '';
      _contractGraceController.text = m.contractGraceDaysLate?.toString() ?? '';
      final rawAct = (m.activitySector ?? '').trim();
      if (rawAct.isEmpty) {
        _activitySectorCode = null;
        _legacyActivitySector = null;
      } else if (activitySectorIsKnownCode(rawAct)) {
        _activitySectorCode = rawAct;
        _legacyActivitySector = null;
      } else {
        _activitySectorCode = null;
        _legacyActivitySector = rawAct;
      }
      _partnerRatingClass = m.partnerRatingClass;
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

  int? _optionalPositiveInt(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 0) {
      throw Exception('Broj dana mora biti nenegativan cijeli broj.');
    }
    return n;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_legacyActivitySector != null &&
          _legacyActivitySector!.trim().isNotEmpty) {
        throw Exception(
          'Odaberi djelatnost iz šifarnika ili dodirni „Obriši djelatnost”.',
        );
      }

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
        countryCode: () {
          final cc = _countryCodeController.text.trim().toUpperCase();
          if (cc.isEmpty) return null;
          if (cc.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(cc)) {
            throw Exception(
              'ISO država mora biti točno 2 slova (npr. BA, DE).',
            );
          }
          return cc;
        }(),
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
        contractDeliveryDays: _optionalPositiveInt(_contractDeliveryController),
        contractPaymentDays: _optionalPositiveInt(_contractPaymentController),
        contractCollectionDays: _optionalPositiveInt(_contractCollectionController),
        contractGraceDaysLate: _optionalPositiveInt(_contractGraceController),
        activitySector:
            _activitySectorCode == null || _activitySectorCode!.trim().isEmpty
                ? null
                : _activitySectorCode!.trim(),
        partnerRatingClass: _partnerRatingClass,
        isStrategic: _isStrategic,
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
            tooltip: 'Šifarnik djelatnosti',
            onPressed: _saving
                ? null
                : () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ActivitySectorsCatalogScreen(),
                      ),
                    );
                  },
            icon: const Icon(Icons.menu_book_outlined),
          ),
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
                        controller: _countryCodeController,
                        decoration: _dec('ISO država (2 slova)').copyWith(
                          hintText: 'npr. BA, DE',
                          counterText: '',
                        ),
                        maxLength: 2,
                        textCapitalization: TextCapitalization.characters,
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
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ugovoreni normativi i procjena',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _contractDeliveryController,
                        decoration: _dec(
                          'Rok isporuke od narudžbe (dana)',
                        ).copyWith(
                          helperText:
                              'Ugovoreni kalendarski dani isporuke od datuma narudžbe.',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contractPaymentController,
                        decoration: _dec('Rok plaćanja (dana)').copyWith(
                          helperText: 'Npr. neto rok od fakture ili isporuke.',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contractCollectionController,
                        decoration: _dec('Rok naplate (dana)').copyWith(
                          helperText: 'Ako se razlikuje od roka plaćanja.',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contractGraceController,
                        decoration: _dec(
                          'Dozvoljeni prekoračeni rok (dana)',
                        ).copyWith(
                          helperText: 'Grace period prije eskalacije.',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final visible = resolveVisibleActivitySectors(
                            widget.companyData['enabledActivitySectorCodes'],
                          );
                          final picker = sectorsForPartnerPicker(
                            visibleForCompany: visible,
                            currentCode: _activitySectorCode,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String?>(
                                key: ValueKey(
                                  '${_activitySectorCode}_${_legacyActivitySector != null}',
                                ),
                                initialValue: _activitySectorCode,
                                isExpanded: true,
                                decoration: _dec('Djelatnost').copyWith(
                                  helperText:
                                      'Šifarnik — aktivne stavke određuje logistika (Kupci i dobavljači → ikonica klizača).',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('— Nije odabrano —'),
                                  ),
                                  ...picker.map(
                                    (e) => DropdownMenuItem<String?>(
                                      value: e.code,
                                      child: Text(
                                        e.label,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _activitySectorCode = v;
                                  _legacyActivitySector = null;
                                }),
                              ),
                              if (visible.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Nema aktivnih djelatnosti za ovu tvrtku. '
                                    'Otvori Kupci i dobavljači → postavke djelatnosti (ikona klizača).',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (_legacyActivitySector != null &&
                          _legacyActivitySector!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Material(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Stari slobodan unos u bazi: “$_legacyActivitySector”. '
                              'Odaberi stavku iz liste iznad i sačuvaj.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _legacyActivitySector = null;
                              _activitySectorCode = null;
                            }),
                            child: const Text(
                              'Obriši djelatnost (ukloni iz partnera)',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('abc_$_partnerRatingClass'),
                        initialValue: _partnerRatingClass,
                        decoration: _dec('Kategorija (ABC)').copyWith(
                          helperText:
                              'A dobar • B upozorenje • C nepouzdan (strategija ispod).',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'unrated',
                            child: Text('Nije procijenjeno'),
                          ),
                          DropdownMenuItem(
                            value: 'A',
                            child: Text('A — dobar'),
                          ),
                          DropdownMenuItem(
                            value: 'B',
                            child: Text('B — upozorenje'),
                          ),
                          DropdownMenuItem(
                            value: 'C',
                            child: Text('C — nepouzdan'),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => _partnerRatingClass = v ?? 'unrated',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Strateški partner'),
                        subtitle: const Text(
                          'Za C-kategoriju: nema alternative — posebno označavanje u listi.',
                        ),
                        value: _isStrategic,
                        onChanged: (v) => setState(() => _isStrategic = v),
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
