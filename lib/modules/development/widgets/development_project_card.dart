import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';

/// Kartica projekta u portfelju — Stage-Gate, KPI, vlasništvo (enterprise prikaz).
class DevelopmentProjectCard extends StatelessWidget {
  const DevelopmentProjectCard({
    super.key,
    required this.project,
    this.onTap,
  });

  final DevelopmentProjectModel project;
  final VoidCallback? onTap;

  Color _statusColor(ColorScheme scheme, String status) {
    switch (status.trim()) {
      case DevelopmentProjectStatuses.active:
      case DevelopmentProjectStatuses.approved:
        return scheme.primary;
      case DevelopmentProjectStatuses.atRisk:
      case DevelopmentProjectStatuses.delayed:
        return scheme.error;
      case DevelopmentProjectStatuses.completed:
        return scheme.tertiary;
      case DevelopmentProjectStatuses.closed:
      case DevelopmentProjectStatuses.cancelled:
        return scheme.outline;
      default:
        return scheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final health = project.kpi.overallHealthScore;
    final statusColor = _statusColor(scheme, project.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      project.currentGate.isEmpty ? '—' : project.currentGate,
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.projectName.isEmpty
                              ? 'Projekat'
                              : project.projectName,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.projectCode.isEmpty
                              ? '—'
                              : project.projectCode,
                          style: tt.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                DevelopmentDisplay.projectTypeLabel(project.projectType),
                style: tt.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if ((project.customerName ?? '').trim().isNotEmpty ||
                  (project.productName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if ((project.customerName ?? '').trim().isNotEmpty)
                      'Kupac: ${project.customerName!.trim()}',
                    if ((project.productName ?? '').trim().isNotEmpty)
                      'Proizvod: ${project.productName!.trim()}',
                  ].join(' · '),
                  style: tt.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    label: Text(
                      DevelopmentDisplay.projectStatusLabel(project.status),
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (project.businessYearLabel.isNotEmpty ||
                      project.businessYearId.isNotEmpty)
                    Chip(
                      avatar: Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: scheme.secondary,
                      ),
                      label: Text(
                        project.businessYearLabel.isNotEmpty
                            ? project.businessYearLabel
                            : project.businessYearId,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  Chip(
                    avatar: Icon(
                      Icons.person_outline,
                      size: 18,
                      color: scheme.tertiary,
                    ),
                    label: Text(
                      project.projectManagerName.isEmpty
                          ? 'PM —'
                          : 'PM: ${project.projectManagerName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Chip(
                    label: Text(
                      'Faza: ${project.currentStage.isEmpty ? '—' : project.currentStage}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Chip(
                    label: Text(
                      'Prioritet: ${DevelopmentDisplay.projectPriorityLabel(project.priority)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (project.riskLevel.isNotEmpty)
                    Chip(
                      label: Text(
                        'Rizik: ${DevelopmentDisplay.riskSeverityLabel(project.riskLevel)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Napredak',
                          style: tt.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (project.progressPercent.clamp(0, 100)) /
                                100.0,
                            minHeight: 8,
                            backgroundColor:
                                scheme.surfaceContainerHighest.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${project.progressPercent}%',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (health != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Health (KPI): ${health.toStringAsFixed(0)}',
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
