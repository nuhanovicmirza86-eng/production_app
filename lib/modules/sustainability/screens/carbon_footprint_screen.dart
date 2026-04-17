import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/user_display_label.dart';
import '../models/carbon_models.dart';
import '../services/carbon_calculation_service.dart';
import '../services/carbon_export_service.dart';
import '../services/carbon_firestore_service.dart';
import 'carbon_activity_line_editor_sheet.dart';

/// Redoslijed tabova = redoslijed unosa: postavke → kvote → aktivnosti → faktori → pregled → izvoz.
class CarbonFootprintScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const CarbonFootprintScreen({super.key, required this.companyData});

  @override
  State<CarbonFootprintScreen> createState() => _CarbonFootprintScreenState();
}

class _CarbonFootprintScreenState extends State<CarbonFootprintScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _svc = CarbonFirestoreService();

  int _year = DateTime.now().year;
  int _formGeneration = 0;

  CarbonCompanySetup? _setup;
  CarbonQuotaSettings? _quotas;
  Map<String, CarbonEmissionFactor> _factors = {};
  List<CarbonActivityLine> _activities = [];

  bool _loading = true;
  String? _loadError;
  bool _accessDenied = false;

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();
  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();
  String get _userId => (widget.companyData['userId'] ?? '').toString().trim();

  String get _fallbackName =>
      (widget.companyData['name'] ?? widget.companyData['companyName'] ?? '')
          .toString()
          .trim();

  bool get _canEditInputs => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.carbonFootprint,
  );

  bool get _isAdmin => ProductionAccessHelper.isAdminRole(_role);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 8, vsync: this);
    if (!ProductionAccessHelper.canView(
      role: _role,
      card: ProductionDashboardCard.carbonFootprint,
    )) {
      _accessDenied = true;
      _loading = false;
      return;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadStatic();
    _subscribeActivities();
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _actSub;

  void _subscribeActivities() {
    _actSub?.cancel();
    _actSub = FirebaseFirestore.instance
        .collection('carbon_activities')
        .where('companyId', isEqualTo: _cid)
        .where('reportingYear', isEqualTo: _year)
        .snapshots()
        .listen((snap) {
          final list =
              snap.docs
                  .map((d) => CarbonActivityLine.fromDoc(d.id, d.data()))
                  .toList()
                ..sort((a, b) => a.rowId.compareTo(b.rowId));
          if (mounted) setState(() => _activities = list);
        });
  }

  Future<void> _loadStatic() async {
    if (_cid.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'Nedostaje companyId';
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final setup = await _svc.loadSettings(
        companyId: _cid,
        reportingYear: _year,
        fallbackCompanyName: _fallbackName.isEmpty ? _cid : _fallbackName,
      );
      final quotas = await _svc.loadQuotas(
        companyId: _cid,
        reportingYear: _year,
      );
      final factors = await _svc.loadEffectiveFactors(_cid);
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _quotas = quotas;
        _factors = factors;
        _loading = false;
        _formGeneration++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  void _onYearChanged(int? y) {
    if (y == null || y == _year) return;
    setState(() => _year = y);
    _subscribeActivities();
    _loadStatic();
  }

  @override
  void dispose() {
    _actSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  CarbonDashboardSummary? get _summary {
    final s = _setup;
    if (s == null) return null;
    return CarbonCalculationService.summarize(
      setup: s,
      activities: _activities,
      factorsByKey: _factors,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('Karbonski otisak')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nemate pristup ovom modulu. Potrebna je uloga Admin, '
              'menadžer proizvodnje ili menadžer održavanja.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final years = List.generate(6, (i) => DateTime.now().year - i);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karbonski otisak'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: '1. Postavke'),
            Tab(text: '2. Kvote'),
            Tab(text: '3. Aktivnosti'),
            Tab(text: '4. Faktori'),
            Tab(text: '5. Pregled'),
            Tab(text: '6. Izvoz'),
            Tab(text: '7. Audit'),
            Tab(text: '8. Regulativa'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _year,
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: _onYearChanged,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : TabBarView(
              controller: _tabs,
              children: [
                _SetupTab(
                  key: ValueKey(_formGeneration),
                  setup: _setup!,
                  summary: _summary,
                  canEdit: _canEditInputs,
                  onSave: (s) => _saveSetup(s),
                ),
                _QuotasTab(
                  key: ValueKey('q$_formGeneration'),
                  quotas: _quotas!,
                  summary: _summary,
                  canEdit: _canEditInputs,
                  onSave: (q) => _saveQuotas(q),
                ),
                _ActivitiesTab(
                  companyId: _cid,
                  reportingYear: _year,
                  activities: _activities,
                  factors: _factors,
                  canEdit: _canEditInputs,
                  userId: _userId.isEmpty ? 'system' : _userId,
                  service: _svc,
                  onChanged: () {},
                ),
                _FactorsTab(
                  companyId: _cid,
                  reportingYear: _year,
                  factors: _factors,
                  isAdmin: _isAdmin,
                  service: _svc,
                  onSaved: _loadStatic,
                ),
                _DashboardTab(
                  setup: _setup!,
                  summary: _summary,
                  quotas: _quotas!,
                  activities: _activities,
                  factors: _factors,
                ),
                _ExportTab(
                  setup: _setup!,
                  activities: _activities,
                  factors: _factors,
                  quotas: _quotas!,
                  summary: _summary,
                  userId: _userId,
                  auditService: _svc,
                ),
                _AuditLogTab(
                  key: ValueKey('carbon_audit_${_cid}_$_year'),
                  companyId: _cid,
                  reportingYear: _year,
                  service: _svc,
                ),
                const _RegulatoryTab(),
              ],
            ),
    );
  }

  Future<void> _saveSetup(CarbonCompanySetup s) async {
    try {
      await _svc.saveSettings(setup: s, userId: _userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postavke su spremljene.')),
        );
        await _loadStatic();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Greška: $e')));
      }
    }
  }

  Future<void> _saveQuotas(CarbonQuotaSettings q) async {
    try {
      await _svc.saveQuotas(quotas: q, userId: _userId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kvote su spremljene.')));
        await _loadStatic();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Greška: $e')));
      }
    }
  }
}

// --- Tab 1 ---
class _SetupTab extends StatefulWidget {
  final CarbonCompanySetup setup;
  final CarbonDashboardSummary? summary;
  final bool canEdit;
  final Future<void> Function(CarbonCompanySetup) onSave;

  const _SetupTab({
    super.key,
    required this.setup,
    required this.summary,
    required this.canEdit,
    required this.onSave,
  });

  @override
  State<_SetupTab> createState() => _SetupTabState();
}

class _SetupTabState extends State<_SetupTab> {
  late final TextEditingController _name;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _industry;
  late final TextEditingController _period;
  late final TextEditingController _currency;
  late final TextEditingController _employees;
  late final TextEditingController _revenue;
  late final TextEditingController _units;
  late final TextEditingController _locations;
  late final TextEditingController _boundary;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.setup;
    _name = TextEditingController(text: s.companyName);
    _country = TextEditingController(text: s.countryCode);
    _city = TextEditingController(text: s.city);
    _industry = TextEditingController(text: s.industry);
    _period = TextEditingController(text: s.period);
    _currency = TextEditingController(text: s.currency);
    _employees = TextEditingController(text: s.employeeCount.toString());
    _revenue = TextEditingController(text: s.revenue.toString());
    _units = TextEditingController(text: s.unitsProduced.toString());
    _locations = TextEditingController(text: s.locationCount.toString());
    _boundary = TextEditingController(text: s.boundaryNotes);
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _city.dispose();
    _industry.dispose();
    _period.dispose();
    _currency.dispose();
    _employees.dispose();
    _revenue.dispose();
    _units.dispose();
    _locations.dispose();
    _boundary.dispose();
    super.dispose();
  }

  void _help(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _info(String message) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 20),
      onPressed: () => _help(context, 'Pojašnjenje', message),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Future<void> _save() async {
    final emp = int.tryParse(_employees.text.trim()) ?? 0;
    final rev = double.tryParse(_revenue.text.trim().replaceAll(',', '.')) ?? 0;
    final units = double.tryParse(_units.text.trim().replaceAll(',', '.')) ?? 0;
    final loc = int.tryParse(_locations.text.trim()) ?? 1;

    final next = CarbonCompanySetup(
      companyId: widget.setup.companyId,
      reportingYear: widget.setup.reportingYear,
      plantKey: widget.setup.plantKey,
      companyName: _name.text.trim(),
      countryCode: _country.text.trim().toUpperCase(),
      city: _city.text.trim(),
      industry: _industry.text.trim(),
      period: _period.text.trim(),
      currency: _currency.text.trim(),
      employeeCount: emp,
      revenue: rev,
      unitsProduced: units,
      locationCount: loc,
      boundaryNotes: _boundary.text.trim(),
    );

    setState(() => _saving = true);
    await widget.onSave(next);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final sum = widget.summary;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Prvo unesite kontekst kompanije za ${_setupYear()}.',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        _lockedRow(
          context,
          'Ključ obračuna (izvedeno)',
          widget.setup.reportingKey,
          'countryCode + godina; koristi se u izvještajima.',
        ),
        const Divider(height: 24),
        _field(
          label: 'Naziv kompanije',
          c: _name,
          hint: 'npr. Operonix d.o.o.',
          help:
              'Službeni naziv za izvještaje. Može se razlikovati od šifre u sistemu.',
          enabled: widget.canEdit,
          trailing: _info('Obavezno za smislen izvoz i PDF.'),
        ),
        _field(
          label: 'Država (ISO)',
          c: _country,
          hint: 'BA',
          help: 'Dvoslovni kod države za referencu faktora.',
          enabled: widget.canEdit,
        ),
        _field(
          label: 'Grad / lokacija',
          c: _city,
          hint: 'npr. Sarajevo',
          enabled: widget.canEdit,
        ),
        _field(
          label: 'Industrija / djelatnost',
          c: _industry,
          hint: 'npr. proizvodnja ambalaže',
          enabled: widget.canEdit,
        ),
        _field(
          label: 'Period',
          c: _period,
          hint: 'Godišnji',
          enabled: widget.canEdit,
        ),
        _field(
          label: 'Valuta',
          c: _currency,
          hint: 'BAM',
          enabled: widget.canEdit,
        ),
        _field(
          label: 'Broj zaposlenih',
          c: _employees,
          hint: 'npr. 45',
          help: 'Za intenzitet tCO2e / zaposlenog.',
          enabled: widget.canEdit,
          keyboard: TextInputType.number,
        ),
        _field(
          label: 'Prihod (u valuti)',
          c: _revenue,
          hint: 'npr. 1250000',
          help: 'Za intenzitet po prihodu ako je unesen.',
          enabled: widget.canEdit,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        _field(
          label: 'Proizvedene jedinice (kom)',
          c: _units,
          hint: 'npr. 120000',
          help: 'Za kg CO2e po jedinici proizvoda.',
          enabled: widget.canEdit,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        _field(
          label: 'Broj lokacija',
          c: _locations,
          hint: '1',
          enabled: widget.canEdit,
          keyboard: TextInputType.number,
        ),
        _field(
          label: 'Granice obračuna (napomena)',
          c: _boundary,
          hint: 'Glavni pogon, skladište, vozila…',
          enabled: widget.canEdit,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Text(
          'Izračun (zaključano)',
          style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary),
        ),
        const SizedBox(height: 8),
        _lockedRow(
          context,
          'Ukupno tCO2e (iz aktivnosti)',
          sum == null ? '—' : sum.totalTCO2e.toStringAsFixed(3),
          'Automatski zbroj uključenih redova × faktori.',
        ),
        _lockedRow(
          context,
          'tCO2e / zaposlenog',
          sum == null || widget.setup.employeeCount <= 0
              ? '—'
              : sum.perEmployeeTCO2e.toStringAsFixed(4),
          'Ukupno / broj zaposlenih.',
        ),
        _lockedRow(
          context,
          'kgCO2e / jedinici',
          sum == null || widget.setup.unitsProduced <= 0
              ? '—'
              : sum.perUnitKgCo2e.toStringAsFixed(4),
          'Ukupno kg / broj jedinica.',
        ),
        if (widget.canEdit) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Spremi postavke'),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Samo pregled: unos imaju Admin, menadžer proizvodnje i '
              'menadžer održavanja.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  int _setupYear() => widget.setup.reportingYear;

  Widget _field({
    required String label,
    required TextEditingController c,
    String? hint,
    String? help,
    bool enabled = true,
    TextInputType? keyboard,
    int maxLines = 1,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: help != null ? _info(help) : trailing,
        ),
      ),
    );
  }

  Widget _lockedRow(
    BuildContext context,
    String label,
    String value,
    String help,
  ) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: bg,
          suffixIcon: _info(help),
        ),
        child: Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

// --- Tab 2 ---
class _QuotasTab extends StatefulWidget {
  final CarbonQuotaSettings quotas;
  final CarbonDashboardSummary? summary;
  final bool canEdit;
  final Future<void> Function(CarbonQuotaSettings) onSave;

  const _QuotasTab({
    super.key,
    required this.quotas,
    required this.summary,
    required this.canEdit,
    required this.onSave,
  });

  @override
  State<_QuotasTab> createState() => _QuotasTabState();
}

class _QuotasTabState extends State<_QuotasTab> {
  late final TextEditingController _baseYear;
  late final TextEditingController _baseT;
  late final TextEditingController _redPct;
  late final TextEditingController _absCap;
  late final TextEditingController _intEmp;
  late final TextEditingController _intUnit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.quotas;
    _baseYear = TextEditingController(text: q.baselineYear.toString());
    _baseT = TextEditingController(text: q.baselineEmissionsTCO2e.toString());
    _redPct = TextEditingController(text: q.reductionTargetPercent.toString());
    _absCap = TextEditingController(text: q.absoluteQuotaTCO2e.toString());
    _intEmp = TextEditingController(
      text: q.intensityTargetPerEmployee.toString(),
    );
    _intUnit = TextEditingController(text: q.intensityTargetPerUnit.toString());
  }

  @override
  void dispose() {
    _baseYear.dispose();
    _baseT.dispose();
    _redPct.dispose();
    _absCap.dispose();
    _intEmp.dispose();
    _intUnit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = CarbonQuotaSettings(
      companyId: widget.quotas.companyId,
      reportingYear: widget.quotas.reportingYear,
      baselineYear: int.tryParse(_baseYear.text.trim()) ?? 0,
      baselineEmissionsTCO2e:
          double.tryParse(_baseT.text.trim().replaceAll(',', '.')) ?? 0,
      reductionTargetPercent:
          double.tryParse(_redPct.text.trim().replaceAll(',', '.')) ?? 0,
      absoluteQuotaTCO2e:
          double.tryParse(_absCap.text.trim().replaceAll(',', '.')) ?? 0,
      intensityTargetPerEmployee:
          double.tryParse(_intEmp.text.trim().replaceAll(',', '.')) ?? 0,
      intensityTargetPerUnit:
          double.tryParse(_intUnit.text.trim().replaceAll(',', '.')) ?? 0,
    );
    setState(() => _saving = true);
    await widget.onSave(q);
    if (mounted) setState(() => _saving = false);
  }

  void _help(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _quotaInfo(String message) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 20),
      onPressed: () => _help('Pojašnjenje', message),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sum = widget.summary;
    final q = widget.quotas;
    final targetRed = CarbonCalculationService.targetFromReductionTCO2e(q);
    final eff = CarbonCalculationService.effectiveQuotaTCO2e(q);
    final currentT = sum?.totalTCO2e ?? 0;
    final dev = eff > 0 ? (currentT - eff) : 0.0;
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Ovdje postavljate referentnu godinu, bazne emisije i ciljeve. Donji dio je '
          'automatski izračun iz unesenih aktivnosti i ovih brojki. Ikone (i) daju primjere '
          'i značenje pojmova — korisno ako tim tek uvodi GHG praćenje.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseYear,
          enabled: widget.canEdit,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Bazna godina',
            hintText: 'npr. 2022',
            suffixIcon: _quotaInfo(
              'Što unijeti\n'
              'Godinu za koju imate pouzdan, dokumentiran ukupni iznos emisija cijele '
              'organizacije (ili granice koju pratite u modulu).\n\n'
              'Primjer: ako je vaš prvi GHG inventar bio za 2022., unesite 2022.\n\n'
              'Zašto: od te godine sustav računa koliki bi trebao biti cilj smanjenja '
              'do tekuće izvještajne godine (godina u traci aplikacije).',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _baseT,
          enabled: widget.canEdit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Bazne emisije (tCO2e)',
            hintText: 'ukupno u baznoj godini',
            suffixIcon: _quotaInfo(
              'Što unijeti\n'
              'Ukupne godišnje emisije u tonaama CO2e (CO₂-ekvivalent) za baznu godinu — '
              'isti obuhvat (scope 1/2/3) koji kasnije pratite kroz aktivnosti.\n\n'
              'Primjer: inventar kaže 1 250 tCO2e za 2022. → unesite 1250 (ili 1250,5).\n\n'
              'Jedinica: tCO2e (tone). Ako imate samo kg, podijelite s 1000.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _redPct,
          enabled: widget.canEdit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Cilj smanjenja (%) do tekuće godine',
            hintText: 'npr. 10',
            suffixIcon: _quotaInfo(
              'Što znači\n'
              'Koliko želite smanjiti emisije u odnosu na baznu godinu, izraženo u postotku. '
              'Primjenjuje se na tekuću izvještajnu godinu (izbornik godine u traci).\n\n'
              'Primjer: baza 2022. = 1000 t, cilj 10% smanjenja → ciljna razina je 900 t '
              '(pojednostavljeno; točan izračun vidi zaključano polje ispod).\n\n'
              'Ako ne želite postotak, ostavite 0 i koristite apsolutnu kvotu ispod.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _absCap,
          enabled: widget.canEdit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Apsolutna interna kvota (tCO2e), opcionalno',
            hintText: '0 = koristi % cilj',
            suffixIcon: _quotaInfo(
              'Što unijeti\n'
              'Interni „ceiling” u tonaama CO2e za tekuću godinu. Ako je broj veći od 0, '
              'ima prednost pred ciljem iz postotka.\n\n'
              'Primjer: regulator ili odbor kaže „maksimalno 800 t ove godine” → unesite 800. '
              'Ako želite samo postotak od baze, unesite 0.\n\n'
              'Efektivna kvota u zaključanim poljima pokazuje što sustav stvarno koristi.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _intEmp,
          enabled: widget.canEdit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Ciljni intenzitet tCO2e / zaposlenom',
            suffixIcon: _quotaInfo(
              'Što unijeti\n'
              'Vaš ciljni prag: koliko tCO2e smije pasti na jednog zaposlenog (ili želite '
              'postići). Služi za usporedbu s brojem koji modul izračuna iz Postavki '
              '(broj zaposlenih) i ukupnih emisija.\n\n'
              'Primjer: cilj 4,5 tCO2e/zaposlenom — unesite 4.5. Ako ne pratite ovaj KPI, '
              'ostavite 0.\n\n'
              'Ne mijenja automatski kvotu; to je referenca za vas i reviziju.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _intUnit,
          enabled: widget.canEdit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Ciljni intenzitet kgCO2e / jedinici',
            suffixIcon: _quotaInfo(
              'Što unijeti\n'
              'Ciljni prag kg CO2e po jedinici proizvoda (iz Postavki — „proizvedene jedinice”). '
              'Uspoređuje se s izračunom ukupnih kg / broj jedinica.\n\n'
              'Primjer: cilj 2,1 kg CO2e po komadu — unesite 2.1.\n\n'
              'Ako ne proizvodite jedinstvenu „jedinicu” ili ne želite ovaj KPI, ostavite 0.',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Izračun (zaključano)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _decorBox(
          bg,
          'Aktuelne emisije (tCO2e)',
          sum == null ? '—' : currentT.toStringAsFixed(3),
          help:
              'Zbroj svih aktivnosti koje imaju uključen „Uključi u zbroj” i pozitivnu količinu, '
              'za odabranu godinu, putem emisijskih faktora (kg → t).\n\n'
              'Primjer: tri reda struje i jedan gorivo, svi uključeni → zbroj njihovih tCO2e ovdje.',
        ),
        _decorBox(
          bg,
          'Cilj iz % smanjenja (tCO2e)',
          targetRed <= 0 ? '—' : targetRed.toStringAsFixed(3),
          help:
              'Automatski: bazne emisije × (1 − postotak/100). Ne koristi apsolutnu kvotu.\n\n'
              'Primjer: baza 1000 t, cilj 10% → oko 900 t (ovisno o zaokruživanju u prikazu).',
        ),
        _decorBox(
          bg,
          'Efektivna kvota (tCO2e)',
          eff <= 0 ? '—' : eff.toStringAsFixed(3),
          help:
              'Pravilo: ako je „apsolutna kvota” > 0, ona je limit; inače koristi se cilj iz %.\n\n'
              'Primjer: apsolutna 800 t i cilj iz % 900 t → efektivno 800 t.',
        ),
        _decorBox(
          bg,
          'Odstupanje od kvote (+ = iznad)',
          eff <= 0 ? '—' : dev.toStringAsFixed(3),
          help:
              'Aktuelne emisije minus efektivna kvota.\n\n'
              'Primjer: aktuelno 950 t, kvota 900 t → +50 t (iznad cilja). '
              'Negativno znači ispod kvote (rezerva).',
        ),
        if (widget.canEdit)
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Spremi kvote'),
          ),
      ],
    );
  }

  Widget _decorBox(Color bg, String label, String value, {String? help}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: bg,
          suffixIcon: help != null ? _quotaInfo(help) : null,
        ),
        child: Text(value),
      ),
    );
  }
}

