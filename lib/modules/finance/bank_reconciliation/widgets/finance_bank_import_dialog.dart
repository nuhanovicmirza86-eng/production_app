import 'package:flutter/material.dart';

import '../../../finance_integrations/models/finance_connection_model.dart';
import '../../../finance_integrations/services/finance_connection_service.dart';
import '../../accounts/models/finance_account.dart';
import '../../accounts/services/finance_accounts_service.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_help_info_button.dart';
import '../../shared/finance_labeled_filter_field.dart';
import '../../shared/finance_strings.dart';
import '../services/finance_bank_reconciliation_service.dart';

/// Vraća poruku uspjeha za SnackBar, ili `null` ako korisnik odustane.
Future<String?> showFinanceBankImportDialog({
  required BuildContext context,
  required String companyId,
  required FinanceBankReconciliationService service,
}) async {
  final connectionsService = FinanceConnectionService();
  final accountsService = FinanceAccountsService();

  final connections = await connectionsService.watchConnections(companyId).first;
  final accounts = await accountsService.listAccounts(
    companyId: companyId,
    activeOnly: true,
  );

  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FinanceBankImportDialog(
      companyId: companyId,
      service: service,
      connections: connections,
      accounts: accounts,
    ),
  );
}

class _FinanceBankImportDialog extends StatefulWidget {
  const _FinanceBankImportDialog({
    required this.companyId,
    required this.service,
    required this.connections,
    required this.accounts,
  });

  final String companyId;
  final FinanceBankReconciliationService service;
  final List<FinanceConnectionModel> connections;
  final List<FinanceAccount> accounts;

  @override
  State<_FinanceBankImportDialog> createState() =>
      _FinanceBankImportDialogState();
}

class _FinanceBankImportDialogState extends State<_FinanceBankImportDialog> {
  String? _connectionId;
  String? _bankAccountId;
  bool _running = false;
  String? _errorMessage;

  Widget _dropdownText(String text) {
    return Text(text, overflow: TextOverflow.ellipsis, maxLines: 1);
  }

  String _successMessage(Map<String, dynamic> result) {
    final status = (result['status'] ?? '').toString().toLowerCase();
    final created = _intField(result, 'createdCount');
    final updated = _intField(result, 'updatedCount');
    final failed = _intField(result, 'failedCount');

    if (status == 'partial') {
      return FinanceStrings.t(context, 'bank_import_partial')
          .replaceAll('{failed}', '$failed');
    }
    if (created > 0 || updated > 0) {
      return FinanceStrings.t(context, 'bank_import_success_detail')
          .replaceAll('{created}', '$created')
          .replaceAll('{updated}', '$updated');
    }
    return FinanceStrings.t(context, 'bank_import_success');
  }

  int _intField(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _runImport() async {
    final conn = _connectionId;
    final acc = _bankAccountId;
    if (conn == null || conn.isEmpty || acc == null || acc.isEmpty) return;

    setState(() {
      _running = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.service.runBankStatementImport(
        companyId: widget.companyId,
        connectionId: conn,
        bankAccountId: acc,
      );
      if (!mounted) return;

      final status = (result['status'] ?? '').toString().toLowerCase();
      if (status == 'failed') {
        final summary = (result['errorSummary'] ?? '').toString().trim();
        setState(() {
          _errorMessage = summary.isNotEmpty
              ? summary
              : FinanceStrings.t(context, 'bank_import_failed');
          _running = false;
        });
        return;
      }

      final message = _successMessage(result);
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = FinanceErrorMapper.toMessage(e, context: context);
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankAccounts = widget.accounts
        .where((a) => a.accountType == 'transactional' || a.iban != null)
        .toList();
    final maxWidth = MediaQuery.sizeOf(context).width * 0.92;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              FinanceStrings.t(context, 'bank_import_title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const FinanceHelpInfoButton(
            titleKey: 'help_bank_import_title',
            bodyKey: 'help_bank_import_body',
          ),
        ],
      ),
      content: SizedBox(
        width: maxWidth.clamp(280, 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceLabeledFilterField(
              label: FinanceStrings.t(context, 'bank_import_connection'),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _connectionId,
                decoration: financeFilterInputDecoration(),
                items: widget.connections
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: _dropdownText(c.connectionName),
                      ),
                    )
                    .toList(),
                onChanged: _running
                    ? null
                    : (v) => setState(() => _connectionId = v),
              ),
            ),
            const SizedBox(height: 12),
            FinanceLabeledFilterField(
              label: FinanceStrings.t(context, 'bank_import_account'),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _bankAccountId,
                decoration: financeFilterInputDecoration(),
                items: bankAccounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: _dropdownText('${a.accountCode} · ${a.name}'),
                      ),
                    )
                    .toList(),
                onChanged: _running
                    ? null
                    : (v) => setState(() => _bankAccountId = v),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.pop(context),
          child: Text(FinanceStrings.t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: _running ||
                  _connectionId == null ||
                  _bankAccountId == null
              ? null
              : _runImport,
          child: _running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(FinanceStrings.t(context, 'bank_import')),
        ),
      ],
    );
  }
}
