import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import 'pma_gateway.dart';
import 'pma_models.dart';

const productDetailsTabLabels = <String>[
  'Osnovni podaci',
  'BOM',
  'Routing',
  'Nalozi',
  'Zaliha',
  'Dokumentacija',
  'Reklamacije',
  'Odobrene mašine',
];

class ProductMachineApprovalTab extends StatefulWidget {
  const ProductMachineApprovalTab({
    super.key,
    required this.companyData,
    required this.productId,
    required this.productCode,
    required this.productName,
    this.gateway,
  });

  final Map<String, dynamic> companyData;
  final String productId;
  final String productCode;
  final String productName;
  final ProductMachineApprovalGateway? gateway;

  @override
  State<ProductMachineApprovalTab> createState() =>
      _ProductMachineApprovalTabState();
}

class _ProductMachineApprovalTabState extends State<ProductMachineApprovalTab> {
  late final ProductMachineApprovalGateway _gateway =
      widget.gateway ?? FirebaseProductMachineApprovalGateway();

  bool _loading = true;
  String? _error;
  List<PmaApprovalView> _approvals = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canCreate =>
      ProductionAccessHelper.canPrepareProductMachineApprovalDraft(_role);

  bool get _canApproveTechnology =>
      ProductionAccessHelper.canApproveProductMachineTechnology(_role);

  bool get _canConfirmQuality =>
      ProductionAccessHelper.canConfirmProductMachineQuality(_role);

