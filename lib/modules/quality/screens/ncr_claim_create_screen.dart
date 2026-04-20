import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_iatf_help.dart';
import '../widgets/qms_pickers.dart';
import 'ncr_detail_screen.dart';

/// Otvaranje NCR-a za reklamaciju kupca (`CUSTOMER`) ili dobavljača (`SUPPLIER`).
class NcrClaimCreateScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// `CUSTOMER` ili `SUPPLIER` (isti kao backend [claimSource]).
  final String claimSource;

  const NcrClaimCreateScreen({
    super.key,
    required this.companyData,
    required this.claimSource,
  });

  @override
  State<NcrClaimCreateScreen> createState() => _NcrClaimCreateScreenState();
}

class _NcrClaimCreateScreenState extends State<NcrClaimCreateScreen> {
  final _svc = QualityCallableService();
  final _description = TextEditingController();
  final _containment = TextEditingController();
  final _externalRef = TextEditingController();

  String? _partnerId;
  String _partnerLabel = '';
  String _severity = 'MEDIUM';
  bool _saving = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _defaultPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _isCustomer =>
      widget.claimSource.trim().toUpperCase() == 'CUSTOMER';

  @override
  void dispose() {
    _description.dispose();
    _containment.dispose();
    _externalRef.dispose();
    super.dispose();
  }

  Future<void> _pickPartner() async {
    final ctx = context;
    final Future<String?> pick = _isCustomer
        ? showQmsCustomerPicker(context: ctx, companyId: _cid)
        : showQmsSupplierPicker(context: ctx, companyId: _cid);
    final id = await pick;
    if (!mounted) return;
    if (id != null) {
      setState(() {
        _partnerId = id;
        _partnerLabel = id;
      });
    }
  }

  Future<void> _save() async {
    final pid = _partnerId?.trim();
    if (pid == null || pid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCustomer ? 'Odaberi kupca.' : 'Odaberi dobavljača.'),
        ),
      );
      return;
    }
    final desc = _description.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opis nesklada je obavezan.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ncrId = await _svc.createQmsPartnerClaimNcr(
        companyId: _cid,
        claimSource: widget.claimSource.trim().toUpperCase(),
        partnerKind: _isCustomer ? 'customer' : 'supplier',
        partnerId: pid,
        description: desc,
        plantKey: _defaultPlantKey.isEmpty ? null : _defaultPlantKey,
        containmentAction: _containment.text.trim().isEmpty
            ? null
            : _containment.text,
        externalClaimRef: _externalRef.text.trim().isEmpty
            ? null
            : _externalRef.text.trim(),
        severity: _severity,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NCR je otvoren.')),
      );
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => NcrDetailScreen(
            companyData: widget.companyData,
            ncrId: ncrId,
          ),
        ),
      );
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
  Widget build(BuildContext context) {
    final title = _isCustomer
        ? 'Reklamacija kupca'
        : 'Reklamacija / prigovor dobavljaču';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          QmsIatfInfoIcon(
            title: title,
            message: _isCustomer
                ? QmsIatfStrings.claimCustomer
                : QmsIatfStrings.claimSupplier,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isCustomer
                ? 'Otvara se NCR s izvorom CUSTOMER, vezan uz kupca iz master podataka.'
                : 'Otvara se NCR s izvorom SUPPLIER (SCAR / 8D kontekst), vezan uz dobavljača.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_isCustomer ? 'Kupac *' : 'Dobavljač *'),
            subtitle: Text(
              _partnerId == null
                  ? 'Nije odabran'
                  : _partnerLabel,
            ),
            trailing: FilledButton.tonal(
              onPressed: _saving ? null : _pickPartner,
              child: Text(_isCustomer ? 'Odaberi kupca' : 'Odaberi dobavljača'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _externalRef,
            decoration: const InputDecoration(
              labelText: 'Vanjski broj reklamacije (opcionalno)',
              hintText: 'Broj od kupca / interni SCAR',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('sev_$_severity'),
            initialValue: _severity,
            decoration: const InputDecoration(
              labelText: 'Ozbiljnost',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'LOW', child: Text('LOW')),
              DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
              DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
              DropdownMenuItem(value: 'CRITICAL', child: Text('CRITICAL')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _severity = v);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Opis nesklada *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _containment,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Containment / privremena mjera (opcionalno)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Spremanje…' : 'Otvori NCR'),
          ),
        ],
      ),
    );
  }
}
