import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/production/production_orders/printing/bom_classification_catalog.dart';
import 'package:production_app/modules/production/tracking/config/station_tracking_setup_store.dart';

/// Prvo pokretanje **dedicated** stanice: korisnik s ulogom `admin` na ovom računalu određuje pogon,
/// klasifikaciju koja se ovdje evidentira i izgled / ispis etikete.
/// Operateri se moraju prijaviti korisnikom koji u sustavu pripada istom pogonu.
class StationTrackingSetupScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final VoidCallback onSaved;

  const StationTrackingSetupScreen({
    super.key,
    required this.companyData,
    required this.onSaved,
  });

  @override
  State<StationTrackingSetupScreen> createState() =>
      _StationTrackingSetupScreenState();
}

class _StationTrackingSetupScreenState extends State<StationTrackingSetupScreen> {
  bool _loading = true;
  Object? _loadError;
  List<String> _keys = [];
  final Map<String, String> _labelByKey = {};
  String? _pickedPlant;
  String _classification = kBomClassificationCodes.first;
  bool _labelPrintingEnabled = true;
  String _labelLayout = kStationLabelLayoutStandard;
  bool _saving = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _labelFromDoc(Map<String, dynamic> data, String fallbackId) {
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
        : fallbackId;
    if (plantCode.isNotEmpty) return '$base ($plantCode)';
    return base;
  }

  bool get _canConfigure =>
      ProductionAccessHelper.isAdminRole(widget.companyData['role']);

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  static String _layoutTitleBs(String key) {
    switch (key) {
      case kStationLabelLayoutCompact:
        return 'Kompaktan (manji QR, manje teksta)';
      case kStationLabelLayoutMinimal:
        return 'Minimalan (naslov + QR)';
      default:
        return 'Standard (puni opis + QR)';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final existing = await StationTrackingSetupStore.load(_companyId);
      final snap = await FirebaseFirestore.instance
          .collection('company_plants')
          .where('companyId', isEqualTo: _companyId)
          .get();
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final ao = (a.data()['order'] as num?)?.toInt() ?? 0;
        final bo = (b.data()['order'] as num?)?.toInt() ?? 0;
        if (ao != bo) return ao.compareTo(bo);
        return _labelFromDoc(
          a.data(),
          a.id,
        ).toLowerCase().compareTo(_labelFromDoc(b.data(), b.id).toLowerCase());
      });
      final keys = <String>[];
      final labels = <String, String>{};
      for (final d in docs) {
        final data = d.data();
        if (data['active'] == false) continue;
        final pk = _s(data['plantKey']).isNotEmpty
            ? _s(data['plantKey'])
            : d.id;
        if (pk.isEmpty) continue;
        keys.add(pk);
        labels[pk] = _labelFromDoc(data, d.id);
      }
      if (!mounted) return;
      setState(() {
        _keys = keys;
        _labelByKey.addAll(labels);
        _pickedPlant = (existing != null && existing.plantKey.isNotEmpty)
            ? (keys.contains(existing.plantKey) ? existing.plantKey : null)
            : (keys.length == 1 ? keys.first : null);
        if (existing != null) {
          _classification = kBomClassificationCodes.contains(
                existing.classification.toUpperCase(),
              )
              ? existing.classification.toUpperCase()
              : kBomClassificationCodes.first;
          _labelPrintingEnabled = existing.labelPrintingEnabled;
          _labelLayout = kStationLabelLayoutKeys.contains(
                existing.labelLayoutKey,
              )
              ? existing.labelLayoutKey
              : kStationLabelLayoutStandard;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final k = _pickedPlant?.trim();
    if (k == null || k.isEmpty || _companyId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await StationTrackingSetupStore.save(
        _companyId,
        StationTrackingSetup(
          plantKey: k,
          classification: _classification,
          labelPrintingEnabled: _labelPrintingEnabled,
          labelLayoutKey: _labelLayout,
        ),
      );
      if (!mounted) return;
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Postavke stanice za praćenje')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Na ovom računalu stanica radi za jedan pogon. '
                      'Odredi koji se tip klasifikacije ovdje evidentira i kako izgleda etiketa. '
                      'Ako na ovoj stanici nema ispis etikete, isključi ga — gumb za ispis će nestati.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    if (!_canConfigure) ...[
                      Text(
                        'Samo korisnik s ulogom admin može postaviti stanicu. '
                        'Zamoli odgovornu osobu da se prijavi i dovrši postavljanje.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ] else if (_loadError != null)
                      Text(
                        'Učitavanje nije uspjelo: $_loadError',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      )
                    else if (_keys.isEmpty)
                      Text(
                        'Nema aktivnih pogona u tvrtki. U sustavu mora postojati barem jedan pogon.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>(
                          '${_pickedPlant}_${_keys.length}',
                        ),
                        initialValue: _pickedPlant != null && _keys.contains(_pickedPlant)
                            ? _pickedPlant
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Pogon za ovu stanicu',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          for (final pk in _keys)
                            DropdownMenuItem(
                              value: pk,
                              child: Text(
                                _labelByKey[pk] ?? pk,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving || !_canConfigure
                            ? null
                            : (v) => setState(() => _pickedPlant = v),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Klasifikacija (BOM)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bomClassificationStationIntroBs(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(_classification),
                        initialValue: _classification,
                        decoration: const InputDecoration(
                          labelText: 'Što se na ovoj stanici evidentira',
                          border: OutlineInputBorder(),
                          helperText:
                              'Odabir utiče na to koja se sastavnica veže na unos i etiketu.',
                        ),
                        isExpanded: true,
                        items: [
                          for (final c in kBomClassificationCodes)
                            DropdownMenuItem(
                              value: c,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${bomClassificationTitleBs(c)} ($c)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    bomClassificationDropdownSubtitleBs(c),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.25,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        selectedItemBuilder: (context) => [
                          for (final c in kBomClassificationCodes)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                '${bomClassificationTitleBs(c)} ($c)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving || !_canConfigure
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() => _classification = v);
                              },
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Za odabrano: '
                                      '${bomClassificationTitleBs(_classification)}',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                bomClassificationStationHelpLongBs(
                                  _classification,
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Etiketa',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Omogući ispis etikete na ovoj stanici'),
                        subtitle: const Text(
                          'Isključi ako se ovdje nema etiketiranja — opcija „Ispiši etiketu“ neće biti u unosu.',
                        ),
                        value: _labelPrintingEnabled,
                        onChanged: _saving || !_canConfigure
                            ? null
                            : (v) => setState(() => _labelPrintingEnabled = v),
                      ),
                      if (_labelPrintingEnabled) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(_labelLayout),
                          initialValue: _labelLayout,
                          decoration: const InputDecoration(
                            labelText: 'Izgled etikete (PDF)',
                            border: OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: [
                            for (final lk in kStationLabelLayoutKeys)
                              DropdownMenuItem(
                                value: lk,
                                child: Text(
                                  _layoutTitleBs(lk),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _saving || !_canConfigure
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() => _labelLayout = v);
                                },
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed:
                            !_canConfigure ||
                                _saving ||
                                _pickedPlant == null ||
                                _pickedPlant!.isEmpty
                            ? null
                            : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Spremanje…' : 'Potvrdi postavke'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
