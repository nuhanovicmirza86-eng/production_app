import 'package:flutter/material.dart';

/// Globalni layout za operator evidencije s tabelom (M1-H3-F1H-R2 + M1-I2-D).
///
/// - Desktop / širi viewport: forma + tabela u split layoutu (flex 5/4).
/// - Mobile: forma skoro cijeli ekran; pregled je spuštena traka koja se
///   na tap otvara u donji panel (i vraća nazad).
///
/// Koristi se u [ProfileDrivenWorkScreen] i [CatalogEvidenceStationScreen].
class CatalogEvidenceViewportSplit extends StatefulWidget {
  const CatalogEvidenceViewportSplit({
    super.key,
    required this.topSection,
    required this.tableSection,
    this.topIsIntrinsic = false,
    this.compactBreakpoint = catalogEvidenceCompactViewportBreakpoint,
    this.compactTopMaxHeight = catalogEvidenceCompactTopMaxHeight,
    this.overviewRecordLimit,
    this.overviewRecordCount,
    this.overviewLoading = false,
  });

  /// Širina ispod koje vrijedi mobilni viewport.
  static const double catalogEvidenceCompactViewportBreakpoint = 600;

  /// Legacy: max visina gornjeg dijela (više se ne koristi za fiksni split).
  static const double catalogEvidenceCompactTopMaxHeight = 300;

  /// Visina otvorenog panela pregleda (udio ekrana).
  static const double catalogEvidenceMobileOverviewPanelFraction = 0.48;

  final Widget topSection;
  final Widget tableSection;

  /// `true` za kompaktan launch header (bez sessiona) — desktop only hint.
  final bool topIsIntrinsic;

  final double compactBreakpoint;
  final double compactTopMaxHeight;

  /// Limit selektora „Zadnjih N“ (za mobilnu traku).
  final int? overviewRecordLimit;

  /// Broj redova u pregledu (zatvoreni + aktivni ako je uključen).
  final int? overviewRecordCount;

  final bool overviewLoading;

  static bool isCompactViewport(
    BuildContext context, {
    double breakpoint = catalogEvidenceCompactViewportBreakpoint,
  }) {
    return MediaQuery.sizeOf(context).width < breakpoint;
  }

  @override
  State<CatalogEvidenceViewportSplit> createState() =>
      _CatalogEvidenceViewportSplitState();
}

class _CatalogEvidenceViewportSplitState
    extends State<CatalogEvidenceViewportSplit> {
  bool _overviewExpanded = false;

  @override
  Widget build(BuildContext context) {
    final compact = CatalogEvidenceViewportSplit.isCompactViewport(
      context,
      breakpoint: widget.compactBreakpoint,
    );
    if (compact) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout();
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(flex: 5, child: widget.topSection),
        const Divider(height: 1),
        Flexible(flex: 4, child: widget.tableSection),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final panelH = (screenH *
            CatalogEvidenceViewportSplit
                .catalogEvidenceMobileOverviewPanelFraction)
        .clamp(220.0, 420.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: widget.topSection),
        if (_overviewExpanded)
          SizedBox(
            height: panelH,
            child: Material(
              elevation: 6,
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OverviewHandleBar(
                    expanded: true,
                    recordLimit: widget.overviewRecordLimit,
                    recordCount: widget.overviewRecordCount,
                    loading: widget.overviewLoading,
                    onTap: () => setState(() => _overviewExpanded = false),
                  ),
                  const Divider(height: 1),
                  Expanded(child: widget.tableSection),
                ],
              ),
            ),
          )
        else
          _OverviewHandleBar(
            expanded: false,
            recordLimit: widget.overviewRecordLimit,
            recordCount: widget.overviewRecordCount,
            loading: widget.overviewLoading,
            onTap: () => setState(() => _overviewExpanded = true),
          ),
      ],
    );
  }
}

class _OverviewHandleBar extends StatelessWidget {
  const _OverviewHandleBar({
    required this.expanded,
    required this.onTap,
    this.recordLimit,
    this.recordCount,
    this.loading = false,
  });

  final bool expanded;
  final VoidCallback onTap;
  final int? recordLimit;
  final int? recordCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final parts = <String>['Pregled evidencija'];
    if (recordLimit != null && recordLimit! > 0) {
      parts.add('Zadnjih $recordLimit');
    }
    if (loading) {
      parts.add('Učitavanje…');
    } else if (recordCount != null && recordLimit != null) {
      parts.add('$recordCount/$recordLimit zapisa');
    } else if (recordCount != null) {
      parts.add('$recordCount zapisa');
    }

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 8, 10 + (expanded ? 0 : bottomInset)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  parts.join(' · '),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
