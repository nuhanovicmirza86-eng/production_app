import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_category.dart';
import '../services/finance_cash_flow_categories_service.dart';
import 'finance_cash_flow_category_form_screen.dart';

class FinanceCashFlowCategoriesScreen extends StatefulWidget {
  const FinanceCashFlowCategoriesScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceCashFlowCategoriesScreen> createState() =>
      _FinanceCashFlowCategoriesScreenState();
}

class _FinanceCashFlowCategoriesScreenState
    extends State<FinanceCashFlowCategoriesScreen> {
  final _service = FinanceCashFlowCategoriesService();
  bool _loading = true;
  String? _error;
  bool _activeOnly = true;
  List<FinanceCashFlowCategory> _categories = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canManage => FinancePermissions.canManageCashFlowMasterData(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

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
      final items = await _service.listCategories(
        companyId: _companyId,
        activeOnly: _activeOnly,
      );
      if (!mounted) return;
      setState(() {
        _categories = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
      });
    }
  }

  Future<void> _openForm({FinanceCashFlowCategory? category}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceCashFlowCategoryFormScreen(
          companyData: widget.companyData,
          category: category,
        ),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _deactivate(FinanceCashFlowCategory category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(ctx, 'deactivate_category')),
        content: Text(FinanceStrings.t(ctx, 'deactivate_category_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(FinanceStrings.t(ctx, 'deactivate_category')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _service.deactivateCategory(
        companyId: _companyId,
        categoryId: category.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'deactivated'))),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canAccessCashFlowOperative(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContextFactory.fromCompany(
          context: context,
          companyData: widget.companyData,
          screenKey: FinanceAssistantScreens.categoriesList,
          tabKey: FinanceAssistantTabs.cashFlow,
          tabLabelKey: 'help_cash_flow_tab_title',
        ),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'categories_title')),
        ),
        body: Center(
          child: Text(FinanceStrings.t(context, 'access_denied')),
        ),
      );
    }

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.categoriesList,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
        actions: FinanceAssistantContextFactory.createAndRefresh(
          createKey: 'category_new',
          canCreate: _canManage,
        ),
      ),
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'categories_title')),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: FinanceStrings.t(context, 'category_new'),
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
          IconButton(
            tooltip: FinanceStrings.t(context, 'refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: Text(FinanceStrings.t(context, 'filter_active_only')),
            value: _activeOnly,
            onChanged: _loading
                ? null
                : (v) {
                    setState(() => _activeOnly = v);
                    _load();
                  },
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (_categories.isEmpty) {
      return Center(
        child: Text(FinanceStrings.t(context, 'categories_empty')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = _categories[index];
          return ListTile(
            title: Text(c.name),
            subtitle: Text(
              '${c.categoryCode} · ${FinanceDisplayLabels.activityType(context, c.cashFlowActivityType)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    c.active
                        ? FinanceStrings.t(context, 'active')
                        : FinanceStrings.t(context, 'inactive'),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                if (_canManage && c.active)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        _openForm(category: c);
                      } else if (v == 'deactivate') {
                        _deactivate(c);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(FinanceStrings.t(ctx, 'category_edit')),
                      ),
                      PopupMenuItem(
                        value: 'deactivate',
                        child: Text(FinanceStrings.t(ctx, 'deactivate_category')),
                      ),
                    ],
                  ),
              ],
            ),
            onTap: _canManage && c.active ? () => _openForm(category: c) : null,
          );
        },
      ),
    );
  }
}