  bool get _choosePlant =>
      ProductionAccessHelper.isCompanyWideContextRole(_role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final approvals = await _gateway.listForProduct(
        productId: widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _approvals = approvals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _PmaDraftDialog(
        gateway: _gateway,
        companyId: _companyId,
        fixedPlantKey: _choosePlant ? '' : _plantKey,
        productId: widget.productId,
        productCode: widget.productCode,
        productName: widget.productName,
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _openTechnologyApproval(PmaApprovalView view) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => _PmaTechnologyApprovalDialog(
        gateway: _gateway,
        view: view,
      ),
    );
    if (approved == true) await _load();
  }

  Future<void> _openQualityAction({
    required PmaApprovalView view,
    required bool confirm,
  }) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (context) => _PmaQualityActionDialog(
        gateway: _gateway,
        view: view,
        confirm: confirm,
      ),
    );
    if (done == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final productTitle = widget.productCode.isEmpty
        ? widget.productName
        : widget.productCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productTitle,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (widget.productCode.isNotEmpty && widget.productName.isNotEmpty)
                Text(widget.productName),
              if (_canCreate) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('pma_create_approval'),
                  onPressed: _loading ? null : _openCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodijeli novu mašinu'),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _card(PmaApprovalView view) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ApprovalCard(
        view: view,
        canApproveTechnology: _canApproveTechnology && view.isDraft,
        canConfirmQuality: _canConfirmQuality && view.isTechnologyApproved,
        onApproveTechnology: () => _openTechnologyApproval(view),
        onConfirmQuality: () => _openQualityAction(view: view, confirm: true),
        onReturnQuality: () => _openQualityAction(view: view, confirm: false),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final confirmed = _approvals.where((view) => view.isQualityConfirmed);
    final inProgress = _approvals.where((view) => !view.isQualityConfirmed);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Column(
          key: const Key('pma_approved_section'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Odobrene mašine',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (confirmed.isEmpty)
              const Text(
                'Trenutno nema potvrđenih odobrenih mašina za ovaj proizvod.',
              )
            else
              ...confirmed.map(_card),
          ],
        ),
        const SizedBox(height: 24),
        Column(
          key: const Key('pma_in_progress_section'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Odobrenja u toku',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (inProgress.isEmpty)
              const Text('Nema odobrenja u toku.')
            else
              ...inProgress.map(_card),
          ],
        ),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.view,
    required this.canApproveTechnology,
    required this.canConfirmQuality,
    required this.onApproveTechnology,
    required this.onConfirmQuality,
    required this.onReturnQuality,
  });

  final PmaApprovalView view;
  final bool canApproveTechnology;
  final bool canConfirmQuality;
  final VoidCallback onApproveTechnology;
  final VoidCallback onConfirmQuality;
  final VoidCallback onReturnQuality;

  @override
  Widget build(BuildContext context) {
    final machines = view.machines.isEmpty
        ? view.machineScopeLabel
        : view.machines.join('\n');
    final message = view.isQualityReturned
        ? 'Vraćeno od Kontrole kvaliteta.'
        : view.isTechnologyApproved
        ? 'Čeka potvrdu Kontrole kvaliteta.'
        : view.isQualityConfirmed
        ? ''
        : 'Priprema odobrenja. Mašina još nije odobrena.';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              view.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Status: ${view.statusLabel}'),
            if (message.isNotEmpty) Text(message),
            Text('Pogon: ${view.plantName}'),
            const SizedBox(height: 8),
            Text(view.machineScopeLabel),
            Text(machines),
            if (view.technologySignatureLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Technology odobrio: ${view.technologySignatureLabel}'),
            ],
            if (view.isQualityConfirmed && view.qualitySignatureLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Kvalitet potvrdio: ${view.qualitySignatureLabel}'),
            ],
            const SizedBox(height: 8),
            Text('Kreirao: ${view.creatorLabel}'),
            Text('Kreirano: ${view.createdAtLabel}'),
            if (canApproveTechnology) ...[
              const SizedBox(height: 12),
              FilledButton(
                key: Key('pma_approve_technology_${view.omNumber}_${view.revision}'),
                onPressed: onApproveTechnology,
                child: const Text('Odobri tehnologiju'),
              ),
            ],
            if (canConfirmQuality) ...[
              const SizedBox(height: 12),
              FilledButton(
                key: Key('pma_confirm_quality_${view.omNumber}_${view.revision}'),
                onPressed: onConfirmQuality,
                child: const Text('Potvrdi kvalitet'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: Key('pma_return_technology_${view.omNumber}_${view.revision}'),
                onPressed: onReturnQuality,
                child: const Text('Vrati tehnologiji'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PmaTechnologyApprovalDialog extends StatefulWidget {
  const _PmaTechnologyApprovalDialog({
    required this.gateway,
    required this.view,
  });

  final ProductMachineApprovalGateway gateway;
  final PmaApprovalView view;

  @override
  State<_PmaTechnologyApprovalDialog> createState() =>
      _PmaTechnologyApprovalDialogState();
}

class _PmaTechnologyApprovalDialogState
    extends State<_PmaTechnologyApprovalDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _approve() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.approveTechnology(
        omNumber: widget.view.omNumber,
        revision: widget.view.revision,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final products = view.products.isEmpty ? '—' : view.products.join('\n');
    final machines = view.machines.isEmpty ? '—' : view.machines.join('\n');
    return AlertDialog(
      key: const Key('pma_technology_approval_dialog'),
      title: const Text('Odobri tehnologiju'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(view.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Proizvod:\n$products'),
              const SizedBox(height: 8),
              Text('Pogon: ${view.plantName}'),
              const SizedBox(height: 8),
              Text('Mašine:\n$machines'),
              const SizedBox(height: 8),
              Text('Status: ${view.statusLabel}'),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          key: const Key('pma_confirm_technology_approval'),
          onPressed: _saving ? null : _approve,
          child: const Text('Odobri tehnologiju'),
        ),
      ],
    );
  }
}

class _PmaQualityActionDialog extends StatefulWidget {
  const _PmaQualityActionDialog({
    required this.gateway,
    required this.view,
    required this.confirm,
  });

  final ProductMachineApprovalGateway gateway;
  final PmaApprovalView view;
  final bool confirm;

  @override
  State<_PmaQualityActionDialog> createState() => _PmaQualityActionDialogState();
}

class _PmaQualityActionDialogState extends State<_PmaQualityActionDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.confirm) {
        await widget.gateway.confirmQuality(
          omNumber: widget.view.omNumber,
          revision: widget.view.revision,
        );
      } else {
        await widget.gateway.returnToTechnology(
          omNumber: widget.view.omNumber,
          revision: widget.view.revision,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final title = widget.confirm ? 'Potvrdi kvalitet' : 'Vrati tehnologiji';
    final products = view.products.isEmpty ? '—' : view.products.join('\n');
    final machines = view.machines.isEmpty ? '—' : view.machines.join('\n');
    return AlertDialog(
      key: Key(
        widget.confirm
            ? 'pma_quality_confirmation_dialog'
            : 'pma_quality_return_dialog',
      ),
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(view.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Proizvod:\n$products'),
              const SizedBox(height: 8),
              Text('Pogon: ${view.plantName}'),
              const SizedBox(height: 8),
              Text('Mašine:\n$machines'),
              const SizedBox(height: 8),
              Text('Status: ${view.statusLabel}'),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          key: Key(
            widget.confirm
                ? 'pma_confirm_quality_approval'
                : 'pma_confirm_quality_return',
          ),
          onPressed: _saving ? null : _submit,
          child: Text(title),
        ),
      ],
    );
  }
}

class _PmaDraftDialog extends StatefulWidget {
  const _PmaDraftDialog({
    required this.gateway,
    required this.companyId,
    required this.fixedPlantKey,
    required this.productId,
    required this.productCode,
    required this.productName,
  });

  final ProductMachineApprovalGateway gateway;
  final String companyId;
  final String fixedPlantKey;
  final String productId;
  final String productCode;
  final String productName;

  @override
  State<_PmaDraftDialog> createState() => _PmaDraftDialogState();
}

class _PmaDraftDialogState extends State<_PmaDraftDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PmaPlantOption> _plants = const [];
  List<PmaMachineOption> _machines = const [];
  String _plantKey = '';
  String _machineScope = 'selected_machines';
  final Set<String> _machineIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plants = await widget.gateway.listPlants(widget.companyId);
      var plantKey = widget.fixedPlantKey;
      if (plantKey.isEmpty && plants.isNotEmpty) plantKey = plants.first.plantKey;
      if (plantKey.isNotEmpty &&
          plants.every((item) => item.plantKey != plantKey)) {
        plants.insert(
          0,
          PmaPlantOption(plantKey: plantKey, plantName: 'Pogon'),
        );
      }
      final machines = plantKey.isEmpty
          ? <PmaMachineOption>[]
          : await widget.gateway.listMachines(
              companyId: widget.companyId,
              plantKey: plantKey,
            );
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _machines = machines;
        _plantKey = plantKey;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _changePlant(String plantKey) async {
    setState(() {
      _plantKey = plantKey;
      _machines = const [];
      _machineIds.clear();
    });
    final machines = await widget.gateway.listMachines(
      companyId: widget.companyId,
      plantKey: plantKey,
    );
    if (!mounted) return;
    setState(() => _machines = machines);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.createDraft(
        PmaDraftRequest(
          plantKey: _plantKey,
          productId: widget.productId,
          machineScopeMode: _machineScope,
          machineIds: _machineScope == 'all_machines'
              ? const []
              : _machineIds.toList(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(error);
      });
    }
  }

  String? _plantName(String plantKey) {
    for (final plant in _plants) {
      if (plant.plantKey == plantKey) return plant.plantName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final plantName = _plantName(_plantKey);
    return AlertDialog(
      title: const Text('Dodijeli novu mašinu'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productCode.isEmpty
                          ? widget.productName
                          : widget.productCode,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (widget.productName.isNotEmpty) Text(widget.productName),
                    const SizedBox(height: 16),
                    if (widget.fixedPlantKey.isNotEmpty)
                      Text('Pogon: ${plantName ?? 'Pogon'}')
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _plantKey.isEmpty ? null : _plantKey,
                        decoration: const InputDecoration(labelText: 'Pogon'),
                        items: _plants
                            .map(
                              (plant) => DropdownMenuItem<String>(
                                value: plant.plantKey,
                                child: Text(plant.plantName),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) _changePlant(value);
                              },
                      ),
                    const SizedBox(height: 16),
                    const Text('Mašine'),
                    RadioGroup<String>(
                      groupValue: _machineScope,
                      onChanged: (value) {
                        if (_saving || value == null) return;
                        setState(() => _machineScope = value);
                      },
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'selected_machines',
                            enabled: !_saving,
                            title: const Text('Odabrane mašine'),
                          ),
                          RadioListTile<String>(
                            value: 'all_machines',
                            enabled: !_saving,
                            title: const Text('Sve mašine u pogonu'),
                          ),
                        ],
                      ),
                    ),
                    if (_machineScope == 'all_machines')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Snima se tačan popis aktivnih mašina u pogonu u trenutku kreiranja.',
                        ),
                      ),
                    if (_machineScope == 'selected_machines')
                      ..._machines.map(
                        (machine) => CheckboxListTile(
                          value: _machineIds.contains(machine.machineId),
                          title: Text(machine.label),
                          subtitle: Text(plantName ?? 'Pogon'),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: _saving
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _machineIds.add(machine.machineId);
                                    } else {
                                      _machineIds.remove(machine.machineId);
                                    }
                                  });
                                },
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          key: const Key('pma_save_draft'),
          onPressed: _loading || _saving ? null : _save,
          child: const Text('Kreiraj nacrt'),
        ),
      ],
    );
  }
}

