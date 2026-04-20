import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_iatf_help.dart';
import '../widgets/qms_pickers.dart';

/// Uređivanje jednog PFMEA reda (`upsertQmsPfmeaRow`).
class QmsPfmeaEditScreen extends StatefulWidget {
  const QmsPfmeaEditScreen({
    super.key,
    required this.companyData,
    this.pfmeaRowId,
  });

  final Map<String, dynamic> companyData;

  /// `null` = novi red.
  final String? pfmeaRowId;

  @override
  State<QmsPfmeaEditScreen> createState() => _QmsPfmeaEditScreenState();
}

class _QmsPfmeaEditScreenState extends State<QmsPfmeaEditScreen> {
  final _svc = QualityCallableService();
  final _processStep = TextEditingController();
  final _failureMode = TextEditingController();
  final _effects = TextEditingController();
  final _currentControls = TextEditingController();
  final _recommended = TextEditingController();
  final _plantKey = TextEditingController();
  final _sortOrder = TextEditingController(text: '0');

  String? _productId;
  String? _controlPlanId;

  var _severity = 0;
  var _occurrence = 0;
  var _detection = 0;
  var _apManual = false;
  var _apManualValue = 'M';
  String _apComputed = 'U';
  String _rowStatus = 'draft';

  bool _loading = true;
  String? _error;
  bool _saving = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool get _isNew => widget.pfmeaRowId == null || widget.pfmeaRowId!.isEmpty;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _processStep.dispose();
    _failureMode.dispose();
    _effects.dispose();
    _currentControls.dispose();
    _recommended.dispose();
    _plantKey.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _recomputeApComputed() {
    final s = _severity;
    final o = _occurrence;
    final d = _detection;
    if (s <= 0 || o <= 0 || d <= 0) {
      _apComputed = 'U';
      return;
    }
    if (s >= 9) {
      _apComputed = 'H';
    } else if (s >= 7 && (o >= 6 || d >= 6)) {
      _apComputed = 'H';
    } else if (o >= 8 && d >= 7) {
      _apComputed = 'H';
    } else if (s >= 7) {
      _apComputed = 'M';
    } else if (o >= 6 || d >= 6) {
      _apComputed = 'M';
    } else {
      _apComputed = 'L';
    }
  }

