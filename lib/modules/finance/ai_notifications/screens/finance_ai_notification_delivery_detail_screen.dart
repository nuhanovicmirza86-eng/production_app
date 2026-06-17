import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../ai_advisory/models/finance_ai_alert.dart';
import '../../ai_advisory/screens/finance_ai_alert_detail_screen.dart';
import '../../ai_advisory/services/finance_ai_advisory_service.dart';
import '../../ai_advisory/widgets/finance_ai_severity_chip.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../models/finance_ai_notification_delivery.dart';
import '../services/finance_ai_notification_delivery_service.dart';

class FinanceAiNotificationDeliveryDetailScreen extends StatefulWidget {
  const FinanceAiNotificationDeliveryDetailScreen({
    super.key,
    required this.companyData,
    required this.deliveryId,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String deliveryId;
  final bool debugUnlockModule;

  @override
  State<FinanceAiNotificationDeliveryDetailScreen> createState() =>
      _FinanceAiNotificationDeliveryDetailScreenState();
}

class _FinanceAiNotificationDeliveryDetailScreenState
    extends State<FinanceAiNotificationDeliveryDetailScreen> {
  final _deliverySvc = FinanceAiNotificationDeliveryService();
  final _alertSvc = FinanceAiAdvisoryService();

  FinanceAiNotificationDelivery? _delivery;
  FinanceAiAlert? _alert;
  String? _plantLabel;
  bool _loading = true;
  bool _markingRead = false;
  String? _error;
  bool _changed = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

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
      final delivery = await _deliverySvc.getDelivery(
        companyId: _companyId,
        deliveryId: widget.deliveryId,
      );
      FinanceAiAlert? alert;
      try {
        alert = await _alertSvc.getAlert(
          companyId: _companyId,
          alertId: delivery.alertId,
        );
      } catch (_) {
        alert = null;
      }
      String? plantLabel;
      final pk = delivery.plantKey.trim();
      if (pk.isNotEmpty) {
        plantLabel = await CompanyPlantDisplayName.resolve(
          companyId: _companyId,
          plantKey: pk,
        );
      }
      if (!mounted) return;
      setState(() {
        _delivery = delivery;
        _alert = alert;
        _plantLabel = plantLabel;
        _loading = false;
      });
      if (delivery.isUnread) {
        await _markRead(silent: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _markRead({bool silent = false}) async {
    final delivery = _delivery;
    if (delivery == null || _markingRead || !delivery.isUnread) return;
    setState(() => _markingRead = true);
    try {
      await _deliverySvc.markDeliveryRead(
        companyId: _companyId,
        deliveryId: delivery.deliveryId,
      );
      _changed = true;
      final refreshed = await _deliverySvc.getDelivery(
        companyId: _companyId,
        deliveryId: delivery.deliveryId,
      );
      if (!mounted) return;
      setState(() {
        _delivery = refreshed;
        _markingRead = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FinanceStrings.t(context, 'notification_marked_read')),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _markingRead = false);
      if (!silent) _showError(e.message ?? '$e');
    } catch (e) {
      if (!mounted) return;
      setState(() => _markingRead = false);
      if (!silent) _showError('$e');
    }
  }

  Future<void> _openAlertDetail() async {
    final delivery = _delivery;
    if (delivery == null || delivery.alertId.trim().isEmpty) return;
    if (_alert == null) {
      _showError(FinanceStrings.t(context, 'notification_alert_unavailable'));
      return;
    }
    final alertChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceAiAlertDetailScreen(
          companyData: widget.companyData,
          alertId: delivery.alertId,
          initialAlert: _alert,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (alertChanged == true) {
      _changed = true;
      await _load();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale).add_Hm();
    final delivery = _delivery;
    final alert = _alert;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: FinanceScaffold(
        assistantContext: FinanceAssistantContextFactory.fromCompany(
          context: context,
          companyData: widget.companyData,
          screenKey: FinanceAssistantScreens.aiNotificationDeliveryDetail,
          tabKey: FinanceAssistantTabs.aiAnalysis,
          tabLabelKey: 'finance_ai_analysis_title',
          entityStatus: delivery == null
              ? null
              : FinanceDisplayLabels.notificationDeliveryStatus(
                  context,
                  delivery.deliveryStatus,
                ),
          actions: FinanceAssistantContextFactory.refreshOnly(),
        ),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'notification_detail_title')),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        FinanceStrings.t(context, 'notification_load_error'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.error,
                        ),
                      ),
                    ),
                  )
                : delivery == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  delivery.headline.isNotEmpty
                                      ? delivery.headline
                                      : FinanceDisplayLabels.advisoryRuleId(
                                          context,
                                          delivery.ruleId,
                                        ),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              FinanceAiSeverityChip(severity: delivery.severity),
                            ],
                          ),
                          if ((alert?.summary ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              alert!.summary.trim(),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _infoRow(
                            context,
                            FinanceStrings.t(context, 'notification_delivery_status'),
                            FinanceDisplayLabels.notificationDeliveryStatus(
                              context,
                              delivery.deliveryStatus,
                            ),
                          ),
                          _infoRow(
                            context,
                            FinanceStrings.t(context, 'advisory_filter_status'),
                            FinanceDisplayLabels.advisoryStatus(
                              context,
                              delivery.alertStatus,
                            ),
                          ),
                          _infoRow(
                            context,
                            FinanceStrings.t(context, 'notification_scope_label'),
                            delivery.plantKey.trim().isEmpty
                                ? FinanceStrings.t(
                                    context,
                                    'notification_scope_company_wide',
                                  )
                                : FinanceStrings.t(context, 'notification_plant_scope')
                                    .replaceAll(
                                      '{plant}',
                                      _plantLabel ?? delivery.plantKey,
                                    ),
                          ),
                          _infoRow(
                            context,
                            FinanceStrings.t(context, 'notification_generation_revision'),
                            FinanceStrings.t(context, 'notification_generation_revision')
                                .replaceAll('{gen}', '${delivery.deliveryGeneration}')
                                .replaceAll(
                                  '{rev}',
                                  delivery.alertRevision.isNotEmpty
                                      ? delivery.alertRevision
                                      : '—',
                                ),
                          ),
                          if (delivery.lastDeliveredAt != null)
                            _infoRow(
                              context,
                              FinanceStrings.t(context, 'notification_delivered_at')
                                  .split(':')
                                  .first,
                              df.format(delivery.lastDeliveredAt!.toLocal()),
                            ),
                          if (delivery.isClosed && delivery.closedReason.isNotEmpty)
                            _infoRow(
                              context,
                              FinanceStrings.t(context, 'notification_closed_reason'),
                              delivery.closedReason,
                            ),
                          const SizedBox(height: 20),
                          if (delivery.isUnread)
                            FilledButton.tonalIcon(
                              onPressed: _markingRead ? null : () => _markRead(),
                              icon: _markingRead
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.mark_email_read_outlined),
                              label: Text(
                                FinanceStrings.t(context, 'notification_mark_read'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: delivery.alertId.trim().isEmpty || _alert == null
                                ? null
                                : _openAlertDetail,
                            icon: const Icon(Icons.open_in_new_outlined),
                            label: Text(
                              FinanceStrings.t(context, 'notification_open_alert'),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
