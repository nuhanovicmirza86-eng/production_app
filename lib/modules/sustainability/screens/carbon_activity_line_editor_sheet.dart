import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../../production/products/services/product_lookup_service.dart';
import '../models/carbon_models.dart';
import '../services/carbon_firestore_service.dart';

/// Bottom sheet za unos/uređivanje jedne stavke aktivnosti. Kontroleri žive u [State]
/// da se [dispose] dogodi nakon zatvaranja sheeta — izbjegava assert na `_dependents`.
class CarbonActivityLineEditorSheet extends StatefulWidget {
  const CarbonActivityLineEditorSheet({
    super.key,
    required this.hostContext,
    required this.companyId,
    required this.reportingYear,
    required this.userId,
    required this.service,
    required this.factors,
    required this.existing,
    required this.nextRowId,
  });

  /// Kontekst roditelja (ekran) za dijaloge pomoći iznad sheeta.
  final BuildContext hostContext;
  final String companyId;
  final int reportingYear;
  final String userId;
  final CarbonFirestoreService service;
  final Map<String, CarbonEmissionFactor> factors;
  final CarbonActivityLine? existing;
  final String Function() nextRowId;

  @override
  State<CarbonActivityLineEditorSheet> createState() =>
      _CarbonActivityLineEditorSheetState();
}

class _PlantCatalogEntry {
  _PlantCatalogEntry({
    required this.plantKey,
    required this.plantCode,
    required this.displayLabel,
  });

  final String plantKey;
  final String plantCode;
  final String displayLabel;

  String get _haystack =>
      '${plantKey.toLowerCase()} ${plantCode.toLowerCase()} ${displayLabel.toLowerCase()}';

  bool matchesQuery(String q) {
    final n = q.trim().toLowerCase();
    if (n.isEmpty) return false;
    return _haystack.contains(n);
  }
}

