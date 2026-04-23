import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../models/mes_tpm_six_losses.dart';
import '../models/ooe_loss_reason.dart';
import '../services/ooe_loss_reason_service.dart';

/// Administracija kataloga `ooe_loss_reasons` (mapiranje u A / P / Q).
///
/// [ProductionAccessHelper.canManage] za OOE — usklađeno s Firestore pravilima.
class OoeLossReasonsScreen extends StatelessWidget {
  const OoeLossReasonsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey => (companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  @override
  Widget build(BuildContext context) {
    final svc = OoeLossReasonService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Razlozi gubitaka'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: CompanyPlantLabelText(
                companyId: _companyId,
                plantKey: _plantKey,
                prefix: '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, reason: null),
              icon: const Icon(Icons.add),
              label: const Text('Novi razlog'),
            )
          : null,
      body: StreamBuilder<List<OoeLossReason>>(
        stream: svc.watchAllReasonsForPlant(
          companyId: _companyId,
          plantKey: _plantKey,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppErrorMapper.toMessage(snap.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _canManage
                      ? 'Još nema razloga. Dodaj prvi unos u katalog.'
                      : 'Katalog razloga je prazan.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                child: ListTile(
                  title: Text(r.name),
                  subtitle: Text(
                    '${r.code} · ${_categoryLabel(r.category)} · TPM: ${MesTpmLossKeys.labelHr(r.effectiveTpmLossKey)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!r.active)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Neaktivan',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      if (_canManage)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEditor(context, reason: r),
                        ),
                    ],
                  ),
                  onTap: _canManage ? () => _openEditor(context, reason: r) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _categoryLabel(String code) {
    const m = {
      OoeLossReason.categoryPlannedStop: 'Planirani zastoj',
      OoeLossReason.categoryUnplannedStop: 'Neplanirani zastoj',
      OoeLossReason.categorySetupChangeover: 'Priprema / prebacivanje',
      OoeLossReason.categoryMaterialWait: 'Čekanje materijala',
      OoeLossReason.categoryOperatorWait: 'Čekanje operatera',
      OoeLossReason.categoryMaintenance: 'Održavanje',
      OoeLossReason.categoryQualityHold: 'Kvalitet / zadržavanje',
      OoeLossReason.categoryMicroStop: 'Mikro zastoj',
      OoeLossReason.categoryReducedSpeed: 'Smanjena brzina',
      OoeLossReason.categoryOther: 'Ostalo',
    };
    return m[code] ?? code;
  }

  void _openEditor(BuildContext context, {required OoeLossReason? reason}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _LossReasonEditorSheet(
        companyId: _companyId,
        plantKey: _plantKey,
        existing: reason,
        canManage: _canManage,
      ),
    );
  }
}

class _LossReasonEditorSheet extends StatefulWidget {
  const _LossReasonEditorSheet({
    required this.companyId,
    required this.plantKey,
    required this.existing,
    required this.canManage,
  });

  final String companyId;
  final String plantKey;
  final OoeLossReason? existing;
  final bool canManage;

  @override
  State<_LossReasonEditorSheet> createState() => _LossReasonEditorSheetState();
}

class _LossReasonEditorSheetState extends State<_LossReasonEditorSheet> {
  final _svc = OoeLossReasonService();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _sortCtrl;
  late String _category;
  /// Prazan string = nema overridea, koristi heuristiku iz kategorije.
  late String _tpmKey;
  late bool _isPlanned;
  late bool _affectsA;
  late bool _affectsP;
  late bool _affectsQ;
  late bool _active;
  bool _saving = false;

  /// Nepoznat ključ u starim zapisima — prikaži kao stavku da ne gubimo mapiranje.
  bool get _tpmKeyIsCustom =>
      _tpmKey.isNotEmpty &&
      !MesTpmLossKeys.ordered.contains(_tpmKey) &&
      _tpmKey != MesTpmLossKeys.unclassified;

