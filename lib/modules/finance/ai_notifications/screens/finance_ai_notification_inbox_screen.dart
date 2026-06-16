import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../models/finance_ai_notification_delivery.dart';
import '../services/finance_ai_notification_delivery_service.dart';
import '../widgets/finance_ai_notification_badge.dart';
import '../widgets/finance_ai_notification_card.dart';
import '../widgets/finance_ai_notification_filters.dart';
import 'finance_ai_notification_delivery_detail_screen.dart';

/// Ugradivi inbox in-app obavijesti unutar Finance AI Assistant taba.
class FinanceAiNotificationInboxPanel extends StatefulWidget {
  const FinanceAiNotificationInboxPanel({
    super.key,
    required this.companyData,
    this.sessionPlantKey = '',
    this.debugUnlockModule = false,
    this.refreshListenable,
    this.onDeliveryChanged,
  });

  final Map<String, dynamic> companyData;
  final String sessionPlantKey;
  final bool debugUnlockModule;
  final Listenable? refreshListenable;
  final VoidCallback? onDeliveryChanged;

  @override
  State<FinanceAiNotificationInboxPanel> createState() =>
      _FinanceAiNotificationInboxPanelState();
}

class _FinanceAiNotificationInboxPanelState
    extends State<FinanceAiNotificationInboxPanel> {
  final _svc = FinanceAiNotificationDeliveryService();

  bool _showHistory = false;
  bool _unreadOnly = false;
  String? _severityMin;
  String _filterPlantKey = '';
  bool _loading = false;
  String? _error;
  List<FinanceAiNotificationDelivery> _allDeliveries = const [];
  Map<String, String> _plantLabels = const {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString().trim();

  String get _profilePlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewFinanceAiAdvisory(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canPickPlant => FinancePermissions.shouldUseHubPlantScopeSelector(
        role: _role,
        profilePlantKey: _profilePlantKey,
      );

  @override
  void initState() {
    super.initState();
    _filterPlantKey = widget.sessionPlantKey.trim();
    if (!_canPickPlant && _profilePlantKey.isNotEmpty) {
      _filterPlantKey = _profilePlantKey;
    }
    widget.refreshListenable?.addListener(_onExternalRefresh);
    _loadDeliveries();
  }

  @override
  void didUpdateWidget(covariant FinanceAiNotificationInboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_onExternalRefresh);
      widget.refreshListenable?.addListener(_onExternalRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    _loadDeliveries();
  }

  List<String> get _statusFilter {
    if (_unreadOnly) return const ['unread'];
    if (_showHistory) return const ['closed', 'superseded'];
    return const ['unread', 'read', 'acknowledged'];
  }

  int _severityRank(String severity) {
    switch (severity.trim().toLowerCase()) {
      case 'critical':
        return 3;
      case 'high':
        return 2;
      case 'medium':
        return 1;
      case 'info':
        return 0;
      default:
        return 0;
    }
  }

  bool _passesSeverity(FinanceAiNotificationDelivery d) {
    if (_severityMin == null) return true;
    return _severityRank(d.severity) >= _severityRank(_severityMin!);
  }

  Future<void> _loadDeliveries() async {
    if (!_canView || _companyId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listDeliveries(
        companyId: _companyId,
        status: _statusFilter,
        plantKey: _filterPlantKey.trim().isEmpty ? null : _filterPlantKey.trim(),
      );
      await _resolvePlantLabels(list);
      if (!mounted) return;
      setState(() {
        _allDeliveries = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resolvePlantLabels(List<FinanceAiNotificationDelivery> items) async {
    final keys = items
        .map((d) => d.plantKey.trim())
        .where((k) => k.isNotEmpty)
        .toSet();
    final labels = Map<String, String>.from(_plantLabels);
    for (final pk in keys) {
      if (labels.containsKey(pk)) continue;
      labels[pk] = await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: pk,
      );
    }
    _plantLabels = labels;
  }

  Future<void> _openDetail(FinanceAiNotificationDelivery delivery) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceAiNotificationDeliveryDetailScreen(
          companyData: widget.companyData,
          deliveryId: delivery.deliveryId,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) {
      await _loadDeliveries();
      widget.onDeliveryChanged?.call();
    }
  }

  void _notifyChanged() {
    _loadDeliveries();
    widget.onDeliveryChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final visible = _allDeliveries.where(_passesSeverity).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                FinanceStrings.t(context, 'notification_section_title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FinanceAiNotificationSectionBadge(
              companyId: _companyId,
              companyData: widget.companyData,
              plantKey: _filterPlantKey,
              refreshListenable: widget.refreshListenable,
              debugUnlockModule: widget.debugUnlockModule,
            ),
          ],
        ),
        const SizedBox(height: 8),
        FinanceAiNotificationFilters(
          companyId: _companyId,
          companyData: widget.companyData,
          role: _role,
          profilePlantKey: _profilePlantKey,
          filterPlantKey: _filterPlantKey,
          showHistory: _showHistory,
          unreadOnly: _unreadOnly,
          severityMin: _severityMin,
          onPlantChanged: (v) {
            setState(() => _filterPlantKey = v);
            _notifyChanged();
          },
          onHistoryChanged: (v) {
            setState(() => _showHistory = v);
            _loadDeliveries();
          },
          onUnreadOnlyChanged: (v) {
            setState(() => _unreadOnly = v);
            _loadDeliveries();
          },
          onSeverityChanged: (v) {
            setState(() => _severityMin = v);
          },
        ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_error != null)
          Text(
            FinanceStrings.t(context, 'notification_load_error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (visible.isEmpty)
          Text(
            FinanceStrings.t(context, 'notification_empty'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...visible.map((delivery) {
            final pk = delivery.plantKey.trim();
            return FinanceAiNotificationCard(
              delivery: delivery,
              plantDisplayName: pk.isEmpty ? null : (_plantLabels[pk] ?? pk),
              onTap: () => _openDetail(delivery),
            );
          }),
      ],
    );
  }
}
