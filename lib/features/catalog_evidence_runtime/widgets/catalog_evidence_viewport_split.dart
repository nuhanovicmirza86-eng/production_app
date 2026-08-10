import 'package:flutter/material.dart';

/// M1-H3-F1H-R2 — globalni mobilni layout za operator evidencije s tabelom.
///
/// Na uskom viewportu: gornji dio kompaktan (intrinsic ili maxHeight),
/// tabela [Expanded]. Na širem: flex 5/4.
///
/// Koristi se u [ProfileDrivenWorkScreen] i [CatalogEvidenceStationScreen]
/// (chemical_dosing, wastewater_treatment, production_counting, budući profili).
class CatalogEvidenceViewportSplit extends StatelessWidget {
  const CatalogEvidenceViewportSplit({
    super.key,
    required this.topSection,
    required this.tableSection,
    this.topIsIntrinsic = false,
    this.compactBreakpoint = catalogEvidenceCompactViewportBreakpoint,
    this.compactTopMaxHeight = catalogEvidenceCompactTopMaxHeight,
  });

  /// Širina ispod koje vrijedi mobilni viewport (tabela dobija većinu visine).
  static const double catalogEvidenceCompactViewportBreakpoint = 600;

  /// Max visina gornjeg dijela na mobilnom kad forma nije intrinsic.
  static const double catalogEvidenceCompactTopMaxHeight = 300;

  final Widget topSection;
  final Widget tableSection;

  /// `true` za kompaktan launch header (bez sessiona) — intrinsic height.
  final bool topIsIntrinsic;

  final double compactBreakpoint;
  final double compactTopMaxHeight;

  static bool isCompactViewport(
    BuildContext context, {
    double breakpoint = catalogEvidenceCompactViewportBreakpoint,
  }) {
    return MediaQuery.sizeOf(context).width < breakpoint;
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactViewport(context, breakpoint: compactBreakpoint);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topIsIntrinsic)
            topSection
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: compactTopMaxHeight),
              child: topSection,
            ),
          const Divider(height: 1),
          Expanded(child: tableSection),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(flex: 5, child: topSection),
        const Divider(height: 1),
        Flexible(flex: 4, child: tableSection),
      ],
    );
  }
}