const pmaDataUnavailableMessage = 'Podatke trenutno nije moguće učitati.';

String _message(Object error) {
  if (error is FirebaseFunctionsException) {
    final code = error.code.toLowerCase().replaceFirst('functions/', '');
    final text = (error.message ?? '').trim();
    if (_isBusinessCallableMessage(code, text)) return text;
  }
  return pmaDataUnavailableMessage;
}

bool _isBusinessCallableMessage(String code, String text) {
  const businessCodes = <String>{
    'failed-precondition',
    'invalid-argument',
    'permission-denied',
    'unauthenticated',
    'not-found',
    'already-exists',
  };
  if (!businessCodes.contains(code) || text.isEmpty) return false;
  final normalized = text.toLowerCase();
  const technical = <String>{
    'internal',
    'permission-denied',
    'failed-precondition',
    'not-found',
    'unauthenticated',
    'invalid-argument',
    'already-exists',
    'unavailable',
    'unknown',
    'deadline-exceeded',
    'cancelled',
    'unimplemented',
    'data-loss',
    'resource-exhausted',
    'aborted',
    'out-of-range',
    'firebasefunctionsexception',
  };
  if (technical.contains(normalized)) return false;
  if (normalized.contains('exception') ||
      normalized.contains('firebase') ||
      normalized.contains('cloudfunctions') ||
      normalized.contains('firestore') ||
      text.contains('\n')) {
    return false;
  }
  return true;
}
