import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:production_app/core/company_plant_display_name.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../services/workforce_callable_service.dart';
import 'workforce_employee_badge_pdf.dart';
import 'workforce_qr_payload.dart';

class EmployeeEditScreen extends StatefulWidget {
  const EmployeeEditScreen({
    super.key,
    required this.companyData,
    required this.existing,
  });

  final Map<String, dynamic> companyData;
  final WorkforceEmployee? existing;

  @override
  State<EmployeeEditScreen> createState() => _EmployeeEditScreenState();
}

class _EmployeeEditScreenState extends State<EmployeeEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _job;
  late final TextEditingController _shiftGroup;
  late final TextEditingController _hire;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _reportsTo;
  late final TextEditingController _linkedUid;
  String _status = 'active';
  bool _active = true;
  bool _saving = false;

  List<({String plantKey, String label})> _plantChoices = [];
  bool _plantsLoading = false;
  String _newEmployeePlantKey = '';
  String _editPlantKey = '';

  final _svc = WorkforceCallableService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _sessionPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  /// Isto pravo kao lista / uređivanje radnika (smjene / workforce).
  bool get _canManageWorkforce => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.shifts,
      );

  bool get _isNew => widget.existing == null;

  /// Sesija u Callable ([assertWorkforceActor]) — uvijek trenutni pogon u appu, ne pogon u zapisu.
  String get _apiSessionPlant => _sessionPlantKey;

  /// Ciljni pogon zapisu — za QR/PDF u UI.
  String get _displayPlantKey {
    if (_isNew) {
      if (_canManageWorkforce && _newEmployeePlantKey.trim().isNotEmpty) {
        return _newEmployeePlantKey.trim();
      }
      return _sessionPlantKey;
    }
    final e = widget.existing;
    if (e == null) return _sessionPlantKey;
    if (_canManageWorkforce && _editPlantKey.trim().isNotEmpty) {
      return _editPlantKey.trim();
    }
    return e.plantKey.trim().isEmpty ? _sessionPlantKey : e.plantKey;
  }

  /// [targetPlantKey] u Callable: kad uloga smije pogon; prazno = backend ne dira pogon (update) ili tretira sesiju (create).
  String? get _apiTargetPlantKey {
    if (_isNew) {
      if (!_canManageWorkforce) return null;
      if (_newEmployeePlantKey.trim().isEmpty) return null;
      if (_newEmployeePlantKey.trim() == _sessionPlantKey) return null;
      return _newEmployeePlantKey.trim();
    }
    final e = widget.existing;
    if (e == null || !_canManageWorkforce) return null;
    if (_editPlantKey.trim().isEmpty) return null;
    if (_editPlantKey.trim() == e.plantKey.trim()) return null;
    return _editPlantKey.trim();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.displayName ?? '');
    _job = TextEditingController(text: e?.jobTitle ?? '');
    _shiftGroup = TextEditingController(text: e?.shiftGroup ?? '');
    _hire = TextEditingController(text: e?.hireDate ?? '');
    _email = TextEditingController(text: e?.internalContactEmail ?? '');
    _phone = TextEditingController(text: e?.internalContactPhone ?? '');
    _reportsTo = TextEditingController(text: e?.reportsToEmployeeDocId ?? '');
    _linkedUid = TextEditingController(text: e?.linkedUserUid ?? '');
    if (e != null) {
      _status = e.employmentStatus.isEmpty ? 'active' : e.employmentStatus;
      _active = e.active;
      _editPlantKey = e.plantKey.trim();
    } else {
      _newEmployeePlantKey = _sessionPlantKey;
    }
    _loadPlants();
  }

  /// Padajući izbor za sve uloge s pravom upravljanja radnicima.
  Future<void> _loadPlants() async {
    if (!_canManageWorkforce) return;
    setState(() => _plantsLoading = true);
    final list = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _companyId,
    );
    if (!mounted) return;
    var pickNew = _newEmployeePlantKey;
    if (list.isNotEmpty) {
      if (pickNew.isEmpty || !list.any((p) => p.plantKey == pickNew)) {
        pickNew = list.any((p) => p.plantKey == _sessionPlantKey)
            ? _sessionPlantKey
            : list.first.plantKey;
      }
    }
    var pickEdit = _editPlantKey;
    final e = widget.existing;
    if (e != null && list.isNotEmpty) {
      if (pickEdit.isEmpty || !list.any((p) => p.plantKey == pickEdit)) {
        pickEdit = e.plantKey.trim().isNotEmpty
            ? e.plantKey
            : _sessionPlantKey;
        if (!list.any((p) => p.plantKey == pickEdit) && list.isNotEmpty) {
          pickEdit = list.first.plantKey;
        }
      }
    }
    setState(() {
      _plantChoices = list;
      if (_isNew) {
        _newEmployeePlantKey = pickNew;
      } else if (e != null) {
        _editPlantKey = pickEdit;
      }
      _plantsLoading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _job.dispose();
    _shiftGroup.dispose();
    _hire.dispose();
    _email.dispose();
    _phone.dispose();
    _reportsTo.dispose();
    _linkedUid.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_apiSessionPlant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje pogon (sesija aplikacije). Otvorite pogon u izborniku pa pokušajte ponovo.'),
        ),
      );
      return;
    }
    if (_isNew && _canManageWorkforce && _plantChoices.isNotEmpty) {
      if (_newEmployeePlantKey.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Odaberite pogon za radnika.'),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final wasNew = _isNew;
      final target = _apiTargetPlantKey;
      final r = await _svc.upsertEmployee(
        companyId: _companyId,
        plantKey: _apiSessionPlant,
        employeeDocId: widget.existing?.id,
        targetPlantKey: target ?? '',
        displayName: _name.text.trim(),
        employmentStatus: _status,
        jobTitle: _job.text.trim(),
        reportsToEmployeeDocId: _reportsTo.text.trim(),
        hireDate: _hire.text.trim(),
        shiftGroup: _shiftGroup.text.trim(),
        active: _active,
        internalContactEmail: _email.text.trim(),
        internalContactPhone: _phone.text.trim(),
        linkedUserUid: _linkedUid.text.trim(),
      );
      if (wasNew && mounted) {
        final newId = (r['employeeDocId'] ?? '').toString().trim();
        if (newId.isNotEmpty) {
          await _showQrBadgeDialog(
            employeeDocId: newId,
            displayName: _name.text.trim(),
            jobTitle: _job.text.trim(),
            qrPlantKey: _displayPlantKey,
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Greška')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showQrBadgeDialog({
    required String employeeDocId,
    required String displayName,
    required String jobTitle,
    required String qrPlantKey,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR bedž radnika'),
        content: SingleChildScrollView(
          child: _WorkforceQrCard(
            companyData: widget.companyData,
            qrPlantKey: qrPlantKey,
            employeeDocId: employeeDocId,
            displayName: displayName,
            jobTitle: jobTitle,
            catalogCode: employeeDocId,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  /// Pogon: padajući izbor s pravom upravljanja, inače samo informacija.
  List<Widget> _plantFormFields(BuildContext context) {
    final e = widget.existing;
    if (_isNew) {
      if (_canManageWorkforce) {
        return [
          if (_plantsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(),
            )
          else if (_plantChoices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Nema pogona u company_plants — dodaj pogon u Maintenance / postavkama kompanije.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_newEmployeePlantKey),
              initialValue: _newEmployeePlantKey,
              decoration: const InputDecoration(
                labelText: 'Pogon *',
                helperText:
                    'Dodjeli pogon radnika. Ako ne promijeniš, zapis slijedi trenutni pogon u aplikaciji (sesija).',
              ),
              items: _plantChoices
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p.plantKey,
                      child: Text(p.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() => _newEmployeePlantKey = v);
                      }
                    },
            ),
          const SizedBox(height: 8),
        ];
      }
      return [
        FutureBuilder<String>(
          future: CompanyPlantDisplayName.resolve(
            companyId: _companyId,
            plantKey: _sessionPlantKey,
          ),
          builder: (context, snap) {
            final label = snap.hasData
                ? snap.data!
                : (snap.hasError ? _sessionPlantKey : '…');
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Pogon: $label (prati trenutni pogon u aplikaciji — nema prava postavljanja drugog pogona)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          },
        ),
      ];
    }
    if (e == null) return [];
    if (_canManageWorkforce) {
      return [
        if (_plantsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(),
          )
        else if (_plantChoices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Nema pogona u company_plants — dodaj pogon u postavkama kompanije.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_editPlantKey),
            initialValue: _editPlantKey,
            decoration: const InputDecoration(
              labelText: 'Pogon *',
              helperText:
                  'Korisnik s pravom upravljanja može premjestiti radnika u drugi pogon u istoj firmi. Provjeri kvalifikacije nakon promjene.',
            ),
            items: _plantChoices
                .map(
                  (p) => DropdownMenuItem<String>(
                    value: p.plantKey,
                    child: Text(p.label),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) {
                    if (v != null) {
                      setState(() => _editPlantKey = v);
                    }
                  },
          ),
        const SizedBox(height: 8),
      ];
    }
    return [
      FutureBuilder<String>(
        future: CompanyPlantDisplayName.resolve(
          companyId: _companyId,
          plantKey: e.plantKey,
        ),
        builder: (context, snap) {
          final label = snap.hasData
              ? snap.data!
              : (snap.hasError ? e.plantKey : '…');
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Pogon: $label',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.existing;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Novi radnik' : 'Uredi radnika'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isNew) ...[
              Text(
                'Novi radnik dobiva trajni sistemski kôd (automatski). '
                'Kôd se ne mijenja. Ime ispod je prikaz u vašoj kompaniji.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
            ] else if (e != null) ...[
              Text(
                'Sistemski kôd (nepromjenjiv): ${e.catalogCode}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _WorkforceQrCard(
                companyData: widget.companyData,
                qrPlantKey: _displayPlantKey,
                employeeDocId: e.id,
                displayName: e.displayName,
                jobTitle: e.jobTitle,
                catalogCode: e.catalogCode,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Ime za prikaz u kompaniji *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obavezno' : null,
            ),
            ..._plantFormFields(context),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_status),
              initialValue: _status,
              decoration:
                  const InputDecoration(labelText: 'Status zaposlenja'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Aktivan')),
                DropdownMenuItem(value: 'inactive', child: Text('Neaktivan')),
                DropdownMenuItem(
                  value: 'on_leave',
                  child: Text('Odsutan (operativno)'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _status = v);
                    },
            ),
            SwitchListTile(
              title: const Text('Aktivan za raspored'),
              value: _active,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _active = v),
            ),
            TextFormField(
              controller: _job,
              decoration:
                  const InputDecoration(labelText: 'Radno mjesto / uloga'),
            ),
            TextFormField(
              controller: _shiftGroup,
              decoration: const InputDecoration(
                labelText: 'Smjena / grupa (npr. DAN, tim A)',
              ),
            ),
            TextFormField(
              controller: _hire,
              decoration: const InputDecoration(
                labelText: 'Datum zaposlenja (GGGG-MM-DD, opcionalno)',
              ),
            ),
            TextFormField(
              controller: _reportsTo,
              decoration: const InputDecoration(
                labelText: 'Nadređeni (sistemski kôd, opcionalno)',
                helperText:
                    'Kôd s profila drugog radnika (polje „Sistemski kôd”).',
              ),
            ),
            TextFormField(
              controller: _linkedUid,
              decoration: const InputDecoration(
                labelText:
                    'Veza na korisnički nalog (opcionalno)',
                helperText:
                    'Isti nalog ne može se kasnije dodijeliti drugom radniku.',
              ),
              readOnly: (e?.linkedUserUid?.trim().isNotEmpty ?? false),
            ),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Interni e-mail (operativa)',
              ),
            ),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Interni telefon (operativa)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spremi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkforceQrCard extends StatefulWidget {
  const _WorkforceQrCard({
    required this.companyData,
    required this.employeeDocId,
    required this.displayName,
    required this.jobTitle,
    this.catalogCode,
    this.qrPlantKey,
  });

  final Map<String, dynamic> companyData;
  final String employeeDocId;
  final String displayName;
  final String jobTitle;
  final String? catalogCode;

  /// Kad je zapis u drugom pogonu od [companyData.plantKey] (npr. admin u cijeloj kompaniji).
  final String? qrPlantKey;

  @override
  State<_WorkforceQrCard> createState() => _WorkforceQrCardState();
}

class _WorkforceQrCardState extends State<_WorkforceQrCard> {
  bool _pdfBusy = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKeyForPayload =>
      (widget.qrPlantKey ?? widget.companyData['plantKey'] ?? '')
          .toString()
          .trim();

  String get _companyDisplayName {
    final n = (widget.companyData['name'] ?? widget.companyData['companyName'] ?? '')
        .toString()
        .trim();
    if (n.isNotEmpty) return n;
    return _companyId;
  }

  String get _payload {
    final pk = _plantKeyForPayload;
    if (pk.isEmpty) {
      return buildWorkforceEmployeeQrPayload(
        companyId: _companyId,
        plantKey: 'MISSING_PLANT',
        employeeDocId: widget.employeeDocId,
      );
    }
    return buildWorkforceEmployeeQrPayload(
      companyId: _companyId,
      plantKey: pk,
      employeeDocId: widget.employeeDocId,
    );
  }

  String _dash(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  Future<void> _exportPdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final plant = await _resolvePlant();
      if (!mounted) return;
      await WorkforceEmployeeBadgePdf.printBadge(
        qrPayload: _payload,
        employeeFullName: _dash(widget.displayName),
        companyName: _companyDisplayName,
        plantLabel: plant,
        jobRole: _dash(widget.jobTitle),
        catalogCode: widget.catalogCode ?? widget.employeeDocId,
        fileName: 'bedz_${widget.employeeDocId}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final plant = await _resolvePlant();
      if (!mounted) return;
      await WorkforceEmployeeBadgePdf.shareBadge(
        qrPayload: _payload,
        employeeFullName: _dash(widget.displayName),
        companyName: _companyDisplayName,
        plantLabel: plant,
        jobRole: _dash(widget.jobTitle),
        catalogCode: widget.catalogCode ?? widget.employeeDocId,
        fileName: 'bedz_${widget.employeeDocId}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dijeljenje: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<String> _resolvePlant() {
    return CompanyPlantDisplayName.resolve(
      companyId: _companyId,
      plantKey: _plantKeyForPayload,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _dash(widget.displayName);
    final role = _dash(widget.jobTitle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Isti raspored kao etikete na stanicama: QR lijevo, lični i podaci tvrtke desno. PDF otvara A6 stranicu za štampu.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black26),
              ),
              child: QrImageView(
                data: _payload,
                size: 132,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badgeLine(theme, 'Ime i prezime', name),
                  const SizedBox(height: 6),
                  _badgeLine(
                    theme,
                    'Kompanija',
                    _companyDisplayName,
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<String>(
                    future: CompanyPlantDisplayName.resolve(
                      companyId: _companyId,
                      plantKey: _plantKeyForPayload,
                    ),
                    builder: (context, snap) {
                      final p = snap.hasData
                          ? snap.data!
                          : (snap.hasError ? '—' : '…');
                      return _badgeLine(theme, 'Pogon', p);
                    },
                  ),
                  const SizedBox(height: 6),
                  _badgeLine(theme, 'Uloga', role),
                ],
              ),
            ),
          ],
        ),
        if ((widget.catalogCode ?? '').toString().trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Sistemski kôd: ${widget.catalogCode!.trim()}',
            style: theme.textTheme.labelSmall,
          ),
        ],
        const SizedBox(height: 12),
        SelectableText(
          _payload,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _payload));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('QR sadržaj kopiran u međuspremnik'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Kopiraj sadržaj'),
            ),
            FilledButton.tonalIcon(
              onPressed: _pdfBusy ? null : _exportPdf,
              icon: _pdfBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: Text(_pdfBusy ? 'Generišem…' : 'PDF / štampa (kao etiketa)'),
            ),
            OutlinedButton.icon(
              onPressed: _pdfBusy ? null : _sharePdf,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Podijeli PDF'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badgeLine(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
