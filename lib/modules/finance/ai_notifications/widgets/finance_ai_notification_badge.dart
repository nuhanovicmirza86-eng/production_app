import 'package:flutter/material.dart';

import '../services/finance_ai_notification_delivery_service.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';

/// Badge broj nepročitanih obavijesti — isključivo iz
/// [getFinanceAiNotificationBadgeSummary] (ne lokalni broj liste).
class FinanceAiNotificationBadge extends StatefulWidget {
  const FinanceAiNotificationBadge({
    super.key,
    required this.companyId,
    required this.companyData,
    this.plantKey = '',
    this.refreshListenable,
    this.child,
    this.debugUnlockModule = false,
  });

  final String companyId;
  final Map<String, dynamic> companyData;
  final String plantKey;
  final Listenable? refreshListenable;
  final Widget? child;
  final bool debugUnlockModule;

  @override
  State<FinanceAiNotificationBadge> createState() =>
      _FinanceAiNotificationBadgeState();
}

class _FinanceAiNotificationBadgeState extends State<FinanceAiNotificationBadge> {
  final _svc = FinanceAiNotificationDeliveryService();
  int _unreadCount = 0;
  bool _loading = true;

  String get _role => (widget.companyData['role'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewFinanceAiAdvisory(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  @override
  void initState() {
    super.initState();
    widget.refreshListenable?.addListener(_onRefresh);
    _loadBadge();
  }

  @override
  void didUpdateWidget(covariant FinanceAiNotificationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_onRefresh);
      widget.refreshListenable?.addListener(_onRefresh);
    }
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.plantKey != widget.plantKey) {
      _loadBadge();
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    _loadBadge();
  }

  Future<void> _loadBadge() async {
    if (!_canView || widget.companyId.trim().isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final summary = await _svc.getBadgeSummary(
        companyId: widget.companyId,
        plantKey: widget.plantKey.trim().isEmpty ? null : widget.plantKey.trim(),
      );
      if (!mounted) return;
      setState(() {
        _unreadCount = summary.unreadCount;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return widget.child ?? const SizedBox.shrink();
    }

    if (widget.child != null) {
      return Badge(
        isLabelVisible: !_loading && _unreadCount > 0,
        label: Text('$_unreadCount'),
        child: widget.child!,
      );
    }

    if (_loading || _unreadCount <= 0) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$_unreadCount',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onError,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Inline broj uz naslov sekcije.
class FinanceAiNotificationSectionBadge extends StatelessWidget {
  const FinanceAiNotificationSectionBadge({
    super.key,
    required this.companyId,
    required this.companyData,
    this.plantKey = '',
    this.refreshListenable,
    this.debugUnlockModule = false,
  });

  final String companyId;
  final Map<String, dynamic> companyData;
  final String plantKey;
  final Listenable? refreshListenable;
  final bool debugUnlockModule;

  @override
  Widget build(BuildContext context) {
    return FinanceAiNotificationBadge(
      companyId: companyId,
      companyData: companyData,
      plantKey: plantKey,
      refreshListenable: refreshListenable,
      debugUnlockModule: debugUnlockModule,
    );
  }
}
