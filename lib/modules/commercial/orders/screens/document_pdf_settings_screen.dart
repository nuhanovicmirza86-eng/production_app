import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/document_pdf_settings.dart';
import '../services/document_pdf_settings_service.dart';

/// Uređivanje zaglavlja i podataka kompanije za PDF narudžbenice i srodne dokumente.
class DocumentPdfSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const DocumentPdfSettingsScreen({super.key, required this.companyData});

  @override
  State<DocumentPdfSettingsScreen> createState() =>
      _DocumentPdfSettingsScreenState();
}

class _DocumentPdfSettingsScreenState extends State<DocumentPdfSettingsScreen> {
  final _service = DocumentPdfSettingsService();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final TextEditingController _legalName;
  late final TextEditingController _businessDesc;
  late final TextEditingController _addr1;
  late final TextEditingController _addr2;
  late final TextEditingController _phone;
  late final TextEditingController _fax;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _court;
  late final TextEditingController _idNumber;
  late final TextEditingController _vatNumber;
  late final TextEditingController _bankName;
  late final TextEditingController _bankAccount;
  late final TextEditingController _bankIban;
  late final TextEditingController _logoUrl;
  late final TextEditingController _defVat;
  late final TextEditingController _defDisc;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _legalName = TextEditingController();
    _businessDesc = TextEditingController();
    _addr1 = TextEditingController();
    _addr2 = TextEditingController();
    _phone = TextEditingController();
    _fax = TextEditingController();
    _email = TextEditingController();
    _website = TextEditingController();
    _court = TextEditingController();
    _idNumber = TextEditingController();
    _vatNumber = TextEditingController();
    _bankName = TextEditingController();
    _bankAccount = TextEditingController();
    _bankIban = TextEditingController();
    _logoUrl = TextEditingController();
    _defVat = TextEditingController(text: '17');
    _defDisc = TextEditingController(text: '0');
    _load();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.load(_companyId);
      if (!mounted) return;
      _legalName.text = s.companyLegalName;
      _businessDesc.text = s.businessDescription;
      _addr1.text = s.addressLine1;
      _addr2.text = s.addressLine2;
      _phone.text = s.phone;
      _fax.text = s.fax;
      _email.text = s.email;
      _website.text = s.website;
      _court.text = s.courtRegistration;
      _idNumber.text = s.idNumber;
      _vatNumber.text = s.vatNumber;
      _bankName.text = s.bankName;
      _bankAccount.text = s.bankAccount;
      _bankIban.text = s.bankIban;
      _logoUrl.text = s.logoUrl;
      _defVat.text = s.defaultVatPercent.toString();
      _defDisc.text = s.defaultDiscountPercent.toString();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMapper.toMessage(e);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId.isEmpty) return;

    int parseInt(TextEditingController c, int def) {
      final v = int.tryParse(c.text.trim());
      return v ?? def;
    }

    final settings = DocumentPdfSettings(
      version: 1,
      companyLegalName: _legalName.text.trim(),
      businessDescription: _businessDesc.text.trim(),
      addressLine1: _addr1.text.trim(),
      addressLine2: _addr2.text.trim(),
      phone: _phone.text.trim(),
      fax: _fax.text.trim(),
      email: _email.text.trim(),
      website: _website.text.trim(),
      courtRegistration: _court.text.trim(),
      idNumber: _idNumber.text.trim(),
      vatNumber: _vatNumber.text.trim(),
      bankName: _bankName.text.trim(),
      bankAccount: _bankAccount.text.trim(),
      bankIban: _bankIban.text.trim(),
      logoUrl: _logoUrl.text.trim(),
      defaultVatPercent: parseInt(_defVat, 17).clamp(0, 100),
      defaultDiscountPercent: parseInt(_defDisc, 0).clamp(0, 100),
    );

    setState(() => _saving = true);
    try {
      await _service.save(companyId: _companyId, settings: settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postavke dokumenta su sačuvane.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _legalName.dispose();
    _businessDesc.dispose();
    _addr1.dispose();
    _addr2.dispose();
    _phone.dispose();
    _fax.dispose();
    _email.dispose();
    _website.dispose();
    _court.dispose();
    _idNumber.dispose();
    _vatNumber.dispose();
    _bankName.dispose();
    _bankAccount.dispose();
    _bankIban.dispose();
    _logoUrl.dispose();
    _defVat.dispose();
    _defDisc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF — podaci kompanije'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sačuvaj'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Material(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  const Text(
                    'Ovi podaci se koriste u zaglavlju PDF narudžbenice za dobavljača. '
                    'Logo: direktan HTTPS link na sliku (PNG, JPG, SVG, ICO) ili adresa '
                    'web sajta (npr. firma.ba) — pokušat će se učitati ikona (favicon) sa sajta.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _legalName,
                    decoration: const InputDecoration(
                      labelText: 'Puni naziv kompanije',
                    ),
                  ),
                  TextFormField(
                    controller: _businessDesc,
                    decoration: const InputDecoration(
                      labelText: 'Djelatnost / opis (jedan red)',
                    ),
                  ),
                  TextFormField(
                    controller: _addr1,
                    decoration: const InputDecoration(labelText: 'Adresa 1'),
                  ),
                  TextFormField(
                    controller: _addr2,
                    decoration: const InputDecoration(labelText: 'Adresa 2'),
                  ),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  TextFormField(
                    controller: _fax,
                    decoration: const InputDecoration(labelText: 'Fax'),
                  ),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  TextFormField(
                    controller: _website,
                    decoration: const InputDecoration(labelText: 'Web'),
                  ),
                  TextFormField(
                    controller: _court,
                    decoration: const InputDecoration(
                      labelText: 'Sudski registar / komora',
                    ),
                  ),
                  TextFormField(
                    controller: _idNumber,
                    decoration: const InputDecoration(
                      labelText: 'Identifikacijski broj',
                    ),
                  ),
                  TextFormField(
                    controller: _vatNumber,
                    decoration: const InputDecoration(labelText: 'PDV broj'),
                  ),
                  TextFormField(
                    controller: _bankName,
                    decoration: const InputDecoration(labelText: 'Banka'),
                  ),
                  TextFormField(
                    controller: _bankAccount,
                    decoration: const InputDecoration(labelText: 'Broj računa'),
                  ),
                  TextFormField(
                    controller: _bankIban,
                    decoration: const InputDecoration(labelText: 'IBAN'),
                  ),
                  TextFormField(
                    controller: _logoUrl,
                    decoration: const InputDecoration(
                      labelText: 'URL loga ili web adresa (opcionalno)',
                      helperText:
                          'Slika ili domen sajta; ako nije direktna slika, koristi se favicon.',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _defVat,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Podrazumijevani PDV %',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _defDisc,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Podrazumijevani rabat %',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
