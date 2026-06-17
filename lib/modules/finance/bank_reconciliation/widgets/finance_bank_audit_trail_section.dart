import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_help_info_button.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_bank_audit_trail_entry.dart';
import '../utils/finance_bank_audit_trail_labels.dart';

class FinanceBankAuditTrailSection extends StatelessWidget {
  const FinanceBankAuditTrailSection({
    super.key,
    required this.entries,
    this.warning,
    this.loading = false,
    this.onRefresh,
  });

  final List<FinanceBankAuditTrailEntry> entries;
  final String? warning;
  final bool loading;
  final VoidCallback? onRefresh;

  String _formatDateTime(BuildContext context, DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).add_Hm().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FinanceHelpSectionTitle(
                title: FinanceStrings.t(context, 'bank_audit_trail_title'),
                helpTitleKey: 'help_bank_audit_trail_title',
                helpBodyKey: 'help_bank_audit_trail_body',
              ),
            ),
            if (onRefresh != null)
              IconButton(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: FinanceStrings.t(context, 'refresh'),
              ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ] else if (warning != null) ...[
          const SizedBox(height: 8),
          Text(
            warning!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ] else if (entries.isEmpty) ...[
          const SizedBox(height: 8),
          Text(FinanceStrings.t(context, 'bank_audit_trail_empty')),
        ] else ...[
          const SizedBox(height: 8),
          ...entries.map((entry) => _AuditTrailCard(
                entry: entry,
                formatDateTime: (d) => _formatDateTime(context, d),
              )),
        ],
      ],
    );
  }
}

class _AuditTrailCard extends StatefulWidget {
  const _AuditTrailCard({
    required this.entry,
    required this.formatDateTime,
  });

  final FinanceBankAuditTrailEntry entry;
  final String Function(DateTime?) formatDateTime;

  @override
  State<_AuditTrailCard> createState() => _AuditTrailCardState();
}

class _AuditTrailCardState extends State<_AuditTrailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final afterSummary = FinanceBankAuditTrailLabels.summaryFromAfter(
      entry.afterDisplay ?? entry.after,
    );
    final performer = FinanceBankAuditTrailLabels.performerLabel(
      email: entry.performedByEmail,
      role: entry.performedByRole,
    );
    final entityLabel = entry.entityDisplayLabel ??
        FinanceBankAuditTrailLabels.entityTypeLabel(
          context,
          entry.entityType,
        );
    final relatedLabels = entry.relatedEntityDisplays;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                FinanceBankAuditTrailLabels.actionLabel(
                  context,
                  entry.actionType,
                ),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.formatDateTime(entry.performedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${FinanceStrings.t(context, 'audit_performed_by')}: $performer',
              ),
              Text('${FinanceStrings.t(context, 'audit_entity_type')}: $entityLabel'),
              if (entry.reason != null && entry.reason!.isNotEmpty)
                Text(
                  '${FinanceStrings.t(context, 'bank_match_cancel_reason')}: ${entry.reason}',
                ),
              if (afterSummary != null)
                Text(
                  '${FinanceStrings.t(context, 'filter_status')}: '
                  '${FinanceDisplayLabels.reconciliationStatus(context, afterSummary)}',
                ),
              if (_expanded) ...[
                const Divider(height: 20),
                if (entry.source != null)
                  _detailRow(
                    context,
                    FinanceStrings.t(context, 'audit_source'),
                    FinanceBankAuditTrailLabels.sourceLabel(
                      context,
                      entry.source,
                    ),
                  ),
                if (relatedLabels.isNotEmpty)
                  _detailRow(
                    context,
                    FinanceStrings.t(context, 'audit_related_entities'),
                    relatedLabels.join('\n'),
                  ),
                if (entry.beforeDisplay != null &&
                    entry.beforeDisplay!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    FinanceStrings.t(context, 'audit_before'),
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    FinanceBankAuditTrailLabels.formatDisplayMap(
                      context,
                      entry.beforeDisplay!,
                    ),
                  ),
                ],
                if (entry.afterDisplay != null &&
                    entry.afterDisplay!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    FinanceStrings.t(context, 'audit_after'),
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    FinanceBankAuditTrailLabels.formatDisplayMap(
                      context,
                      entry.afterDisplay!,
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  FinanceStrings.t(context, 'bank_audit_trail_tap_detail'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