  static const _categories = <String, String>{
    OoeLossReason.categoryPlannedStop: 'Planirani zastoj',
    OoeLossReason.categoryUnplannedStop: 'Neplanirani zastoj',
    OoeLossReason.categorySetupChangeover: 'Priprema / prebacivanje',
    OoeLossReason.categoryMaterialWait: 'Čekanje materijala',
    OoeLossReason.categoryOperatorWait: 'Čekanje operatera',
    OoeLossReason.categoryMaintenance: 'Održavanje',
    OoeLossReason.categoryQualityHold: 'Kvalitet / zadržavanje',
    OoeLossReason.categoryMicroStop: 'Mikro zastoj',
    OoeLossReason.categoryReducedSpeed: 'Smanjena brzina',
    OoeLossReason.categoryOther: 'Ostalo',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codeCtrl = TextEditingController(text: e?.code ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _sortCtrl = TextEditingController(
      text: e != null ? e.sortOrder.toString() : '0',
    );
    _category = e?.category ?? OoeLossReason.categoryUnplannedStop;
    _tpmKey = e?.tpmLossKey?.trim() ?? '';
    _isPlanned = e?.isPlanned ?? false;
    _affectsA = e?.affectsAvailability ?? true;
    _affectsP = e?.affectsPerformance ?? false;
    _affectsQ = e?.affectsQuality ?? false;
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!widget.canManage) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      _toast('Moraš biti prijavljen.');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Naziv je obavezan.');
      return;
    }
    final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      final e = widget.existing;
      if (e == null) {
        final code = _codeCtrl.text.trim().toUpperCase();
        if (code.isEmpty) {
          _toast('Šifra (code) je obavezna.');
          setState(() => _saving = false);
          return;
        }
        await _svc.createReason(
          companyId: widget.companyId,
          plantKey: widget.plantKey,
          code: code,
          name: name,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          category: _category,
          tpmLossKey: _tpmKey.isEmpty ? null : _tpmKey,
          isPlanned: _isPlanned,
          affectsAvailability: _affectsA,
          affectsPerformance: _affectsP,
          affectsQuality: _affectsQ,
          sortOrder: sort,
        );
      } else {
        await _svc.updateReason(
          reasonId: e.id,
          companyId: widget.companyId,
          plantKey: widget.plantKey,
          name: name,
          description: _descCtrl.text.trim().isEmpty ? '' : _descCtrl.text.trim(),
          category: _category,
          tpmLossKey: _tpmKey.isEmpty ? '' : _tpmKey,
          isPlanned: _isPlanned,
          affectsAvailability: _affectsA,
          affectsPerformance: _affectsP,
          affectsQuality: _affectsQ,
          active: _active,
          sortOrder: sort,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Katalog ažuriran.')),
        );
      }
    } catch (e) {
      if (mounted) _toast(AppErrorMapper.toMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isNew ? 'Novi razlog gubitka' : 'Uredi razlog',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              enabled: isNew && !_saving,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Šifra (code)',
                helperText: 'Jedinstvena u pogonu, npr. BREAK, TOOL_CHANGE',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Naziv'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              enabled: !_saving,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Opis (opc.)'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Kategorija'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _categories.containsKey(_category)
                      ? _category
                      : OoeLossReason.categoryOther,
                  items: _categories.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: widget.canManage && !_saving
                      ? (v) {
                          if (v != null) setState(() => _category = v);
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'TPM — šest velikih gubitaka',
                helperText: 'Prazno = heuristika iz kategorije gore (za starije unose).',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _tpmKey,
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Auto (heuristika iz kategorije)'),
                    ),
                    const DropdownMenuItem<String>(
                      value: MesTpmLossKeys.unclassified,
                      child: Text('Eksplicitno: nekvalificirano'),
                    ),
                    ...MesTpmLossKeys.ordered.map(
                      (k) => DropdownMenuItem<String>(
                        value: k,
                        child: Text(MesTpmLossKeys.labelHr(k)),
                      ),
                    ),
                    if (_tpmKeyIsCustom)
                      DropdownMenuItem<String>(
                        value: _tpmKey,
                        child: Text('Spremljeno: $_tpmKey'),
                      ),
                  ],
                  onChanged: widget.canManage && !_saving
                      ? (v) {
                          if (v == null) return;
                          setState(() => _tpmKey = v);
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sortCtrl,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Redoslijed (sortOrder)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Planirani zastoj'),
              value: _isPlanned,
              onChanged: widget.canManage && !_saving
                  ? (v) => setState(() => _isPlanned = v)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Utječe na availability (A)'),
              value: _affectsA,
              onChanged: widget.canManage && !_saving
                  ? (v) => setState(() => _affectsA = v)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Utječe na performance (P)'),
              value: _affectsP,
              onChanged: widget.canManage && !_saving
                  ? (v) => setState(() => _affectsP = v)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Utječe na quality (Q)'),
              value: _affectsQ,
              onChanged: widget.canManage && !_saving
                  ? (v) => setState(() => _affectsQ = v)
                  : null,
            ),
            if (!isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktivan u katalogu'),
                value: _active,
                onChanged: widget.canManage && !_saving
                    ? (v) => setState(() => _active = v)
                    : null,
              ),
            const SizedBox(height: 16),
            if (widget.canManage)
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Čuvanje…' : 'Sačuvaj'),
              ),
          ],
        ),
      ),
    );
  }
}
