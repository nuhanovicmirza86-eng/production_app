import 'package:flutter/material.dart';

class KpiMetric {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const KpiMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class StandardScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  /// Ikone izvoza itd. — prikazuje se prije info dugmeta.
  final Widget? beforeInfoAction;
  final Widget? action;

  const StandardScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onInfo,
    this.beforeInfoAction,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        if (onBack != null) const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        if (beforeInfoAction != null) beforeInfoAction!,
        if (onInfo != null)
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: onInfo,
          ),
        action ?? const SizedBox.shrink(),
      ],
    );
  }
}

class StandardKpiGrid extends StatelessWidget {
  final List<KpiMetric> metrics;

  const StandardKpiGrid({super.key, required this.metrics});

  Widget _buildKpiCard(KpiMetric metric) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metric.value}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: metric.color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = metrics.take(4).toList();
    if (m.isEmpty) return const SizedBox.shrink();
    if (m.length <= 2) {
      return Row(
        children: [
          for (int i = 0; i < m.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(m[i])),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKpiCard(m[0])),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(m[1])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildKpiCard(m[2])),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(m[3])),
          ],
        ),
      ],
    );
  }
}

class StandardSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  /// Kompaktniji unos (npr. unutar sklopivog filter panela).
  final bool compact;

  const StandardSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final outline = cs.outlineVariant;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontSize: compact ? 14 : 16),
      decoration: InputDecoration(
        hintText: hintText,
        isDense: compact,
        prefixIcon: Icon(Icons.search, size: compact ? 20 : 24),
        filled: true,
        fillColor: cs.surface,
        contentPadding: pad,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

class StandardFilterPanel extends StatelessWidget {
  final bool expanded;
  final int activeCount;
  final VoidCallback onToggle;
  final Widget child;
  final String title;

  const StandardFilterPanel({
    super.key,
    required this.expanded,
    required this.activeCount,
    required this.onToggle,
    required this.child,
    this.title = 'Filteri',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (activeCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$activeCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, thickness: 1, color: cs.outlineVariant),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
            alignment: Alignment.topCenter,
          ),
        ],
      ),
    );
  }
}

