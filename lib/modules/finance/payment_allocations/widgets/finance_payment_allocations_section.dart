import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_payment_allocation.dart';
import '../services/finance_payment_allocations_service.dart';
import '../widgets/finance_allocation_list.dart';
import '../screens/finance_payment_allocation_detail_screen.dart';

/// Sekcija alokacija plaćanja (faktura ili transakcija).
class FinancePaymentAllocationsSection extends StatefulWidget {
  const FinancePaymentAllocationsSection({
    super.key,
    required this.companyData,
    required this.debugUnlockModule,
    required this.mode,
    this.invoiceId,
    this.invoiceType,
    this.transactionId,
    this.onChanged,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;
  final FinancePaymentAllocationsSectionMode mode;
  final String? invoiceId;
  final String? invoiceType;
  final String? transactionId;
  final VoidCallback? onChanged;

  @override
  State<FinancePaymentAllocationsSection> createState() =>
      FinancePaymentAllocationsSectionState();
}

enum FinancePaymentAllocationsSectionMode { invoice, transaction }

class FinancePaymentAllocationsSectionState
    extends State<FinancePaymentAllocationsSection> {
  final _service = FinancePaymentAllocationsService();
  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;
  List<FinancePaymentAllocation> _items = const [];
  double _activeTotal = 0;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewPaymentAllocations(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  bool get _canCancel => FinancePermissions.canCancelPaymentAllocation(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  @override
  void initState() {
    super.initState();
    if (_canView) _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final FinancePaymentAllocationListResult result;
      if (widget.mode == FinancePaymentAllocationsSectionMode.invoice) {
        result = await _service.getInvoiceAllocations(
          companyId: _companyId,
          invoiceId: widget.invoiceId!.trim(),
          invoiceType: widget.invoiceType!.trim(),
          activeOnly: false,
        );
      } else {
        result = await _service.getTransactionAllocations(
          companyId: _companyId,
          transactionId: widget.transactionId!.trim(),
          activeOnly: false,
        );
      }
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _activeTotal = result.activeAllocatedTotal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = FinanceErrorMapper.toMessage(e, context: context);
      });
    }
  }

  Future<void> _cancelItem(FinancePaymentAllocation item) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final ok = await showFinanceCancelAllocationDialog(
        context: context,
        companyId: _companyId,
        allocation: item,
      );
      if (!ok || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'allocation_cancelled'))),
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _openDetail(FinancePaymentAllocation item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinancePaymentAllocationDetailScreen(
          companyData: widget.companyData,
          allocation: item,
          debugUnlockModule: widget.debugUnlockModule,
          onChanged: () {
            _load();
            widget.onChanged?.call();
          },
        ),
      ),
    );
    if (changed == true) {
      await _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                FinanceStrings.t(context, 'payment_allocations_section'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: FinanceStrings.t(context, 'refresh'),
              onPressed: _loading || _actionInProgress ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!_loading && _error == null)
          FinanceAllocationList(
            items: _items,
            activeAllocatedTotal: _activeTotal,
            canCancel: _canCancel,
            actionInProgress: _actionInProgress,
            onCancel: _cancelItem,
            onTap: _openDetail,
            showInvoiceColumn:
                widget.mode == FinancePaymentAllocationsSectionMode.transaction,
            showTransactionColumn:
                widget.mode == FinancePaymentAllocationsSectionMode.invoice,
          ),
      ],
    );
  }
}
