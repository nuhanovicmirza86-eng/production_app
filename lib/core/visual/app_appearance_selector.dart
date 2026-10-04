import 'package:flutter/material.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_layout_selector.dart';

import 'operonix_visual_tokens.dart';
import 'visual_experience_scope.dart';
import 'visual_style.dart';

/// Ekran iz tune akcije i web izbornika. Isti sadržaj kao [AppAppearanceSelector].
///
/// Odabir rasporeda se primjenjuje odmah, i ako roditelj još nije ponovo
/// izgradio ovu rutu.
class AppAppearanceScreen extends StatefulWidget {
  final ProductionDashboardLayout homeLayout;
  final ValueChanged<ProductionDashboardLayout> onHomeLayoutChanged;

  const AppAppearanceScreen({
    super.key,
    required this.homeLayout,
    required this.onHomeLayoutChanged,
  });

  @override
  State<AppAppearanceScreen> createState() => _AppAppearanceScreenState();
}

class _AppAppearanceScreenState extends State<AppAppearanceScreen> {
  late ProductionDashboardLayout _layout;

  @override
  void initState() {
    super.initState();
    _layout = widget.homeLayout;
  }

  @override
  void didUpdateWidget(covariant AppAppearanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.homeLayout != oldWidget.homeLayout) {
      _layout = widget.homeLayout;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izgled aplikacije')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppAppearanceSelector(
            homeLayout: _layout,
            onHomeLayoutChanged: (next) {
              setState(() => _layout = next);
              widget.onHomeLayoutChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

/// Izgled aplikacije: vizuelni stil, Premium tema i raspored početne.
class AppAppearanceSelector extends StatelessWidget {
  final ProductionDashboardLayout homeLayout;
  final ValueChanged<ProductionDashboardLayout> onHomeLayoutChanged;

  const AppAppearanceSelector({
    super.key,
    required this.homeLayout,
    required this.onHomeLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = VisualExperienceScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final style = controller.style;
    final tokens = OperonixVisualTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Izgled aplikacije',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: tokens.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Prikaz:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tokens.secondaryText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SegmentedButton<VisualStyle>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: VisualStyle.classic,
                    label: Text('Classic'),
                  ),
                  ButtonSegment(
                    value: VisualStyle.premium,
                    label: Text('Premium'),
                  ),
                ],
                selected: {style},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  controller.setStyle(selection.first);
                },
              ),
            ),
          ],
        ),
        if (style == VisualStyle.premium) ...[
          const SizedBox(height: 8),
          Text(
            'Tema: Midnight',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.secondaryText,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ProductionDashboardLayoutSelector(
          value: homeLayout,
          onChanged: onHomeLayoutChanged,
        ),
      ],
    );
  }
}
