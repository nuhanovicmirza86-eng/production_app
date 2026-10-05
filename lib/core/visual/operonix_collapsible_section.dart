import 'package:flutter/material.dart';

import '../ui/standard_list_components.dart';
import 'operonix_visual_tokens.dart';
import 'premium/operonix_premium_icon.dart';
import 'premium/premium_icon_accent.dart';
import 'premium/premium_widgets.dart';

/// Isti sklopivi obrazac za filtere, postavke i radni kontekst.
///
/// Premium koristi piktogram i tamnu površinu. Classic zadržava
/// [StandardFilterPanel].
class OperonixCollapsibleSection extends StatelessWidget {
  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final OperonixPremiumGlyph glyph;
  final PremiumIconRole role;
  final int activeCount;

  const OperonixCollapsibleSection({
    super.key,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.child,
    required this.glyph,
    this.role = PremiumIconRole.info,
    this.activeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (OperonixVisualTokens.of(context).isPremium) {
      return PremiumFilterCard(
        title: title,
        summary: summary,
        expanded: expanded,
        activeCount: activeCount,
        onToggle: onToggle,
        glyph: glyph,
        role: role,
        child: child,
      );
    }
    return StandardFilterPanel(
      title: title,
      summary: summary,
      expanded: expanded,
      activeCount: activeCount,
      onToggle: onToggle,
      child: child,
    );
  }
}
