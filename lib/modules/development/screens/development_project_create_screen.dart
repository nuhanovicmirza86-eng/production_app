import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../production/ooe/widgets/ooe_info_icon.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_help_texts.dart';
import 'development_project_details_screen.dart';
import '../widgets/development_customer_picker_sheet.dart';
import 'development_project_demo_fullscreen_screen.dart';
import '../utils/development_intelligence_glossary.dart';

/// Otvaranje NPI / Stage-Gate projekta — poslovna godina na backendu iz **aktivne** godine šifrarnika
/// (ili kalendara ako šifrarnik ne postoji); bez ručnog biranja godine u UI.
class DevelopmentProjectCreateScreen extends StatefulWidget {
  const DevelopmentProjectCreateScreen({
    super.key,
    required this.companyData,
    /// Kada admin gleda cijelu kompaniju, pogon se prosljeđuje iz portfelja (ili sesije).
    this.plantKeyOverride,
  });

  final Map<String, dynamic> companyData;
  final String? plantKeyOverride;

  @override
  State<DevelopmentProjectCreateScreen> createState() =>
      _DevelopmentProjectCreateScreenState();
}

IconData _typeIcon(String code) {
  switch (code) {
    case DevelopmentProjectTypes.customerNewProduct:
      return Icons.rocket_launch_outlined;
    case DevelopmentProjectTypes.customerChangeProject:
      return Icons.change_circle_outlined;
    case DevelopmentProjectTypes.internalProductDevelopment:
      return Icons.lightbulb_outline;
    case DevelopmentProjectTypes.internalProcessDevelopment:
      return Icons.settings_suggest_outlined;
    case DevelopmentProjectTypes.industrializationProject:
      return Icons.precision_manufacturing_outlined;
    case DevelopmentProjectTypes.costReductionProject:
      return Icons.savings_outlined;
    case DevelopmentProjectTypes.qualityImprovementProject:
      return Icons.verified_outlined;
    case DevelopmentProjectTypes.toolingDevelopment:
      return Icons.build_circle_outlined;
    case DevelopmentProjectTypes.digitalizationProject:
      return Icons.hub_outlined;
    default:
      return Icons.folder_special_outlined;
  }
}