class _CarbonActivityLineEditorSheetState
    extends State<CarbonActivityLineEditorSheet> {
  late final String _rowId;
  late final TextEditingController _plantC;
  /// Tekst za pretragu / prikaz „šifra · naziv” nakon odabira iz šifrarnika.
  late final TextEditingController _productSearchC;
  late final TextEditingController _productLabelC;
  late final TextEditingController _productOutputQtyC;
  late final TextEditingController _dateC;
  late final TextEditingController _typeC;
  late final TextEditingController _descC;
  late final TextEditingController _qtyC;
  late final TextEditingController _unitC;
  late final TextEditingController _evC;
  late final TextEditingController _notesC;
  late String _factorKey;
  final List<bool> _include = <bool>[true];

  final ProductLookupService _productLookup = ProductLookupService();
  final FocusNode _plantFocus = FocusNode();
  final FocusNode _productSearchFocus = FocusNode();

  String _catalogProductId = '';
  String _catalogProductCode = '';
  String _lastBoundProductSearchText = '';
  bool _suppressProductSearchListener = false;

  Timer? _productSearchDebounce;
  bool _productSearchLoading = false;
  List<ProductLookupItem> _productHits = <ProductLookupItem>[];

  List<_PlantCatalogEntry> _plantCatalog = const [];
  List<_PlantCatalogEntry> _plantHits = const [];

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String _plantLabelFromDoc(Map<String, dynamic> data, String docId) {
    final displayName = _s(data['displayName']);
    final defaultName = _s(data['defaultName']);
    final primaryName = _s(data['primaryName']);
    final plantCode = _s(data['plantCode']);
    final plantKey = _s(data['plantKey']);
    final base = displayName.isNotEmpty
        ? displayName
        : defaultName.isNotEmpty
            ? defaultName
            : primaryName.isNotEmpty
                ? primaryName
                : plantKey.isNotEmpty
                    ? plantKey
                    : docId;
    if (plantCode.isNotEmpty && base.isNotEmpty) {
      return '$base ($plantCode)';
    }
    return base.isEmpty ? docId : base;
  }

  void _sheetHelp(String title, String body) {
    showDialog<void>(
      context: widget.hostContext,
      builder: (dctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _infoIcon(String body) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 20),
      onPressed: () => _sheetHelp('Pojašnjenje', body),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Future<void> _loadPlantCatalog() async {
    final cid = widget.companyId.trim();
    if (cid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('company_plants')
          .where('companyId', isEqualTo: cid)
          .where('active', isEqualTo: true)
          .get();
      final docs = [...snap.docs];
      int orderOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        final o = d.data()['order'];
        if (o is int) return o;
        if (o is num) return o.toInt();
        return 0;
      }

      docs.sort((a, b) {
        final ao = orderOf(a);
        final bo = orderOf(b);
        if (ao != bo) return ao.compareTo(bo);
        final al = _plantLabelFromDoc(a.data(), a.id).toLowerCase();
        final bl = _plantLabelFromDoc(b.data(), b.id).toLowerCase();
        return al.compareTo(bl);
      });

      final list = <_PlantCatalogEntry>[];
      for (final d in docs) {
        final data = d.data();
        final key = _s(data['plantKey']).isNotEmpty ? _s(data['plantKey']) : d.id;
        final code = _s(data['plantCode']);
        list.add(
          _PlantCatalogEntry(
            plantKey: key,
            plantCode: code,
            displayLabel: _plantLabelFromDoc(data, d.id),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _plantCatalog = list);
      _refreshPlantHits();
    } catch (_) {
      // Šifrarnik pogona nije obavezan — ručni plantKey i dalje vrijedi.
    }
  }

  void _refreshPlantHits() {
    final q = _plantC.text.trim();
    if (q.isEmpty || _plantCatalog.isEmpty) {
      setState(() => _plantHits = const []);
      return;
    }
    final hits = _plantCatalog.where((e) => e.matchesQuery(q)).take(12).toList();
    setState(() => _plantHits = hits);
  }

  void _onPlantTextChanged() {
    if (!_plantFocus.hasFocus) return;
    _refreshPlantHits();
  }

  void _onPlantFocusChanged() {
    if (_plantFocus.hasFocus) {
      _refreshPlantHits();
    } else {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        if (!_plantFocus.hasFocus) {
          setState(() => _plantHits = const []);
        }
      });
    }
  }

  void _selectPlant(_PlantCatalogEntry e) {
    _plantC.text = e.plantKey;
    setState(() => _plantHits = const []);
    _plantFocus.unfocus();
  }

  void _setProductSearchText(String v) {
    _suppressProductSearchListener = true;
    _productSearchC.text = v;
    _suppressProductSearchListener = false;
  }

  Future<void> _hydrateExistingProduct() async {
    final ex = widget.existing;
    if (ex == null) return;
    final pid = ex.productId.trim();
    if (pid.isEmpty) return;

    final item = await _productLookup.getByProductId(
      companyId: widget.companyId,
      productId: pid,
      onlyActive: false,
    );
    if (!mounted) return;

    final code = ex.productCode.trim().isNotEmpty
        ? ex.productCode.trim()
        : (item?.productCode ?? '').trim();
    final name = ex.productLabel.trim().isNotEmpty
        ? ex.productLabel.trim()
        : (item?.productName ?? '').trim();

    setState(() {
      _catalogProductId = pid;
      _catalogProductCode = code;
      if (_productLabelC.text.trim().isEmpty && name.isNotEmpty) {
        _productLabelC.text = name;
      }
      final disp = code.isNotEmpty && name.isNotEmpty
          ? '$code · $name'
          : (name.isNotEmpty
              ? name
              : (code.isNotEmpty ? code : pid));
      _setProductSearchText(disp);
      _lastBoundProductSearchText = disp.trim();
    });
  }

  void _onProductSearchChanged() {
    if (_suppressProductSearchListener) return;
    _productSearchDebounce?.cancel();
    if (!_productSearchFocus.hasFocus) return;

    final raw = _productSearchC.text;
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _catalogProductId = '';
        _catalogProductCode = '';
        _lastBoundProductSearchText = '';
        _productHits = const [];
        _productSearchLoading = false;
      });
      return;
    }

    if (_catalogProductId.isNotEmpty &&
        q == _lastBoundProductSearchText.trim()) {
      return;
    }

    if (_catalogProductId.isNotEmpty) {
      setState(() {
        _catalogProductId = '';
        _catalogProductCode = '';
      });
    }

    setState(() => _productSearchLoading = true);

    _productSearchDebounce = Timer(const Duration(milliseconds: 280), () async {
      final companyId = widget.companyId.trim();
      if (companyId.isEmpty) {
        if (mounted) {
          setState(() {
            _productHits = const [];
            _productSearchLoading = false;
          });
        }
        return;
      }

      try {
        final results = await _productLookup.searchProducts(
          companyId: companyId,
          query: q,
          limit: 12,
        );
        if (!mounted) return;
        if (_productSearchC.text.trim() != q) return;
        setState(() {
          _productHits = results;
          _productSearchLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        if (_productSearchC.text.trim() != q) return;
        setState(() {
          _productHits = const [];
          _productSearchLoading = false;
        });
        if (widget.hostContext.mounted) {
          ScaffoldMessenger.of(widget.hostContext).showSnackBar(
            SnackBar(content: Text(AppErrorMapper.toMessage(e))),
          );
        }
      }
    });
  }

  void _onProductSearchFocusChanged() {
    if (!_productSearchFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        if (!_productSearchFocus.hasFocus) {
          setState(() {
            _productHits = const [];
            _productSearchLoading = false;
          });
        }
      });
    }
  }

  void _selectProduct(ProductLookupItem p) {
    _catalogProductId = p.productId;
    _catalogProductCode = p.productCode;
    _productLabelC.text = p.productName;
    final disp =
        p.productCode.isNotEmpty ? '${p.productCode} · ${p.productName}' : p.productName;
    _setProductSearchText(disp);
    _lastBoundProductSearchText = disp.trim();
    setState(() {
      _productHits = const [];
      _productSearchLoading = false;
    });
    _productSearchFocus.unfocus();
  }

  Future<void> _pickActivityDate() async {
    final y = widget.reportingYear;
    final initial = DateTime.tryParse(_dateC.text.trim()) ??
        DateTime(y, DateTime.now().month.clamp(1, 12), 15);
    final first = DateTime(y, 1, 1);
    final last = DateTime(y, 12, 31);

    final picked = await showDatePicker(
      context: widget.hostContext,
      initialDate: _clampDate(initial, first, last),
      firstDate: first,
      lastDate: last,
      helpText: 'Datum aktivnosti ($y)',
    );
    if (picked == null || !mounted) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _dateC.text = iso);
  }

  DateTime _clampDate(DateTime d, DateTime first, DateTime last) {
    if (d.isBefore(first)) return first;
    if (d.isAfter(last)) return last;
    return d;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _rowId = e?.rowId ?? widget.nextRowId();
    _include[0] = e?.include ?? true;
    _plantC = TextEditingController(text: e?.plantKey ?? '');
    _productSearchC = TextEditingController();
    _productLabelC = TextEditingController(text: e?.productLabel ?? '');
    _productOutputQtyC = TextEditingController(
      text: e != null && e.productOutputQty > 0
          ? e.productOutputQty.toString()
          : '',
    );
    _dateC = TextEditingController(text: e?.activityDate ?? '');
    _typeC = TextEditingController(text: e?.activityType ?? '');
    _descC = TextEditingController(text: e?.description ?? '');
    _qtyC = TextEditingController(
      text: e == null ? '' : e.quantity.toString(),
    );
    _unitC = TextEditingController(text: e?.unit ?? '');
    final keys = widget.factors.keys.toList()..sort();
    _factorKey = e?.factorKey ?? '';
    if (_factorKey.isEmpty && keys.isNotEmpty) _factorKey = keys.first;
    if (keys.isNotEmpty && !keys.contains(_factorKey)) _factorKey = keys.first;
    _evC = TextEditingController(text: e?.evidenceRef ?? '');
    _notesC = TextEditingController(text: e?.notes ?? '');

    _plantC.addListener(_onPlantTextChanged);
    _plantFocus.addListener(_onPlantFocusChanged);
    _productSearchC.addListener(_onProductSearchChanged);
    _productSearchFocus.addListener(_onProductSearchFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPlantCatalog();
        _hydrateExistingProduct();
      }
    });
  }

  @override
  void dispose() {
    _productSearchDebounce?.cancel();
    _plantC.removeListener(_onPlantTextChanged);
    _plantFocus.removeListener(_onPlantFocusChanged);
    _productSearchC.removeListener(_onProductSearchChanged);
    _productSearchFocus.removeListener(_onProductSearchFocusChanged);
    _plantFocus.dispose();
    _productSearchFocus.dispose();
    _plantC.dispose();
    _productSearchC.dispose();
    _productLabelC.dispose();
    _productOutputQtyC.dispose();
    _dateC.dispose();
    _typeC.dispose();
    _descC.dispose();
    _qtyC.dispose();
    _unitC.dispose();
    _evC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportY = widget.reportingYear;
    final keys = widget.factors.keys.toList()..sort();
    final f = widget.factors[_factorKey];
    final e = widget.existing;
    final kg = e == null && _qtyC.text.isEmpty
        ? 0.0
        : (double.tryParse(_qtyC.text.replaceAll(',', '.')) ?? 0) *
            (f?.factorKgCo2ePerUnit ?? 0);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              e == null ? 'Nova aktivnost' : 'Uredi ${e.rowId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              secondary: IconButton(
                icon: const Icon(Icons.info_outline, size: 22),
                onPressed: () => _sheetHelp(
                  'Uključi u zbroj',
                  'Ovaj prekidač mijenja samo aktivnost koju upravo uređujete '
                      '(npr. red A001), ne cijelu listu odjednom.\n\n'
                      'UKLJUČENO: emisije ovog reda ulaze u ukupni tCO2e na tabovima '
                      'Pregled i Kvote te u CSV izvoz (uključeni redovi).\n\n'
                      'ISKLJUČENO: red ostaje spremljen, ali se ne zbraja i ne izvozi '
                      'u CSV — npr. skica, duplikat, ili podatak samo za arhivu.\n\n'
                      'Primjer: imate privremeni red za test — isključite ga dok ne '
                      'potvrdite brojke.',
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              title: const Text('Uključi u zbroj'),
              subtitle: const Text(
                'Vrijedi samo za ovaj red. Isključeno = nema u zbroju niti u CSV izvozu.',
              ),
              value: _include[0],
              onChanged: (v) => setState(() => _include[0] = v),
            ),
            TextField(
              controller: _plantC,
              focusNode: _plantFocus,
              decoration: InputDecoration(
                labelText: 'Pogon (plantKey, šifrarnik)',
                hintText: 'Upišite šifru ili naziv — filtrira pogone',
                suffixIcon: _infoIcon(
                  'Odaberite pogon iz šifrarnika (filtrira se dok tipkate) ili '
                  'upišite vlastiti plantKey.\n\n'
                  'Koristi se za Pregled po pogonu i CSV zbrojeve.',
                ),
              ),
            ),
            if (_plantHits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _plantHits.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final row = _plantHits[i];
                        return ListTile(
                          dense: true,
                          title: Text(row.displayLabel),
                          subtitle: Text(
                            row.plantCode.isEmpty
                                ? 'plantKey: ${row.plantKey}'
                                : 'plantKey: ${row.plantKey} · šifra: ${row.plantCode}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectPlant(row),
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _productSearchC,
              focusNode: _productSearchFocus,
              decoration: InputDecoration(
                labelText: 'Proizvod (šifrarnik)',
                hintText: 'Tipkajte šifru ili naziv — filtrira katalog',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_productSearchLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    _infoIcon(
                      'Odaberite red iz liste: u polju ostaje „šifra · naziv” radi '
                      'lakšeg prepoznavanja. U pozadini se pamti tehnički ID (nije prikazan).\n\n'
                      'Obrišite polje ako ne želite dodjelu proizvodu.',
                    ),
                  ],
                ),
              ),
            ),
            if (_productHits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _productHits.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final p = _productHits[i];
                        return ListTile(
                          dense: true,
                          title: Text(p.productName),
                          subtitle: Text(
                            p.productCode.isNotEmpty
                                ? 'Šifra: ${p.productCode}'
                                : 'Bez šifre u katalogu',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectProduct(p),
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _productLabelC,
              decoration: InputDecoration(
                labelText: 'Naziv proizvoda (opcionalno)',
                hintText: 'za čitljivost u izvještajima',
                suffixIcon: _infoIcon(
                  'Popunjava se iz šifrarnika kad odaberete proizvod gore; možete i '
                  'ručno urediti.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _productOutputQtyC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Proizvedena količina uz ovaj red (opcionalno)',
                hintText: 'npr. kom proizvedeno u periodu retka',
                suffixIcon: _infoIcon(
                  'Za razradu po proizvodu (npr. koliko ste proizveli dok je trajala '
                  'ovdje unesena potrošnja).\n\n'
                  'Ne mijenja polje „Proizvedene jedinice” u Postavkama kompanije i '
                  'ne utječe na kg CO2e: emisija se i dalje računa samo iz polja '
                  '„Količina” ispod i emisijskog faktora.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateC,
              readOnly: true,
              onTap: _pickActivityDate,
              decoration: InputDecoration(
                labelText: 'Datum (YYYY-MM-DD)',
                hintText: 'Kliknite za kalendar',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kalendar',
                      icon: const Icon(Icons.calendar_today_outlined, size: 20),
                      onPressed: _pickActivityDate,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    _infoIcon(
                      'Odaberite datum u kalendaru — format je uvijek GGGG-MM-DD.\n\n'
                      'Ograničeno na izvještajnu godinu ($reportY).',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _typeC,
              decoration: InputDecoration(
                labelText: 'Tip aktivnosti',
                hintText: 'Electricity / Fuel / Freight…',
                suffixIcon: _infoIcon(
                  'Kratka kategorija radi grupiranja u izvještajima.\n\n'
                  'Primjeri: Electricity, Natural gas, Diesel, Freight, Business travel.\n\n'
                  'Može odgovarati nazivu u faktoru, ali ne mora — opis može biti '
                  'detaljniji u polju „Opis”.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descC,
              decoration: InputDecoration(
                labelText: 'Opis',
                hintText: 'Kupljena struja — glavni pogon',
                suffixIcon: _infoIcon(
                  'Tekst koji čita čovjek: što je točno potrošeno ili prevezeno.\n\n'
                  'Primjer: „Kupljena struja — glavna hala, Elektroprivreda, račun 45/2026” '
                  'ili „Dostava sirovine kamionom Sarajevo–Mostar”.\n\n'
                  'Pomaže pri reviziji uz polje Referenca dokaza.',
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Količina',
                hintText: 'npr. 125000',
                suffixIcon: _infoIcon(
                  'Ovo je količina za izračun emisije (potrošnja/udaljenost u jedinici faktora), '
                  'npr. kWh, litre, tkm — ne kompanijski zbroj „proizvedenih jedinica” iz Postavki.\n\n'
                  'Primjeri: 125000 kWh (struja), 2400 l (dizel), 8500 tkm (prijevoz).\n\n'
                  'kg CO2e = ova količina × faktor. Za „koliko sam proizvodno uradio” uz proizvod '
                  'koristite polje „Proizvedena količina uz ovaj red” iznad.',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _unitC,
              decoration: InputDecoration(
                labelText: 'Jedinica',
                hintText: 'kWh, litres, km…',
                suffixIcon: _infoIcon(
                  'Jedinica mora biti ista kao u emisijskom faktoru (npr. kWh, l, tkm).\n\n'
                  'Primjer: ako je faktor „kg CO2e po kWh”, ovdje piše kWh — ne MWh '
                  '(osim ako faktor eksplicitno koristi MWh).\n\n'
                  'Kriva jedinica = krivi izračun emisija.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (keys.isEmpty)
              const Text('Nema faktora — učitajte modul ponovo.')
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownMenu<String>(
                      key: ValueKey(_factorKey),
                      initialSelection: _factorKey,
                      label: const Text('Factor Key'),
                      expandedInsets: EdgeInsets.zero,
                      dropdownMenuEntries: [
                        for (final k in keys)
                          DropdownMenuEntry<String>(value: k, label: k),
                      ],
                      onSelected: (v) {
                        if (v != null) setState(() => _factorKey = v);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8),
                    child: _infoIcon(
                      'Svaki ključ veže red na tablicu faktora (scope 1/2/3, izvor, jedinica).\n\n'
                      'Primjer: BA_2025_ELEC_GRID_kWh znači „mrežna struja, kg CO2e po kWh”.\n\n'
                      'Ako niste sigurni, pitajte osobu koja je unijela faktore ili '
                      'koristite ključ koji odgovara vašem računu (isti izvor i godina).',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Faktor (kg CO2e / jed.) — zaključano',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                suffixIcon: _infoIcon(
                  'Očitano iz taba Faktori — ne mijenja se ovdje.\n\n'
                  'Primjer: 0,122260 znači da svaka jedinica količine (npr. 1 tkm) '
                  'množi ovaj broj da dobije kg CO2e.',
                ),
              ),
              child: Text(
                f == null ? '—' : f.factorKgCo2ePerUnit.toStringAsFixed(6),
              ),
            ),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'kg CO2e — zaključano',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                suffixIcon: _infoIcon(
                  'Izračun: količina (gore) × faktor (kg CO2e po jedinici).\n\n'
                  'Primjer: 1000 tkm × 0,122260 = 122,26 kg CO2e.\n\n'
                  'Tone (tCO2e) vide se u tabu Pregled i u CSV stupcu co2eT.',
                ),
              ),
              child: Text(kg.toStringAsFixed(3)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _evC,
              decoration: InputDecoration(
                labelText: 'Referenca dokaza',
                hintText: 'Račun br.…',
                suffixIcon: _infoIcon(
                  'Što zapisati\n'
                  'Nešto što će revizor ili kolega moći pronaći: broj računa, interni '
                  'dokument, link na SharePoint/DMS, ime datoteke.\n\n'
                  'Primjer: „INV-2026-0144” ili „Struja 03-2026 PDF u mapi Energetika”.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesC,
              decoration: InputDecoration(
                labelText: 'Napomena',
                suffixIcon: _infoIcon(
                  'Opcionalno: pretpostavke, izuzeci, tko je unio podatak, zašto je '
                  'faktor odabran.\n\n'
                  'Primjer: „Procjena dok nije stigao konačni račun” ili '
                  '„Uključeno 50% rada iz najma”.\n\n'
                  'Ne utječe na izračun — samo dokumentacija.',
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final line = CarbonActivityLine(
                  id: e?.id ?? '',
                  companyId: widget.companyId,
                  reportingYear: widget.reportingYear,
                  rowId: _rowId,
                  include: _include[0],
                  plantKey: _plantC.text.trim(),
                  productId: _catalogProductId.trim(),
                  productCode: _catalogProductCode.trim(),
                  productLabel: _productLabelC.text.trim(),
                  productOutputQty: double.tryParse(
                        _productOutputQtyC.text.trim().replaceAll(',', '.'),
                      ) ??
                      0,
                  activityDate: _dateC.text.trim(),
                  activityType: _typeC.text.trim(),
                  description: _descC.text.trim(),
                  quantity:
                      double.tryParse(
                        _qtyC.text.trim().replaceAll(',', '.'),
                      ) ??
                      0,
                  unit: _unitC.text.trim(),
                  factorKey: _factorKey,
                  evidenceRef: _evC.text.trim(),
                  notes: _notesC.text.trim(),
                );
                await widget.service.upsertActivity(
                  line: line,
                  userId: widget.userId,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Spremi'),
            ),
          ],
        ),
      ),
    );
  }
}
