import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../tracking/services/production_asset_display_lookup.dart';
import '../models/work_center_model.dart';
import '../services/work_center_service.dart';
import '../widgets/work_center_help.dart';

class WorkCenterEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String workCenterId;
  final String plantKey;

  const WorkCenterEditScreen({
    super.key,
    required this.companyData,
    required this.workCenterId,
    required this.plantKey,
  });

  @override
  State<WorkCenterEditScreen> createState() => _WorkCenterEditScreenState();
}

class _WorkCenterEditScreenState extends State<WorkCenterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final WorkCenterService _service = WorkCenterService();

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController();
  final _operatorsCtrl = TextEditingController();

  String _type = WorkCenter.typeMachine;
  String _status = WorkCenter.statusOperational;

  bool _isOee = true;
  bool _isOoe = true;
  bool _isTeep = true;
  bool _active = true;

  bool _pageLoading = true;
  bool _saving = false;
  bool _assetsLoading = true;
  String? _loadError;

  WorkCenter? _existing;
  List<({String id, String label})> _assets = const [];
  String _linkedAssetId = '';

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userId =>
      (widget.companyData['userId'] ?? widget.companyData['uid'] ?? 'system')
          .toString()
          .trim();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _capacityCtrl.dispose();
    _cycleCtrl.dispose();
    _operatorsCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _pageLoading = true;
      _loadError = null;
    });
    try {
      final wc = await _service.getById(
        companyId: _companyId,
        plantKey: widget.plantKey.trim(),
        workCenterId: widget.workCenterId.trim(),
      );
      if (!mounted) return;
      if (wc == null) {
        setState(() {
          _pageLoading = false;
          _loadError = 'Radni centar nije pronađen.';
        });
        return;
      }
      _existing = wc;
      _codeCtrl.text = wc.workCenterCode;
      _nameCtrl.text = wc.name;
      _locationCtrl.text = wc.locationName;
      _capacityCtrl.text = wc.capacityPerHour > 0
          ? (wc.capacityPerHour == wc.capacityPerHour.roundToDouble()
                ? wc.capacityPerHour.toInt().toString()
                : wc.capacityPerHour.toString())
          : '';
      _cycleCtrl.text = wc.standardCycleTimeSec > 0
          ? (wc.standardCycleTimeSec == wc.standardCycleTimeSec.roundToDouble()
                ? wc.standardCycleTimeSec.toInt().toString()
                : wc.standardCycleTimeSec.toString())
          : '';
      _operatorsCtrl.text = wc.operatorCount.toString();
      _type = wc.type.isEmpty ? WorkCenter.typeMachine : wc.type;
      _status = wc.status.isEmpty ? WorkCenter.statusIdle : wc.status;
      _isOee = wc.isOeeRelevant;
      _isOoe = wc.isOoeRelevant;
      _isTeep = wc.isTeepRelevant;
      _active = wc.active;
      _linkedAssetId = wc.linkedAssetId;

      setState(() => _pageLoading = false);
      await _loadAssets();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageLoading = false;
        _loadError = AppErrorMapper.toMessage(e);
      });
    }
  }

  Future<void> _loadAssets() async {
    final cid = _companyId;
    final pk = widget.plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      if (mounted) setState(() => _assetsLoading = false);
      return;
    }

    setState(() => _assetsLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('assets')
          .where('companyId', isEqualTo: cid)
          .where('plantKey', isEqualTo: pk)
          .limit(400)
          .get();

      final rows =
          snap.docs
              .map(
                (d) => (
                  id: d.id,
                  label: ProductionAssetDisplayLookup.labelFromAssetData(
                    d.data(),
                  ),
                ),
              )
              .toList()
            ..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
            );

      if (!mounted) return;
      setState(() {
        _assets = rows;
        _assetsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assets = const [];
        _assetsLoading = false;
      });
    }
  }

  String? _required(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return '$label je obavezno';
    return null;
  }

  double _parseDouble(String raw) {
    final s = raw.trim().replaceAll(',', '.');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  int _parseInt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? 0;
  }

  Widget _switchHelpTitle(String text, String helpTitle, String helpBody) {
    return Row(
      children: [
        Expanded(child: Text(text)),
        WorkCenterInfoIcon(title: helpTitle, message: helpBody),
      ],
    );
  }

  Future<void> _save() async {
    final ex = _existing;
    if (!_formKey.currentState!.validate() || ex == null) return;
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje korisnik za audit.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String linkedName = '';
      if (_linkedAssetId.isNotEmpty) {
        for (final a in _assets) {
          if (a.id == _linkedAssetId) {
            linkedName = a.label;
            break;
          }
        }
        if (linkedName.isEmpty) {
          linkedName = ex.linkedAssetName;
        }
      }

      await _service.updateWorkCenter(
        existing: ex,
        workCenterCode: _codeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        type: _type,
        status: _status,
        locationName: _locationCtrl.text.trim(),
        linkedAssetId: _linkedAssetId,
        linkedAssetName: linkedName,
        capacityPerHour: _parseDouble(_capacityCtrl.text),
        standardCycleTimeSec: _parseDouble(_cycleCtrl.text),
        operatorCount: _parseInt(_operatorsCtrl.text),
        isOeeRelevant: _isOee,
        isOoeRelevant: _isOoe,
        isTeepRelevant: _isTeep,
        active: _active,
        updatedBy: _userId,
      );

      final refreshed = await _service.getById(
        companyId: _companyId,
        plantKey: widget.plantKey.trim(),
        workCenterId: widget.workCenterId.trim(),
      );
      if (!mounted) return;
      if (refreshed != null) {
        setState(() => _existing = refreshed);
      }
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Izmjene su spremljene.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pageLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uredi radni centar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uredi radni centar')),
        body: Center(child: Text(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uredi radni centar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: WorkCenterHelpTexts.overviewTitle,
            onPressed: () => showWorkCenterHelpDialog(
              context,
              title: WorkCenterHelpTexts.overviewTitle,
              message: WorkCenterHelpTexts.overviewBody,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Pogon: ${widget.plantKey.trim()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.plantTitle,
                  message: WorkCenterHelpTexts.plantBody,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                labelText: 'Šifra radnog centra *',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.codeTitle,
                  message: WorkCenterHelpTexts.codeBody,
                ),
              ),
              validator: (v) => _required(v, 'Šifra'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Naziv *',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.nameTitle,
                  message: WorkCenterHelpTexts.nameBody,
                ),
              ),
              validator: (v) => _required(v, 'Naziv'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: 'Tip *',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.typeTitle,
                  message: WorkCenterHelpTexts.typeBody,
                ),
              ),
              items: WorkCenter.selectableTypes
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _type = v ?? WorkCenter.typeMachine),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: 'Status *',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.statusTitle,
                  message: WorkCenterHelpTexts.statusBody,
                ),
              ),
              items: WorkCenter.selectableStatuses
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _status = v ?? WorkCenter.statusIdle),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                labelText: 'Lokacija / zona *',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.locationTitle,
                  message: WorkCenterHelpTexts.locationBody,
                ),
              ),
              validator: (v) => _required(v, 'Lokacija'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityCtrl,
              decoration: InputDecoration(
                labelText: 'Kapacitet (kom/h)',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.capacityTitle,
                  message: WorkCenterHelpTexts.capacityBody,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cycleCtrl,
              decoration: InputDecoration(
                labelText: 'Standardni ciklus (s)',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.cycleTitle,
                  message: WorkCenterHelpTexts.cycleBody,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _operatorsCtrl,
              decoration: InputDecoration(
                labelText: 'Broj operatera *',
                suffixIcon: WorkCenterInfoIcon(
                  title: WorkCenterHelpTexts.operatorsTitle,
                  message: WorkCenterHelpTexts.operatorsBody,
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = _parseInt(v ?? '');
                if (n < 0) return 'Ne može biti negativno';
                return null;
              },
            ),
            const SizedBox(height: 12),
            if (_assetsLoading)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                initialValue: _linkedAssetId.isEmpty ? '' : _linkedAssetId,
                decoration: InputDecoration(
                  labelText: 'Povezana mašina / linija (asset)',
                  suffixIcon: WorkCenterInfoIcon(
                    title: WorkCenterHelpTexts.assetTitle,
                    message: WorkCenterHelpTexts.assetBody,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('— nije povezano —'),
                  ),
                  ..._assets.map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.label, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _linkedAssetId = v ?? ''),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: _switchHelpTitle(
                'OEE relevantan',
                WorkCenterHelpTexts.oeeFlagTitle,
                WorkCenterHelpTexts.oeeFlagBody,
              ),
              value: _isOee,
              onChanged: _saving ? null : (v) => setState(() => _isOee = v),
            ),
            SwitchListTile(
              title: _switchHelpTitle(
                'OOE relevantan',
                WorkCenterHelpTexts.ooeFlagTitle,
                WorkCenterHelpTexts.ooeFlagBody,
              ),
              value: _isOoe,
              onChanged: _saving ? null : (v) => setState(() => _isOoe = v),
            ),
            SwitchListTile(
              title: _switchHelpTitle(
                'TEEP relevantan',
                WorkCenterHelpTexts.teepFlagTitle,
                WorkCenterHelpTexts.teepFlagBody,
              ),
              value: _isTeep,
              onChanged: _saving ? null : (v) => setState(() => _isTeep = v),
            ),
            SwitchListTile(
              title: _switchHelpTitle(
                'Aktivan u šifrarniku',
                WorkCenterHelpTexts.activeTitle,
                WorkCenterHelpTexts.activeBody,
              ),
              value: _active,
              onChanged: _saving ? null : (v) => setState(() => _active = v),
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
                  : const Text('Spremi izmjene'),
            ),
          ],
        ),
      ),
    );
  }
}
