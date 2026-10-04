import 'package:flutter/material.dart';

import 'operonix_visual_tokens.dart';
import 'visual_experience_scope.dart';
import 'visual_style.dart';

/// Ekran iz Više / izbornika. Isti lokalni izbor kao [AppAppearanceSelector].
class AppAppearanceScreen extends StatelessWidget {
  const AppAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izgled aplikacije')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [AppAppearanceSelector()],
      ),
    );
  }
}

/// Izgled aplikacije. Nezamjenjuje prikaz Standardno / Ikone.
class AppAppearanceSelector extends StatelessWidget {
  const AppAppearanceSelector({super.key});

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
      ],
    );
  }
}