// --- Tab 3 ---
class _ActivitiesTab extends StatelessWidget {
  final String companyId;
  final int reportingYear;
  final List<CarbonActivityLine> activities;
  final Map<String, CarbonEmissionFactor> factors;
  final bool canEdit;
  final String userId;
  final CarbonFirestoreService service;
  final VoidCallback onChanged;

  const _ActivitiesTab({
    required this.companyId,
    required this.reportingYear,
    required this.activities,
    required this.factors,
    required this.canEdit,
    required this.userId,
    required this.service,
    required this.onChanged,
  });

  String _nextRowId() {
    var maxN = 0;
    for (final a in activities) {
      final m = RegExp(r'^A(\d+)$').firstMatch(a.rowId.trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return 'A${(maxN + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _openEditor(
    BuildContext context,
    CarbonActivityLine? existing,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CarbonActivityLineEditorSheet(
        hostContext: context,
        companyId: companyId,
        reportingYear: reportingYear,
        userId: userId,
        service: service,
        factors: factors,
        existing: existing,
        nextRowId: _nextRowId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Lista aktivnosti',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: 'Kako rade aktivnosti',
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('Aktivnosti'),
                      content: SingleChildScrollView(
                        child: Text(
                          'Svaki red je jedna stavka (npr. struja, gorivo, prijevoz). Prekidač '
                          '„Uključi u zbroj” odnosi se samo na red koji uređujete. Ikone (i) uz '
                          'polja sadrže primjere i pojašnjenja.',
                          style: Theme.of(dctx).textTheme.bodyMedium,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Zatvori'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (canEdit)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FilledButton.icon(
                onPressed: factors.isEmpty
                    ? null
                    : () => _openEditor(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Nova aktivnost'),
              ),
            ),
          ),
        Expanded(
          child: activities.isEmpty
              ? const Center(
                  child: Text('Nema aktivnosti. Dodajte redove s količinama.'),
                )
              : ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (ctx, i) {
                    final a = activities[i];
                    final kg = CarbonCalculationService.lineKgCo2e(a, factors);
                    final pk = a.plantKey.trim();
                    final prod = a.productId.trim();
                    final pcode = a.productCode.trim();
                    final plab = a.productLabel.trim();
                    String productLine() {
                      if (prod.isEmpty && pcode.isEmpty && plab.isEmpty) {
                        return '';
                      }
                      if (pcode.isNotEmpty && plab.isNotEmpty) {
                        return 'Proizvod: $plab · šifra $pcode';
                      }
                      if (plab.isNotEmpty) return 'Proizvod: $plab';
                      if (pcode.isNotEmpty) return 'Proizvod: šifra $pcode';
                      return 'Proizvod: (povezano — otvorite uređivanje za prikaz iz kataloga)';
                    }

                    final subParts = <String>[
                      '${a.quantity} ${a.unit} • ${a.factorKey}',
                      if (pk.isNotEmpty) 'Pogon: $pk',
                      if (prod.isNotEmpty || pcode.isNotEmpty || plab.isNotEmpty)
                        productLine(),
                      if (a.productOutputQty > 0)
                        'Proizvedeno (uz red): ${a.productOutputQty}',
                      '→ ${kg.toStringAsFixed(1)} kg CO2e',
                    ];
                    return Card(
                      child: ListTile(
                        title: Text('${a.rowId} • ${a.description}'),
                        subtitle: Text(subParts.join('\n')),
                        isThreeLine: true,
                        trailing: canEdit
                            ? IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openEditor(context, a),
                              )
                            : null,
                        onTap: canEdit ? () => _openEditor(context, a) : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// --- Tab 4 ---
class _FactorsTab extends StatelessWidget {
  final String companyId;
  final int reportingYear;
  final Map<String, CarbonEmissionFactor> factors;
  final bool isAdmin;
  final CarbonFirestoreService service;
  final Future<void> Function() onSaved;

  const _FactorsTab({
    required this.companyId,
    required this.reportingYear,
    required this.factors,
    required this.isAdmin,
    required this.service,
    required this.onSaved,
  });

  Future<void> _syncReferenceFactors(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Preuzimanje s mreže (DEFRA, OWID)…')),
            ],
          ),
        ),
      ),
    );
    try {
      final res = await service.syncReferenceEmissionFactors(
        companyId: companyId,
        reportingYear: reportingYear,
      );
      await onSaved();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final extra = res.warnings.isEmpty
          ? ''
          : ' ${res.warnings.join(' ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.upserted == 0
                ? 'Nema zapisa za upis.'
                : 'Sinkronizirano faktora: ${res.upserted}.$extra',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  String _statusLabel(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'reference') return 'Referentno';
    if (s == 'imported') return 'Uvezeno';
    if (s == 'override') return 'Kompanija';
    if (s == 'proxy') return 'Zadano (proxy)';
    if (s.isEmpty || s == 'default') return 'Zadano';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final entries = factors.values.toList()
      ..sort((a, b) => a.factorKey.compareTo(b.factorKey));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Katalog faktora',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: 'O referentnim faktorima i izvorima',
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('Referentni faktori'),
                      content: SingleChildScrollView(
                        child: Text(
                          'Faktori se temelje na međunarodno referentnim vrijednostima. '
                          'Izmjena faktora u aplikaciji nije dozvoljena.\n\n'
                          'Izvori u katalogu:\n'
                          '• Our World in Data / Ember — intenzitet električne energije za BiH (mrežni CSV)\n'
                          '• UK Government / DEFRA — GHG Conversion Factors 2025 flat XLSX '
                          '(gorivo, transport, voda, let)\n'
                          '• Otpad (tonne) — iste UK vrijednosti kao u ugrađenom katalogu '
                          'do potpunog mapiranja DEFRA redova',
                          style: Theme.of(dctx).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Zatvori'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: FilledButton.icon(
              onPressed: () => _syncReferenceFactors(context),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Import novih faktora'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Import referentnih faktora može pokrenuti samo Admin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final f = entries[i];
              final src = f.sourceName.trim();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(f.factorKey),
                  subtitle: Text(
                    '${f.scope} • ${f.activity} • ${f.unit}\n'
                    'kg CO2e / j.: ${f.factorKgCo2ePerUnit.toStringAsFixed(5)}'
                    '${src.isEmpty ? '' : '\nIzvor: $src'}',
                  ),
                  isThreeLine: true,
                  trailing: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      _statusLabel(f.factorStatus),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Tab 5 ---
class _DashboardTab extends StatelessWidget {
  final CarbonCompanySetup setup;
  final CarbonDashboardSummary? summary;
  final CarbonQuotaSettings quotas;
  final List<CarbonActivityLine> activities;
  final Map<String, CarbonEmissionFactor> factors;

  const _DashboardTab({
    required this.setup,
    required this.summary,
    required this.quotas,
    required this.activities,
    required this.factors,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (s == null) {
      return const Center(child: Text('Nema podataka za pregled.'));
    }

    final byPlant = CarbonCalculationService.rollupsByPlant(
      activities: activities,
      factorsByKey: factors,
    );
    final byProduct = CarbonCalculationService.rollupsByProduct(
      activities: activities,
      factorsByKey: factors,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Pregled za ${setup.companyName} • ${setup.reportingYear}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Kompanijski ukupni tCO2e uključuje sve uključene aktivnosti za godinu. '
          'Ispod su razrade po pogonu (plantKey na aktivnosti) i po proizvodu ako ste '
          'unijeli ID proizvoda na redovima.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _tile(bg, 'Ukupno', '${s.totalTCO2e.toStringAsFixed(3)} tCO2e'),
        _tile(bg, 'Scope 1', '${(s.scope1Kg / 1000).toStringAsFixed(3)} t'),
        _tile(bg, 'Scope 2', '${(s.scope2Kg / 1000).toStringAsFixed(3)} t'),
        _tile(bg, 'Scope 3', '${(s.scope3Kg / 1000).toStringAsFixed(3)} t'),
        _tile(
          bg,
          'Aktivni redovi / s količinom',
          '${s.includedActivityCount} / ${s.rowsWithQuantity}',
        ),
        _tile(
          bg,
          'tCO2e / zaposlenog',
          setup.employeeCount <= 0
              ? '—'
              : s.perEmployeeTCO2e.toStringAsFixed(4),
        ),
        _tile(
          bg,
          'kgCO2e / jedinici',
          setup.unitsProduced <= 0 ? '—' : s.perUnitKgCo2e.toStringAsFixed(4),
        ),
        if (setup.revenue > 0)
          _tile(
            bg,
            'tCO2e / 1000 ${setup.currency} prihoda',
            s.per1000RevenueTCO2e.toStringAsFixed(4),
          ),
        const Divider(height: 32),
        _tile(
          bg,
          'Efektivna kvota',
          CarbonCalculationService.effectiveQuotaTCO2e(quotas) <= 0
              ? '—'
              : '${CarbonCalculationService.effectiveQuotaTCO2e(quotas).toStringAsFixed(3)} t',
        ),
        const Divider(height: 32),
        Text(
          'Razrada po pogonima',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (byPlant.isEmpty)
          Text(
            'Nema aktivnosti s izračunatim emisijama za ovu godinu.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              columns: const [
                DataColumn(label: Text('Pogon')),
                DataColumn(label: Text('tCO2e'), numeric: true),
                DataColumn(label: Text('Redova'), numeric: true),
              ],
              rows: [
                for (final p in byPlant)
                  DataRow(
                    cells: [
                      DataCell(Text(p.displayPlant)),
                      DataCell(Text(p.totalTCO2e.toStringAsFixed(3))),
                      DataCell(Text('${p.lineCount}')),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Razrada po proizvodu',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Samo redovi s odabranim proizvodom iz šifrarnika ulaze ovdje. Ostale emisije '
          'ostaju u kompanijskom ukupnom zbroju. Opcionalno „proizvedeno uz red” ne dira '
          'polje „Proizvedene jedinice” u Postavkama.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (byProduct.isEmpty)
          Text(
            'Još nema dodijele proizvodu. U tabu Aktivnosti odaberite proizvod (šifra/naziv) '
            'na redovima koje želite pripisati proizvodu.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              columns: const [
                DataColumn(label: Text('Proizvod')),
                DataColumn(label: Text('Σ proizv. kol.'), numeric: true),
                DataColumn(label: Text('tCO2e'), numeric: true),
                DataColumn(label: Text('Redova'), numeric: true),
              ],
              rows: [
                for (final p in byProduct)
                  DataRow(
                    cells: [
                      DataCell(Text(p.displayTitle)),
                      DataCell(
                        Text(
                          p.totalProductOutputQty > 0
                              ? p.totalProductOutputQty.toStringAsFixed(2)
                              : '—',
                        ),
                      ),
                      DataCell(Text(p.totalTCO2e.toStringAsFixed(3))),
                      DataCell(Text('${p.lineCount}')),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(Color bg, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: bg,
        ),
        child: Text(value),
      ),
    );
  }
}

// --- Tab 6 ---
class _ExportTab extends StatelessWidget {
  final CarbonCompanySetup setup;
  final List<CarbonActivityLine> activities;
  final Map<String, CarbonEmissionFactor> factors;
  final CarbonQuotaSettings quotas;
  final CarbonDashboardSummary? summary;
  final String userId;
  final CarbonFirestoreService auditService;

  const _ExportTab({
    required this.setup,
    required this.activities,
    required this.factors,
    required this.quotas,
    required this.summary,
    required this.userId,
    required this.auditService,
  });

  @override
  Widget build(BuildContext context) {
    final plantRoll = CarbonCalculationService.rollupsByPlant(
      activities: activities,
      factorsByKey: factors,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Izvezite podatke za arhivu ili daljnju obradu. CSV odgovara “flat” strukturi za uvoz.',
        ),
        const SizedBox(height: 8),
        const Text(
          'PDF sažetak i zbirni PDF-ovi (po pogonu / po proizvodu): prvo se otvara pregled '
          '(štampa / dijeljenje / spremanje) — ništa se ne šalje odmah iz aplikacije.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        const Text(
          'Zbirni PDF po pogonu: tablica GHG scope 1/2/3 za svaki pogon. Po proizvodu: isti '
          'oblik kao ukupno za kompaniju, zatim tablice po pogonu (proizvod, šifra, scopeovi). '
          '„Podijeli CSV” i dalje šalje flat CSV za Excel.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            final csv = CarbonExportService.buildCsv(
              setup: setup,
              activities: activities,
              factorsByKey: factors,
            );
            final fn = 'karbon_${setup.companyId}_${setup.reportingYear}.csv';
            try {
              await CarbonExportService.shareCsv(fileName: fn, csvContent: csv);
              await auditService.logReportEvent(
                companyId: setup.companyId,
                reportingYear: setup.reportingYear,
                userId: userId,
                action: 'export_csv_shared',
                detail: fn,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Izvoz: $e')));
              }
            }
          },
          icon: const Icon(Icons.table_chart),
          label: const Text('Podijeli CSV'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: summary == null
              ? null
              : () async {
                  try {
                    await CarbonExportService.previewSummaryPdf(
                      setup: setup,
                      summary: summary!,
                      quotas: quotas,
                      plantRollups:
                          plantRoll.isEmpty ? null : plantRoll,
                    );
                    await auditService.logReportEvent(
                      companyId: setup.companyId,
                      reportingYear: setup.reportingYear,
                      userId: userId,
                      action: 'export_pdf_preview',
                      detail: plantRoll.isEmpty
                          ? 'Sažetak PDF'
                          : 'Sažetak PDF + pogoni',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('PDF: $e')));
                    }
                  }
                },
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(
            plantRoll.isEmpty
                ? 'PDF pregled (sažetak)'
                : 'PDF pregled (sažetak + pogoni)',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () async {
            final base =
                'karbon_po_pogonu_${setup.companyId}_${setup.reportingYear}';
            try {
              await CarbonExportService.previewPlantRollupPdf(
                setup: setup,
                activities: activities,
                factorsByKey: factors,
              );
              await auditService.logReportEvent(
                companyId: setup.companyId,
                reportingYear: setup.reportingYear,
                userId: userId,
                action: 'export_csv_plant_preview',
                detail: '$base.pdf',
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Izvoz: $e')));
              }
            }
          },
          icon: const Icon(Icons.factory_outlined),
          label: const Text('PDF zbroj po pogonu (pregled)'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () async {
            final base =
                'karbon_po_proizvodu_${setup.companyId}_${setup.reportingYear}';
            try {
              await CarbonExportService.previewProductRollupByPlantPdf(
                setup: setup,
                activities: activities,
                factorsByKey: factors,
              );
              await auditService.logReportEvent(
                companyId: setup.companyId,
                reportingYear: setup.reportingYear,
                userId: userId,
                action: 'export_csv_product_preview',
                detail: '$base.pdf',
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Izvoz: $e')));
              }
            }
          },
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('PDF zbroj po proizvodu (pregled)'),
        ),
      ],
    );
  }
}

/// Sažetak aktuelne EU regulative relevantne za izvještavanje o emisijama (informativno).
class _RegulatoryTab extends StatelessWidget {
  const _RegulatoryTab();

  Future<void> _open(BuildContext context, String url) async {
    final u = Uri.parse(url);
    try {
      var ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(u, mode: LaunchMode.inAppWebView);
      }
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nije moguće otvoriti link na ovom uređaju.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri otvaranju linka: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Regulativa (EU) — informativni pregled',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Ovo nije pravni savjet. Za obaveze vaše organizacije koristite interni pravni '
          'tim ili savjetnika; ovdje su sažeti naslovi korisni uz modul karbonskog otiska.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _regCard(
          context,
          title: 'CSRD — Direktiva o izvještavanju o održivosti',
          body:
              'Direktiva (EU) 2022/2464 (izmijenjena Direktiva o računovodstvenim iskazima) '
              'uvodi detaljnije nefinansijsko izvještavanje za velike i srednje kapitalne '
              'društva u EU-u, uključujući klimu i druge ESG teme. Primjena ovisi o veličini '
              'i statusu entiteta (procjena „velike” / „srednje” prema kriterijima EU-a).',
          url:
              'https://eur-lex.europa.eu/legal-content/HR/TXT/?uri=CELEX:32022L2464',
          linkLabel: 'EUR-Lex (HR): 2022/2464',
        ),
        const SizedBox(height: 12),
        _regCard(
          context,
          title: 'ESRS — Europski standardi izvještavanja o održivosti',
          body:
              'Delegated akti Komisije (npr. 2023/2772) donose ESRS standarde koje treba '
              'koristiti uz CSRD. Oni preciziraju metrike i strukturu (uključivo emisije GHG '
              'po scope-ovima gdje je primjenjivo).',
          url:
              'https://eur-lex.europa.eu/legal-content/HR/TXT/?uri=CELEX:32023R2772',
          linkLabel: 'EUR-Lex: delegirani akt ESRS',
        ),
        const SizedBox(height: 12),
        _regCard(
          context,
          title: 'EU ETS — Tržište ugljika za instalacije',
          body:
              'Direktiva 2003/87/EZ (s izmjenama) uspostavlja sistem trgovanja emisijama za '
              'energetiku, industriju i zrakoplovstvo (EU ETS). Ako ste operator instalacije '
              'pod obuhvatom, obratite se obvezama dozvola za emisije — odvojeno od ovog '
              'internog modula karbonskog otiska.',
          url:
              'https://climate.ec.europa.eu/eu-action/eu-emissions-trading-system-eu-ets_hr',
          linkLabel: 'European Commission: EU ETS',
          bodyInInfoDialog: true,
        ),
        const SizedBox(height: 12),
        _regCard(
          context,
          title: 'CBAM — mehanizam prilagodbe na granici',
          body:
              'Uredba (EU) 2023/956 uvodi postepeno izvještavanje i naknadu za uvoz određenih '
              'proizvoda s intenzitetom ugljika (čelik, željezo, cement, gnojivo, aluminij, '
              'električna energija…). Ako uvožete u EU, provjerite obuhvat i obveze izvještaja.',
          url:
              'https://taxation-customs.ec.europa.eu/carbon-border-adjustment-mechanism_hr',
          linkLabel: 'European Commission: CBAM',
        ),
        const SizedBox(height: 12),
        _regCard(
          context,
          title: 'Fit for 55',
          body:
              'Paket politika EU-a za smanjenje neto emisija najmanje 55% do 2030. u odnosu na '
              '1990. godinu. Povezuje ETS, energetsku učinkovitost, promet i druge sektore.',
          url: 'https://commission.europa.eu/strategy-and-policy/priorities-2019-2024/european-green-deal/delivering-european-green-deal/fit-55_hr',
          linkLabel: 'European Commission: Fit for 55',
        ),
      ],
    );
  }

  Widget _regCard(
    BuildContext context, {
    required String title,
    required String body,
    required String url,
    required String linkLabel,
    bool bodyInInfoDialog = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (bodyInInfoDialog)
                  IconButton(
                    tooltip: 'Detalji',
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: Text(title),
                          content: SingleChildScrollView(child: Text(body)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dctx),
                              child: const Text('Zatvori'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (!bodyInInfoDialog) ...[
              const SizedBox(height: 8),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _open(context, url),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(linkLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _carbonAuditActionLabelHr(String action) {
  switch (action) {
    case 'settings_saved':
      return 'Spremljene postavke izvještaja';
    case 'quotas_saved':
      return 'Spremljene kvote i ciljevi';
    case 'activity_created':
      return 'Dodana stavka aktivnosti';
    case 'activity_updated':
      return 'Ažurirana stavka aktivnosti';
    case 'factor_override_saved':
      return 'Izmijenjen faktor emisije';
    case 'factors_csv_imported':
      return 'Uvoz faktora iz CSV';
    case 'reference_factors_synced':
      return 'Import referentnih faktora';
    case 'export_csv_shared':
      return 'Podijeljen CSV izvještaj';
    case 'export_csv_plant_shared':
      return 'Podijeljen CSV zbroj po pogonu';
    case 'export_csv_plant_preview':
      return 'Pregled PDF-a (zbroj po pogonu, tablice scope)';
    case 'export_csv_product_shared':
      return 'Podijeljen CSV zbroj po proizvodu';
    case 'export_csv_product_preview':
      return 'Pregled PDF-a (zbroj po proizvodu, tablice po pogonu)';
    case 'export_pdf_preview':
      return 'Pregled PDF (sažetak)';
    default:
      return action;
  }
}

String _formatCarbonAuditDateTime(DateTime? t) {
  if (t == null) return '—';
  final d = t.day.toString().padLeft(2, '0');
  final m = t.month.toString().padLeft(2, '0');
  final y = t.year;
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$d.$m.$y $hh:$mm';
}

class _AuditLogTab extends StatefulWidget {
  final String companyId;
  final int reportingYear;
  final CarbonFirestoreService service;

  const _AuditLogTab({
    super.key,
    required this.companyId,
    required this.reportingYear,
    required this.service,
  });

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  StreamSubscription<List<CarbonAuditLogEntry>>? _sub;
  List<CarbonAuditLogEntry> _entries = [];

  ({
    DateTime? settingsUpdatedAt,
    String settingsUpdatedBy,
    DateTime? quotasUpdatedAt,
    String quotasUpdatedBy,
  })?
  _docHints;

  bool _metaLoading = true;
  String? _metaError;

  @override
  void initState() {
    super.initState();
    _loadDocHints();
    _sub = widget.service
        .watchAuditLog(
          companyId: widget.companyId,
          reportingYear: widget.reportingYear,
        )
        .listen(_onEntries);
  }

  Future<void> _loadDocHints() async {
    try {
      final h = await widget.service.loadPeriodDocumentUpdateHints(
        companyId: widget.companyId,
        reportingYear: widget.reportingYear,
      );
      if (!mounted) return;
      final ids = <String>{};
      for (final s in [h.settingsUpdatedBy, h.quotasUpdatedBy]) {
        if (UserDisplayLabel.looksLikeFirebaseUid(s)) ids.add(s);
      }
      await UserDisplayLabel.prefetchUids(FirebaseFirestore.instance, ids);
      if (!mounted) return;
      setState(() {
        _docHints = h;
        _metaLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _metaError = e.toString();
        _metaLoading = false;
      });
    }
  }

  Future<void> _onEntries(List<CarbonAuditLogEntry> list) async {
    final ids = list
        .map((e) => e.userId)
        .where(UserDisplayLabel.looksLikeFirebaseUid)
        .toSet();
    await UserDisplayLabel.prefetchUids(FirebaseFirestore.instance, ids);
    if (!mounted) return;
    setState(() => _entries = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Widget _metaCard(BuildContext context, ThemeData theme) {
    if (_metaLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_metaError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_metaError!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    final h = _docHints!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zadnje izmjene dokumenata (Firestore)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Na dokumentima postavki i kvota i dalje postoje polja zadnjeg '
              'uređivanja; detaljni dnevnik ispod bilježi svaku radnju od '
              'uvođenja ove funkcije.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _metaRow(
              theme,
              'Postavke (carbon_settings)',
              h.settingsUpdatedAt,
              h.settingsUpdatedBy,
            ),
            const SizedBox(height: 8),
            _metaRow(
              theme,
              'Kvote (carbon_quotas)',
              h.quotasUpdatedAt,
              h.quotasUpdatedBy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(ThemeData theme, String title, DateTime? at, String by) {
    final label = UserDisplayLabel.labelForStored(by);
    return Text(
      '$title\n'
      '${_formatCarbonAuditDateTime(at)} • $label',
      style: theme.textTheme.bodyMedium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Povijest za godinu ${widget.reportingYear}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Svaka spremljena promjena postavki, kvota, aktivnosti, faktora ili '
          'izvoz generiše zapis s vremenom i korisnikom (ime ili email).',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _metaCard(context, theme),
        const SizedBox(height: 24),
        Text(
          'Dnevnik događaja',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_entries.isEmpty)
          Text(
            'Još nema zapisa u dnevniku za ovu godinu. Nakon prve izmjene ili '
            'izvoza pojavit će se ovdje.',
            style: theme.textTheme.bodyMedium,
          )
        else
          ..._entries.map((e) {
            final who = UserDisplayLabel.labelForStored(e.userId);
            final when = _formatCarbonAuditDateTime(e.createdAt);
            final title = _carbonAuditActionLabelHr(e.action);
            final detail = e.detail.trim().isEmpty ? null : e.detail.trim();
            final longDetail = detail != null && detail.length > 48;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(title),
                subtitle: Text([when, who, ?detail].join(' • ')),
                isThreeLine: longDetail,
              ),
            );
          }),
      ],
    );
  }
}