class _DevelopmentProjectCreateScreenState
    extends State<DevelopmentProjectCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DevelopmentProjectService();
  final _nameCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();

  String _projectType = DevelopmentProjectTypes.customerNewProduct;
  String _priority = DevelopmentPriorities.medium;
  bool _submitting = false;
  String? _linkedCustomerId;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey {
    final o = (widget.plantKeyOverride ?? '').toString().trim();
    if (o.isNotEmpty) return o;
    return (widget.companyData['plantKey'] ?? '').toString().trim();
  }
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canPickAnotherPm =>
      ProductionAccessHelper.isAdminRole(_role) ||
      ProductionAccessHelper.isSuperAdminRole(_role);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nedostaje organizacija ili pogon u sesiji (potreban za zapis projekta).',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _service.createProjectViaCallable(
        companyId: _companyId,
        plantKey: _plantKey,
        projectName: _nameCtrl.text.trim(),
        projectType: _projectType,
        priority: _priority,
        customerName: _customerCtrl.text.trim().isEmpty
            ? null
            : _customerCtrl.text.trim(),
        customerId: (_linkedCustomerId != null && _linkedCustomerId!.trim().isNotEmpty)
            ? _linkedCustomerId!.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DevelopmentProjectDetailsScreen(
            companyData: widget.companyData,
            projectId: result.projectId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kreiranje nije uspjelo: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final priorities = <MapEntry<String, String>>[
      MapEntry(DevelopmentPriorities.low, 'Nizak'),
      MapEntry(DevelopmentPriorities.medium, 'Srednji'),
      MapEntry(DevelopmentPriorities.high, 'Visok'),
      MapEntry(DevelopmentPriorities.critical, 'Kritičan'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novi NPI projekat'),
        actions: [
          IconButton(
            tooltip: 'Primjer NPI projekta (pun zaslon)',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => DevelopmentProjectDemoFullscreenScreen(
                    companyData: widget.companyData,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'O kreiranju projekta',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final scheme = Theme.of(context).colorScheme;
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Novi projekat'),
                  content: SingleChildScrollView(
                    child: Text(
                      'Zapis otvara životni ciklus u modulu Razvoj: Stage-Gate, tim, '
                      'rizici, dokumentacija, odobrenja i Launch Intelligence. '
                      'Poslovna godina se dodjeljuje automatski (aktivna u šifrarniku).\n\n'
                      '${_canPickAnotherPm ? 'Voditelja kasnije mijenjaš u timu projekta.' : 'Ti si početni voditelj; tim proširuješ u detaljima projekta.'}\n\n'
                      '${DevelopmentIntelligenceGlossary.launchIntelligenceSystemPitch}',
                      style: TextStyle(
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Zatvori'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Tip inicijative',
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        OoeInfoIcon(
                          tooltip: DevelopmentHelpTexts.createInitiativeTypeTooltip,
                          dialogTitle: DevelopmentHelpTexts.createInitiativeTypeTitle,
                          dialogBody: DevelopmentHelpTexts.createInitiativeTypeBody,
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Odabir usmjerava predložene kontrole i obrasce u NPI toku.',
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final tileW = w > 520 ? (w - 12) / 2 : w;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: DevelopmentProjectTypes.all.map((t) {
                            final sel = _projectType == t;
                            return SizedBox(
                              width: tileW,
                              child: Material(
                                color: sel
                                    ? scheme.primaryContainer
                                        .withValues(alpha: 0.65)
                                    : scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => setState(() => _projectType = t),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _typeIcon(t),
                                          color: sel
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            DevelopmentDisplay.projectTypeLabel(t),
                                            style: tt.bodyMedium?.copyWith(
                                              fontWeight: sel
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (sel)
                                          Icon(
                                            Icons.check_circle,
                                            color: scheme.primary,
                                            size: 22,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Identitet inicijative',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'Radni naziv projekta',
                        hintText: 'npr. NPI housings — kupac X / linija Y',
                        border: const OutlineInputBorder(),
                        filled: true,
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.insights_outlined),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      minLines: 1,
                      validator: (_) =>
                          _nameCtrl.text.trim().isEmpty ? 'Unesi naziv.' : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Prioritet portfelja',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: priorities.map((e) {
                        final sel = _priority == e.key;
                        return FilterChip(
                          label: Text(e.value),
                          selected: sel,
                          onSelected: (_) =>
                              setState(() => _priority = e.key),
                          selectedColor:
                              scheme.secondaryContainer.withValues(alpha: 0.9),
                          checkmarkColor: scheme.onSecondaryContainer,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Poslovni kontekst (opcionalno)',
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        OoeInfoIcon(
                          tooltip: DevelopmentHelpTexts.createBusinessContextTooltip,
                          dialogTitle: DevelopmentHelpTexts.createBusinessContextTitle,
                          dialogBody: DevelopmentHelpTexts.createBusinessContextBody,
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kupac ili program — pomaže CSR, Launch Intelligence i trag za IATF.',
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kupac / program',
                        hintText: 'ostavi prazno ako je interna inicijativa',
                        border: OutlineInputBorder(),
                        filled: true,
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 8),
                    if (_linkedCustomerId != null &&
                        _linkedCustomerId!.trim().isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          label: Text(
                            'Povezano na šifarnik (customerId: ${_linkedCustomerId!.trim()})',
                            style: tt.bodySmall,
                          ),
                          onDeleted: _submitting
                              ? null
                              : () => setState(() => _linkedCustomerId = null),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  final m = await showDevelopmentCustomerPickerSheet(
                                    context,
                                    companyId: _companyId,
                                  );
                                  if (!context.mounted) return;
                                  if (m != null) {
                                    setState(() {
                                      _linkedCustomerId = m.id;
                                      if (m.name.trim().isNotEmpty) {
                                        _customerCtrl.text = m.name.trim();
                                      }
                                    });
                                  }
                                },
                          icon: const Icon(Icons.link),
                          label: const Text('Odaberi kupca iz šifrarnika'),
                        ),
                        if (_linkedCustomerId != null &&
                            _linkedCustomerId!.trim().isNotEmpty)
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _linkedCustomerId = null),
                            child: const Text('Ukloni vezu s šifrarnikom'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 6,
              color: scheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : Text(
                                'Otvori NPI projekat',
                                style: tt.labelLarge?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Generirat će se šifra projekta i početni Stage-Gate zapisi prema pravilima tenant-a.',
                              textAlign: TextAlign.center,
                              style: tt.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 2),
                            child: OoeInfoIcon(
                              tooltip: DevelopmentHelpTexts.stageGateConceptTooltip,
                              dialogTitle: DevelopmentHelpTexts.stageGateConceptTitle,
                              dialogBody: DevelopmentHelpTexts.stageGateConceptBody,
                              iconSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
