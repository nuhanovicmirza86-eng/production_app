import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../../ai_advisory/widgets/finance_ai_severity_chip.dart';
import '../models/finance_ai_notification_delivery.dart';

class FinanceAiNotificationCard extends StatelessWidget {
  const FinanceAiNotificationCard({
    super.key,
    required this.delivery,
    required this.onTap,
    this.plantDisplayName,
    this.summary,
  });

  final FinanceAiNotificationDelivery delivery;
  final VoidCallback onTap;
  final String? plantDisplayName;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale).add_Hm();
    final isHighPriority =
        delivery.severity == 'critical' || delivery.severity == 'high';
    final borderColor = delivery.isUnread
        ? cs.primary.withValues(alpha: 0.55)
        : (isHighPriority
            ? cs.error.withValues(alpha: 0.45)
            : cs.outlineVariant);

    final deliveredAt = delivery.lastDeliveredAt ?? delivery.firstDeliveredAt;
    final plantScope = delivery.plantKey.trim().isEmpty
        ? FinanceStrings.t(context, 'notification_scope_company_wide')
        : FinanceStrings.t(context, 'notification_plant_scope')
            .replaceAll('{plant}', plantDisplayName ?? delivery.plantKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: delivery.isUnread ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (delivery.isUnread)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: Icon(Icons.circle, size: 10, color: cs.primary),
                    ),
                  Expanded(
                    child: Text(
                      delivery.headline.isNotEmpty
                          ? delivery.headline
                          : FinanceDisplayLabels.advisoryRuleId(
                              context,
                              delivery.ruleId,
                            ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FinanceAiSeverityChip(
                    severity: delivery.severity,
                    compact: true,
                  ),
                ],
              ),
              if ((summary ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  summary!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      FinanceDisplayLabels.notificationDeliveryStatus(
                        context,
                        delivery.deliveryStatus,
                      ),
                    ),
                  ),
                  if (delivery.alertStatus.trim().isNotEmpty)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        FinanceDisplayLabels.advisoryStatus(
                          context,
                          delivery.alertStatus,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                FinanceStrings.t(context, 'notification_generation_revision')
                    .replaceAll('{gen}', '${delivery.deliveryGeneration}')
                    .replaceAll('{rev}', delivery.alertRevision.isNotEmpty
                        ? delivery.alertRevision
                        : '—'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                deliveredAt != null
                    ? FinanceStrings.t(context, 'notification_delivered_at')
                        .replaceAll('{time}', df.format(deliveredAt.toLocal()))
                    : '—',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                plantScope,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
