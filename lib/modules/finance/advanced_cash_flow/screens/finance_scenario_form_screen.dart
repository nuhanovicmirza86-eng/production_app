import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_context_factory.dart';
import '../../shared/finance_date_picker_field.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_help_info_button.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario.dart';
import '../services/finance_cash_flow_scenario_service.dart';
import '../widgets/finance_scenario_assumptions_section.dart';

class FinanceScenarioFormScreen extends StatefulWidget {
  const FinanceScenarioFormScreen({
    super.key,
    required this.companyData,
    this.scenario,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinanceCashFlowScenario? scenario;
  final bool debugUnlockModule;

  bool get isEdit => scenario != null;

  @override
  State<FinanceScenarioFormScreen> createState() =>
      _FinanceScenarioFormScreenState();
}

class _FinanceScenarioFormScreenState extends State<FinanceScenarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FinanceCashFlowScenarioService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _plantCtrl = TextEditingController();
  final _requestId = const Uuid().v4();

  bool _saving = false;
  String _scenarioType = 'base';
  DateTime? _periodFrom;
  DateTime? _periodTo;
  Map<String, double?> _whatIfValues = {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final s = widget.scenario;
    if (s != null) {
      _nameCtrl.text = s.name;
      _descCtrl.text = s.description ?? '';
      _plantCtrl.text = s.plantKey ?? '';
      _scenarioType = s.scenarioType;
      _periodFrom = s.periodFrom;
      _periodTo = s.periodTo;
      if (s.isWhatIf) {
        for (final e in s.assumptions.entries.entries) {
          _whatIfValues[e.key] = e.value.value;
        }
      }
    } else {
      final now = DateTime.now();
      _periodFrom = DateTime(now.year, now.month, now.day);
      _periodTo = _periodFrom!.add(const Duration(days: 29));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _plantCtrl.dispose();
    super.dispose();
  }

  String _assistantScreenKey() {
    switch (_scenarioType) {
      case 'optimistic':
        return FinanceAssistantScreens.scenarioOptimistic;
      case 'pessimistic':
        return FinanceAssistantScreens.scenarioPessimistic;
      case 'what_if':
        return FinanceAssistantScreens.whatIf;
      default:
        return FinanceAssistantScreens.scenarioBase;
    }
  }

  Map<String, dynamic>? _whatIfPayload() {
    if (_scenarioType != 'what_if') return null;
    final out = <String, dynamic>{};
    for (final key in _WhatIfCreateFields.fieldKeys) {
      out[key] = _whatIfValues[key];
    }
    return out;
  }

  void _initWhatIfDefaults() {
    for (final key in _WhatIfCreateFields.fieldKeys) {
      if (key == 'minimumLiquidityThreshold') {
        _whatIfValues[key] = null;
      } else {
        _whatIfValues[key] = 0;
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_periodFrom == null || _periodTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'scenario_period_required'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await _service.updateScenario(
          companyId: _companyId,
          scenarioId: widget.scenario!.scenarioId,
          name: _nameCtrl.text,
          description: _descCtrl.text,
          plantKey: _plantCtrl.text,
          whatIfAssumptions: _whatIfPayload(),
          expectedRevision: widget.scenario!.revision,
        );
      } else {
        await _service.createScenario(
          companyId: _companyId,
          name: _nameCtrl.text,
          description: _descCtrl.text,
          scenarioType: _scenarioType,
          plantKey: _plantCtrl.text,
          periodFrom: _periodFrom,
          periodTo: _periodTo,
          whatIfAssumptions: _whatIfPayload(),
          requestId: _requestId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = FinanceErrorMapper.toMessage(e, context: context);
      final hint = FinanceErrorMapper.isConcurrencyAborted(e)
          ? '\n${FinanceErrorMapper.concurrencyHint(context)}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg$hint')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canManageCashFlowScenarios(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContextFactory.fromCompany(
          context: context,
          companyData: widget.companyData,
          screenKey: _assistantScreenKey(),
          tabKey: FinanceAssistantTabs.advancedCashFlow,
        ),
        appBar: AppBar(
          title: Text(
            widget.isEdit
                ? FinanceStrings.t(context, 'scenario_edit')
                : FinanceStrings.t(context, 'scenario_new'),
          ),
        ),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    final whatIfAssumptions = widget.scenario?.assumptions;

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: _assistantScreenKey(),
        tabKey: FinanceAssistantTabs.advancedCashFlow,
        tabLabelKey: 'help_advanced_cash_flow_tab_title',
      ),
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? FinanceStrings.t(context, 'scenario_edit')
              : FinanceStrings.t(context, 'scenario_new'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'scenario_name'),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? FinanceStrings.t(context, 'scenario_name_required')
                      : null,
            ),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'scenario_description'),
              ),
              maxLines: 3,
            ),
            if (!widget.isEdit)
              DropdownButtonFormField<String>(
                value: _scenarioType,
                decoration: InputDecoration(
                  labelText: FinanceStrings.t(context, 'scenario_type'),
                ),
                items: FinanceDisplayLabels.scenarioTypeCodes.map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(
                      FinanceDisplayLabels.scenarioType(context, code),
                    ),
                  ),
                ).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _scenarioType = v;
                      if (v == 'what_if' && _whatIfValues.isEmpty) {
                        _initWhatIfDefaults();
                      }
                    });
                  }
                },
              ),
            const SizedBox(height: 8),
            FinanceDatePickerField(
              label: FinanceStrings.t(context, 'date_from'),
              value: _periodFrom,
              lastDate: _periodTo,
              onChanged: (d) => setState(() => _periodFrom = d),
            ),
            FinanceDatePickerField(
              label: FinanceStrings.t(context, 'date_to'),
              value: _periodTo,
              firstDate: _periodFrom,
              onChanged: (d) => setState(() => _periodTo = d),
            ),
            TextFormField(
              controller: _plantCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'scenario_plant_or_all'),
              ),
            ),
            if (_scenarioType == 'what_if') ...[
              const SizedBox(height: 16),
              if (widget.isEdit && whatIfAssumptions != null)
                FinanceScenarioAssumptionsSection(
                  assumptions: whatIfAssumptions,
                  readOnly: false,
                  onWhatIfChanged: (key, value) {
                    _whatIfValues[key] = value;
                  },
                )
              else
                _WhatIfCreateFields(
                  values: _whatIfValues,
                  onChanged: (key, value) => _whatIfValues[key] = value,
                ),
            ] else if (!widget.isEdit)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  FinanceStrings.t(context, 'scenario_preset_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(FinanceStrings.t(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatIfCreateFields extends StatelessWidget {
  const _WhatIfCreateFields({
    required this.values,
    required this.onChanged,
  });

  static const fieldKeys = [
    'receivableDelayDays',
    'payableDelayDays',
    'receivableProbabilityAdjustment',
    'payableProbabilityAdjustment',
    'plannedInflowAdjustmentPercent',
    'plannedOutflowAdjustmentPercent',
    'minimumLiquidityThreshold',
  ];

  final Map<String, double?> values;
  final void Function(String key, double? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FinanceStrings.t(context, 'scenario_what_if_fields'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final key in fieldKeys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: values[key]?.toString() ?? '',
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: FinanceStrings.t(
                        context,
                        'scenario_assumption_${key}_title',
                      ),
                    ),
                    onChanged: (v) {
                      if (v.trim().isEmpty) {
                        onChanged(key, null);
                        return;
                      }
                      onChanged(key, double.tryParse(v.replaceAll(',', '.')));
                    },
                  ),
                ),
                FinanceHelpInfoButton(
                  titleKey: 'scenario_assumption_${key}_title',
                  bodyKey: 'scenario_assumption_${key}_body',
                  iconSize: 18,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
