import 'package:flutter/material.dart';

import 'ncr_action_hodogram_model.dart';

/// M1-I12-B — premium vizuelni hodogram akcije (NCR + Detalji evidencije).
class NcrActionHodogramTimeline extends StatelessWidget {
  const NcrActionHodogramTimeline({
    super.key,
    required this.snapshot,
    this.onFocusNextAction,
    this.compact = false,
  });

  final NcrHodogramSnapshot snapshot;
  final VoidCallback? onFocusNextAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final current = snapshot.steps.firstWhere(
      (s) => s.id == snapshot.currentStepId,
      orElse: () => snapshot.steps.last,
    );

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
                Icon(Icons.timeline, color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hodogram akcije',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pregled toka neusaglašenosti — status, odgovornost, rok i sljedeći korak.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final vertical = constraints.maxWidth < 560;
                if (vertical) {
                  return _VerticalRail(
                    steps: snapshot.steps,
                    onStepTap: _onStepTap,
                  );
                }
                return _HorizontalRail(
                  steps: snapshot.steps,
                  onStepTap: _onStepTap,
                );
              },
            ),
            const SizedBox(height: 16),
            _ContextPanel(
              step: current,
              nextHint: snapshot.headlineNextStep,
              onFocusNextAction: current.id == NcrHodogramStepId.nextAction
                  ? onFocusNextAction
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _onStepTap(NcrHodogramStepView step) {
    if (step.id == NcrHodogramStepId.nextAction) {
      onFocusNextAction?.call();
    }
  }
}

class _HorizontalRail extends StatelessWidget {
  const _HorizontalRail({
    required this.steps,
    required this.onStepTap,
  });

  final List<NcrHodogramStepView> steps;
  final void Function(NcrHodogramStepView step) onStepTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _Connector(
                    done: steps[i - 1].phase == NcrHodogramStepPhase.done ||
                        steps[i - 1].phase == NcrHodogramStepPhase.current,
                  ),
                ),
              SizedBox(
                width: 108,
                child: _StepNode(
                  step: steps[i],
                  onTap: () => onStepTap(steps[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerticalRail extends StatelessWidget {
  const _VerticalRail({
    required this.steps,
    required this.onStepTap,
  });

  final List<NcrHodogramStepView> steps;
  final void Function(NcrHodogramStepView step) onStepTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 16,
                  color: _connectorColor(context, steps[i - 1]),
                ),
              ),
            ),
          _StepNode(
            step: steps[i],
            horizontal: false,
            onTap: () => onStepTap(steps[i]),
          ),
        ],
      ],
    );
  }

  Color _connectorColor(BuildContext context, NcrHodogramStepView prev) {
    final scheme = Theme.of(context).colorScheme;
    if (prev.phase == NcrHodogramStepPhase.done ||
        prev.phase == NcrHodogramStepPhase.current) {
      return scheme.primary.withValues(alpha: 0.55);
    }
    return scheme.outlineVariant;
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: done
          ? scheme.primary.withValues(alpha: 0.55)
          : scheme.outlineVariant,
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.step,
    required this.onTap,
    this.horizontal = true,
  });

  final NcrHodogramStepView step;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = _nodeColors(context, step);
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: horizontal
            ? Column(
                children: [
                  _Dot(colors: colors, number: step.id.number),
                  const SizedBox(height: 8),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: step.phase == NcrHodogramStepPhase.current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Dot(colors: colors, number: step.id.number),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight:
                                step.phase == NcrHodogramStepPhase.current
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.summary,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
    return child;
  }
}

class _NodeColors {
  const _NodeColors({
    required this.fill,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color fill;
  final Color border;
  final Color foreground;
  final Color icon;
}

_NodeColors _nodeColors(BuildContext context, NcrHodogramStepView step) {
  final scheme = Theme.of(context).colorScheme;
  if (step.id == NcrHodogramStepId.nextAction && step.actionTone != null) {
    return _actionToneColors(context, step.actionTone!);
  }
  switch (step.phase) {
    case NcrHodogramStepPhase.done:
      return _NodeColors(
        fill: scheme.primaryContainer,
        border: scheme.primary,
        foreground: scheme.onSurface,
        icon: scheme.onPrimaryContainer,
      );
    case NcrHodogramStepPhase.current:
      return _NodeColors(
        fill: scheme.primary,
        border: scheme.primary,
        foreground: scheme.onSurface,
        icon: scheme.onPrimary,
      );
    case NcrHodogramStepPhase.notApplicable:
      return _NodeColors(
        fill: scheme.surfaceContainerHighest,
        border: scheme.outlineVariant,
        foreground: scheme.onSurfaceVariant,
        icon: scheme.onSurfaceVariant,
      );
    case NcrHodogramStepPhase.pending:
      return _NodeColors(
        fill: scheme.surface,
        border: scheme.outlineVariant,
        foreground: scheme.onSurfaceVariant,
        icon: scheme.onSurfaceVariant,
      );
  }
}

_NodeColors _actionToneColors(
  BuildContext context,
  NcrHodogramActionTone tone,
) {
  final scheme = Theme.of(context).colorScheme;
  switch (tone) {
    case NcrHodogramActionTone.idle:
      return _NodeColors(
        fill: const Color(0xFFE8E8E8),
        border: const Color(0xFF9E9E9E),
        foreground: scheme.onSurface,
        icon: const Color(0xFF616161),
      );
    case NcrHodogramActionTone.assigned:
      return _NodeColors(
        fill: const Color(0xFFD6E4FF),
        border: const Color(0xFF2962FF),
        foreground: scheme.onSurface,
        icon: const Color(0xFF1565C0),
      );
    case NcrHodogramActionTone.watch:
      return _NodeColors(
        fill: const Color(0xFFFFF3CD),
        border: const Color(0xFFF9A825),
        foreground: scheme.onSurface,
        icon: const Color(0xFFF57F17),
      );
    case NcrHodogramActionTone.critical:
      return _NodeColors(
        fill: const Color(0xFFFFCDD2),
        border: const Color(0xFFD32F2F),
        foreground: scheme.onSurface,
        icon: const Color(0xFFB71C1C),
      );
    case NcrHodogramActionTone.complete:
      return _NodeColors(
        fill: const Color(0xFFC8E6C9),
        border: const Color(0xFF2E7D32),
        foreground: scheme.onSurface,
        icon: const Color(0xFF1B5E20),
      );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.colors, required this.number});

  final _NodeColors colors;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.fill,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border, width: 2),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: colors.icon,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.step,
    this.nextHint,
    this.onFocusNextAction,
  });

  final NcrHodogramStepView step;
  final String? nextHint;
  final VoidCallback? onFocusNextAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final toneFill = step.actionTone != null
        ? _actionToneColors(context, step.actionTone!).fill
        : scheme.secondaryContainer.withValues(alpha: 0.4);

    return Material(
      color: toneFill,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trenutno: ${step.title}',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(step.summary, style: textTheme.bodyMedium),
            if (step.detailRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final row in step.detailRows) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          row.label,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.value,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if ((nextHint ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Sljedeći korak: ${nextHint!.trim()}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (onFocusNextAction != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onFocusNextAction,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: const Text('Idi na unos sljedeće akcije'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
