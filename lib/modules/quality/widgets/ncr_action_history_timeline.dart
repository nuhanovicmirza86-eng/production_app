import 'package:flutter/material.dart';

import '../models/ncr_action_history_models.dart';

/// M1-I13-D — poslovni prikaz ledger historije akcija (odvojeno od I12 hodograma).
class NcrActionHistoryTimeline extends StatelessWidget {
  const NcrActionHistoryTimeline({
    super.key,
    required this.entries,
    this.loading = false,
    this.error,
    this.showNcrHeader = false,
    this.onNcrTap,
    this.onRetry,
    this.compact = false,
  });

  final List<NcrActionHistoryHubRow> entries;
  final bool loading;
  final String? error;
  final bool showNcrHeader;
  final void Function(String ncrId)? onNcrTap;
  final VoidCallback? onRetry;
  final bool compact;

  static const emptyMessage =
      'Još nema evidentiranih akcija za ovu neusklađenost.';

  static const hubEmptyMessage =
      'Još nema evidentiranih akcija za neusaglašenosti u odabranom pregledu.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Historija akcija',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Poslovni zapis svih akcija na neusaglašenosti — ko, šta, rok i izvor.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && error!.trim().isNotEmpty)
              _ErrorBlock(message: error!, onRetry: onRetry)
            else if (entries.isEmpty)
              _EmptyBlock(
                message: showNcrHeader ? hubEmptyMessage : emptyMessage,
              )
            else
              ...List.generate(entries.length, (index) {
                final row = entries[index];
                final isLast = index == entries.length - 1;
                return _HistoryEntryTile(
                  entry: row.entry,
                  ncrDocumentNo: showNcrHeader ? row.ncrDocumentNo : null,
                  ncrStatusLabel: showNcrHeader ? row.ncrStatusLabel : null,
                  onNcrTap: showNcrHeader && onNcrTap != null
                      ? () => onNcrTap!(row.ncrId)
                      : null,
                  showConnector: !isLast,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({
    required this.entry,
    this.ncrDocumentNo,
    this.ncrStatusLabel,
    this.onNcrTap,
    required this.showConnector,
  });

  final NcrActionHistoryEntry entry;
  final String? ncrDocumentNo;
  final String? ncrStatusLabel;
  final VoidCallback? onNcrTap;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value.trim().isEmpty ? '—' : value,
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: InkWell(
                  onTap: onNcrTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (ncrDocumentNo != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ncrDocumentNo!,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if ((ncrStatusLabel ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    ncrStatusLabel!,
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (onNcrTap != null)
                                Icon(
                                  Icons.chevron_right,
                                  color: scheme.onSurfaceVariant,
                                  size: 20,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          entry.occurredAt,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        row('Korak', entry.stepLabel),
                        row('Akcija', entry.actionLabel),
                        row('Odgovorna osoba', entry.ownerLabel),
                        row('Izvršilac', entry.executorLabel),
                        row('Rok', entry.dueLabel),
                        row('Status', entry.statusLabel),
                        row('Napomena', entry.note),
                        row('Izvor događaja', entry.eventSourceLabel),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