  int _rpn() {
    if (_severity <= 0 || _occurrence <= 0 || _detection <= 0) return 0;
    return _severity * _occurrence * _detection;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await _svc.getQmsPfmeaRowMap(
        companyId: _cid,
        pfmeaRowId: widget.pfmeaRowId!,
      );
      if (!mounted) return;
      _processStep.text = (m['processStep'] ?? '').toString();
      _failureMode.text = (m['failureMode'] ?? '').toString();
      _effects.text = (m['effects'] ?? '').toString();
      _currentControls.text = (m['currentControls'] ?? '').toString();
      _recommended.text = (m['recommendedAction'] ?? '').toString();
      _plantKey.text = (m['plantKey'] ?? '').toString();
      _sortOrder.text = (m['sortOrder'] ?? 0).toString();
      _productId = (m['productId'] ?? '').toString().trim();
      if (_productId!.isEmpty) _productId = null;
      final cp = (m['controlPlanId'] ?? '').toString().trim();
      _controlPlanId = cp.isEmpty ? null : cp;
      _severity = _gi(m['severity']);
      _occurrence = _gi(m['occurrence']);
      _detection = _gi(m['detection']);
      _apManual = m['apManual'] == true;
      final am = (m['ap'] ?? 'M').toString().toUpperCase();
      _apManualValue =
          _apManual && (am == 'H' || am == 'M' || am == 'L') ? am : 'M';
      _apComputed = (m['apComputed'] ?? 'U').toString();
      _rowStatus = (m['rowStatus'] ?? 'draft').toString();
      if (!['draft', 'active', 'obsolete'].contains(_rowStatus)) {
        _rowStatus = 'draft';
      }
      _recomputeApComputed();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  int _gi(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _save() async {
    final anySod = _severity > 0 || _occurrence > 0 || _detection > 0;
    final allSod = _severity > 0 && _occurrence > 0 && _detection > 0;
    if (anySod && !allSod) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('S, O i D moraju biti svi 1–10 ili svi 0.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final so = int.tryParse(_sortOrder.text.trim()) ?? 0;
      await _svc.upsertQmsPfmeaRow(
        companyId: _cid,
        pfmeaRowId: _isNew ? null : widget.pfmeaRowId,
        processStep: _processStep.text,
        failureMode: _failureMode.text,
        plantKey: _plantKey.text.trim().isEmpty ? null : _plantKey.text.trim(),
        productId: _productId,
        controlPlanId: _controlPlanId,
        effects: _effects.text,
        severity: _severity,
        occurrence: _occurrence,
        detection: _detection,
        apManual: _apManual,
        apManualValue: _apManualValue,
        currentControls: _currentControls.text,
        recommendedAction: _recommended.text,
        rowStatus: _rowStatus,
        sortOrder: so,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PFMEA red je spremljen.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_isNew) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati PFMEA red?'),
        content: const Text('Ova radnja se ne može poništiti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Obriši')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _svc.deleteQmsPfmeaRow(
        companyId: _cid,
        pfmeaRowId: widget.pfmeaRowId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Red je obrisan.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sodDropdown(String label, int value, void Function(int) onChanged) {
    return DropdownButtonFormField<int>(
      key: ValueKey<String>('${label}_$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('—')),
        for (var i = 1; i <= 10; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          onChanged(v);
          _recomputeApComputed();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('PFMEA red')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PFMEA red')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!),
        )),
      );
    }

    final apShown = _apManual ? _apManualValue : _apComputed;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Novi PFMEA red' : 'PFMEA red'),
        actions: [
          QmsIatfInfoIcon(
            title: 'PFMEA red',
            message: QmsIatfStrings.editPfmea,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Proizvod i kontrolni plan (preporučeno za aktivne redove). '
            'Ako odabereš kontrolni plan, proizvod mora odgovarati planu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final id = await showQmsProductPicker(
                      context: context,
                      companyId: _cid,
                    );
                    if (!mounted) return;
                    setState(() {
                      _productId =
                          (id == null || id.trim().isEmpty) ? null : id.trim();
                      _controlPlanId = null;
                    });
                  },
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(
              _productId == null ? 'Odaberi proizvod (opcionalno)' : 'Proizvod: $_productId',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final id = await showQmsControlPlanPicker(
                      context: context,
                      companyId: _cid,
                      productIdFilter: _productId,
                    );
                    if (!mounted) return;
                    setState(() {
                      _controlPlanId =
                          (id == null || id.trim().isEmpty) ? null : id.trim();
                    });
                  },
            icon: const Icon(Icons.engineering_outlined),
            label: Text(
              _controlPlanId == null
                  ? 'Kontrolni plan (opcionalno)'
                  : 'Kontrolni plan: $_controlPlanId',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _processStep,
            decoration: const InputDecoration(
              labelText: 'Korak procesa *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _failureMode,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Način otkazivanja (failure mode) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _effects,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Posljedice / efekti',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('S / O / D (1–10 ili svi 0)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _sodDropdown('S', _severity, (v) => _severity = v)),
              const SizedBox(width: 8),
              Expanded(child: _sodDropdown('O', _occurrence, (v) => _occurrence = v)),
              const SizedBox(width: 8),
              Expanded(child: _sodDropdown('D', _detection, (v) => _detection = v)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'RPN: ${_rpn()} · izračun AP: $_apComputed · korišteno: $apShown',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _apManual,
            onChanged: _saving
                ? null
                : (v) => setState(() => _apManual = v ?? false),
            title: const Text('Ručni AP (inače se koristi izračun)'),
          ),
          if (_apManual)
            DropdownButtonFormField<String>(
              key: ValueKey<String>('apman_$_apManualValue'),
              initialValue: _apManualValue,
              decoration: const InputDecoration(
                labelText: 'Ručni AP',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'H', child: Text('H')),
                DropdownMenuItem(value: 'M', child: Text('M')),
                DropdownMenuItem(value: 'L', child: Text('L')),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _apManualValue = v);
                    },
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _currentControls,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Trenutne kontrole',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _recommended,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Preporučena akcija',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('st_$_rowStatus'),
            initialValue: _rowStatus,
            decoration: const InputDecoration(
              labelText: 'Status reda',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'draft', child: Text('draft')),
              DropdownMenuItem(value: 'active', child: Text('active')),
              DropdownMenuItem(value: 'obsolete', child: Text('obsolete')),
            ],
            onChanged: _saving
                ? null
                : (v) {
                    if (v != null) setState(() => _rowStatus = v);
                  },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sortOrder,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sort redoslijed (broj)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _plantKey,
            decoration: const InputDecoration(
              labelText: 'Plant key (opcionalno)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Spremanje…' : 'Spremi'),
          ),
          if (!_isNew) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Obriši red'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
