import 'package:flutter/material.dart';

import '../models/qms_list_models.dart';
import '../utils/qms_ncr_display_labels.dart';

/// Premium kartica NCR zapisa na listi — statusni obrub + tekstualni badge.
class NcrListStatusCard extends StatelessWidget {
  const NcrListStatusCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  final QmsNcrRow row;
  final VoidCallback onTap;

  static String _formatDate(String? iso) {
    final raw = (iso ?? '').trim();
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.$y. $h:$min';
  }

  static String? _fromDescription(String desc, String label) {
    final m = RegExp('$label:\\s*([^.\\n]+)', caseSensitive: false).firstMatch(desc);
    final v = m?.group(1)?.trim();
    if (v == null || v.isEmpty) return null;
    return QmsNcrDisplayLabels.businessOrNull(v) ?? v;
  }

  static _NcrStatusStyle _styleFor(String statusCode) {
    switch (QmsNcrDisplayLabels.statusBorderGroup(statusCode)) {
      case 'in_progress':
        return const _NcrStatusStyle(
          border: Color(0xFF1565C0),
          badgeBg: Color(0xFFE3F2FD),
          badgeFg: Color(0xFF0D47A1),
        );
      case 'closed':
        return const _NcrStatusStyle(
          border: Color(0xFF2E7D32),
          badgeBg: Color(0xFFE8F5E9),
          badgeFg: Color(0xFF1B5E20),
        );
      case 'dismissed':
        return const _NcrStatusStyle(
          border: Color(0xFF757575),
          badgeBg: Color(0xFFF5F5F5),
          badgeFg: Color(0xFF424242),
        );
      case 'open':
      default:
        return const _NcrStatusStyle(
          border: Color(0xFFE65100),
          badgeBg: Color(0xFFFFF3E0),
          badgeFg: Color(0xFFBF360C),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = _styleFor(row.status);
    final statusLabel = QmsNcrDisplayLabels.status(row.status);
    final severityLabel = QmsNcrDisplayLabels.severity(row.severity);
    final sourceLabel = QmsNcrDisplayLabels.source(row.source);
    final desc = QmsNcrDisplayLabels.sanitizeUserFacingDescription(row.description);

    final product = QmsNcrDisplayLabels.businessOrNull(row.productId) ??
        _fromDescription(desc, 'Proizvod');
    final order = QmsNcrDisplayLabels.businessOrNull(row.productionOrderId) ??
        _fromDescription(desc, 'Nalog');

    final code = QmsNcrDisplayLabels.displayDocumentNumber(
      ncrDocumentNo: row.ncrDocumentNo,
      ncrCode: row.ncrCode,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: style.border, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _StatusBadge(
                      label: statusLabel,
                      background: style.badgeBg,
                      foreground: style.badgeFg,
                      border: style.border,
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.flag_outlined,
                      label: 'Ozbiljnost: $severityLabel',
                    ),
                    _MetaChip(
                      icon: Icons.source_outlined,
                      label: 'Izvor: $sourceLabel',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetaRow(label: 'Proizvod', value: product ?? 'Nije evidentirano'),
                const SizedBox(height: 4),
                _MetaRow(label: 'Nalog', value: order ?? 'Nije evidentirano'),
                const SizedBox(height: 4),
                _MetaRow(label: 'Datum', value: _formatDate(row.createdAtIso)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    desc,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                if ((row.partnerDisplayName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _MetaRow(
                    label: 'Partner',
                    value: row.partnerDisplayName!.trim(),
                  ),
                ],
                if ((row.externalClaimRef ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _MetaRow(
                    label: 'Vanjski br.',
                    value: row.externalClaimRef!.trim(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NcrStatusStyle {
  const _NcrStatusStyle({
    required this.border,
    required this.badgeBg,
    required this.badgeFg,
  });

  final Color border;
  final Color badgeBg;
  final Color badgeFg;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
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
    );
  }
}
