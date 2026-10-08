import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/premium_widgets.dart';
import '../../packing/services/packing_box_service.dart';
import '../models/production_dashboard_layout.dart';
import '../models/production_dashboard_module.dart';
import '../production_dashboard_access.dart';
import 'premium_home_icon_grid_metrics.dart';
import 'production_classic_action_tile.dart';
import 'production_dashboard_action_tile.dart';
import 'production_dashboard_icon_grid_tile.dart';
import 'production_dashboard_module_group_header.dart';
import 'production_web_premium_action_tile.dart';

class ProductionDashboardHomeModulesView extends StatelessWidget {
  static const double tileGap = 10;
  static const double sectionGap = 18;
  static const double afterHeader = 8;

  /// Web Premium row cap. Android does not use this.
  static const double maxTileWidth = 320;

  static double tileWidthFor(double contentWidth) {
    if (!contentWidth.isFinite || contentWidth <= 0) return maxTileWidth;
    if (contentWidth <= maxTileWidth) return contentWidth;
    return maxTileWidth;
  }

  /// Android Classic icon grid. Same breakpoints as before the web hotfix.
  static int classicIconGridColumnCount(double screenWidth) {
    if (screenWidth >= 1200) return 6;
    if (screenWidth >= 900) return 5;
    if (screenWidth >= 600) return 4;
    return 3;
  }

  final ProductionDashboardLayout layout;
  final List<ProductionDashboardModuleSection> sections;
  final ProductionDashboardAccess access;

  /// Tests set this. Production uses [kIsWeb]. Width never selects the platform.
  final bool? useWebPresentation;

  const ProductionDashboardHomeModulesView({
    super.key,
    required this.layout,
    required this.sections,
    required this.access,
    this.useWebPresentation,
  });

  bool get _web => useWebPresentation ?? kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (_web && !OperonixVisualTokens.of(context).isPremium) {
      return _WebClassicView(sections: sections, access: access);
    }
    if (_web) {
      return _WebPremiumView(sections: sections, access: access);
    }
    return switch (layout) {
      ProductionDashboardLayout.standard => _StandardView(sections: sections),
      ProductionDashboardLayout.iconGrid => _IconGridView(
        sections: sections,
        access: access,
      ),
    };
  }
}

class _StandardView extends StatelessWidget {
  final List<ProductionDashboardModuleSection> sections;

  const _StandardView({required this.sections});

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (i > 0) out.add(const SizedBox(height: ProductionDashboardHomeModulesView.sectionGap));
      out.add(
        ProductionDashboardModuleGroupHeader(
          title: section.title,
          subtitle: section.subtitle,
          icon: section.icon,
        ),
      );
      out.add(const SizedBox(height: ProductionDashboardHomeModulesView.afterHeader));
      final entries = [
        for (final entry in section.entries) _buildStandardEntry(context, entry),
      ];
      if (OperonixVisualTokens.of(context).isPremium && entries.length > 1) {
        out.add(PremiumResponsiveGrid(children: entries));
      } else {
        for (var j = 0; j < entries.length; j++) {
          if (j > 0) {
            out.add(
              const SizedBox(height: ProductionDashboardHomeModulesView.tileGap),
            );
          }
          out.add(entries[j]);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }

  Widget _buildStandardEntry(
    BuildContext context,
    ProductionDashboardModuleEntry entry,
  ) {
    if (entry.customTileBuilder != null) {
      return entry.customTileBuilder!(context);
    }
    return ProductionDashboardActionTile(
      icon: entry.icon,
      title: entry.title,
      subtitle: entry.subtitle,
      noticeText: entry.noticeText,
      onTap: entry.onTap,
    );
  }
}

class _IconGridView extends StatelessWidget {
  final List<ProductionDashboardModuleSection> sections;
  final ProductionDashboardAccess access;

  const _IconGridView({
    required this.sections,
    required this.access,
  });

  @override
  Widget build(BuildContext context) {
    final premium = OperonixVisualTokens.of(context).isPremium;
    final screenWidth = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final crossAxisCount = premium
            ? PremiumHomeIconGridMetrics.columnCount(contentWidth)
            : ProductionDashboardHomeModulesView.classicIconGridColumnCount(
                screenWidth,
              );
        return _buildColumn(
          context,
          crossAxisCount: crossAxisCount,
          mainAxisExtent: premium
              ? PremiumHomeIconGridMetrics.tileExtentFor(contentWidth)
              : null,
        );
      },
    );
  }

  Widget _buildColumn(
    BuildContext context, {
    required int crossAxisCount,
    required double? mainAxisExtent,
  }) {
    final out = <Widget>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (i > 0) {
        out.add(const SizedBox(height: ProductionDashboardHomeModulesView.sectionGap));
      }
      out.add(
        ProductionDashboardModuleGroupHeader(
          title: section.title,
          subtitle: section.subtitle,
          icon: section.icon,
        ),
      );
      out.add(const SizedBox(height: ProductionDashboardHomeModulesView.afterHeader));
      out.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: ProductionDashboardHomeModulesView.tileGap,
            crossAxisSpacing: ProductionDashboardHomeModulesView.tileGap,
            mainAxisExtent: mainAxisExtent,
            childAspectRatio: mainAxisExtent == null ? 0.82 : 1,
          ),
          itemCount: section.entries.length,
          itemBuilder: (context, index) {
            return _buildIconEntry(context, section.entries[index]);
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }

  Widget _buildIconEntry(
    BuildContext context,
    ProductionDashboardModuleEntry entry,
  ) {
    if (entry.id == 'logistics.packed_boxes') {
      return StreamBuilder(
        stream: PackingBoxService().watchClosedPendingReceipt(
          companyId: access.companyId,
          plantKey: access.plantKey,
        ),
        builder: (context, snap) {
          final count = snap.data?.length ?? 0;
          return ProductionDashboardIconGridTile(
            icon: entry.icon,
            title: entry.title,
            badgeText: count > 0 ? access.packedBoxesPendingNotice(count) : null,
            onTap: entry.onTap,
          );
        },
      );
    }

    return ProductionDashboardIconGridTile(
      icon: entry.icon,
      title: entry.title,
      badgeText: entry.noticeText,
      onTap: entry.onTap,
    );
  }
}

class _WebClassicView extends StatelessWidget {
  final List<ProductionDashboardModuleSection> sections;
  final ProductionDashboardAccess access;

  const _WebClassicView({
    required this.sections,
    required this.access,
  });

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (i > 0) {
        out.add(const SizedBox(height: ProductionDashboardHomeModulesView.sectionGap));
      }
      out.add(
        ProductionDashboardModuleGroupHeader(
          title: section.title,
          subtitle: section.subtitle,
          icon: section.icon,
        ),
      );
      out.add(const SizedBox(height: ProductionDashboardHomeModulesView.afterHeader));
      out.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: ProductionClassicActionTile.maxCrossAxisExtent,
            mainAxisSpacing: ProductionClassicActionTile.gridSpacing,
            crossAxisSpacing: ProductionClassicActionTile.gridSpacing,
            childAspectRatio: ProductionClassicActionTile.childAspectRatio,
          ),
          itemCount: section.entries.length,
          itemBuilder: (context, index) {
            return _tile(context, section.entries[index]);
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }

  Widget _tile(BuildContext context, ProductionDashboardModuleEntry entry) {
    if (entry.customTileBuilder != null) {
      return entry.customTileBuilder!(context);
    }
    if (entry.id == 'logistics.packed_boxes') {
      return StreamBuilder(
        stream: PackingBoxService().watchClosedPendingReceipt(
          companyId: access.companyId,
          plantKey: access.plantKey,
        ),
        builder: (context, snap) {
          final count = snap.data?.length ?? 0;
          return ProductionClassicActionTile(
            icon: entry.icon,
            title: entry.title,
            noticeText: count > 0 ? access.packedBoxesPendingNotice(count) : null,
            onTap: entry.onTap,
          );
        },
      );
    }
    return ProductionClassicActionTile(
      icon: entry.icon,
      title: entry.title,
      noticeText: entry.noticeText,
      onTap: entry.onTap,
    );
  }
}

class _WebPremiumView extends StatelessWidget {
  final List<ProductionDashboardModuleSection> sections;
  final ProductionDashboardAccess access;

  const _WebPremiumView({
    required this.sections,
    required this.access,
  });

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (i > 0) {
        out.add(const SizedBox(height: ProductionDashboardHomeModulesView.sectionGap));
      }
      out.add(
        ProductionDashboardModuleGroupHeader(
          title: section.title,
          subtitle: section.subtitle,
          icon: section.icon,
        ),
      );
      out.add(const SizedBox(height: ProductionDashboardHomeModulesView.afterHeader));
      out.add(
        _WebPremiumWrap(
          children: [
            for (final entry in section.entries) _tile(context, entry),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }

  Widget _tile(BuildContext context, ProductionDashboardModuleEntry entry) {
    if (entry.customTileBuilder != null) {
      return entry.customTileBuilder!(context);
    }
    if (entry.id == 'logistics.packed_boxes') {
      return StreamBuilder(
        stream: PackingBoxService().watchClosedPendingReceipt(
          companyId: access.companyId,
          plantKey: access.plantKey,
        ),
        builder: (context, snap) {
          final count = snap.data?.length ?? 0;
          return ProductionWebPremiumActionTile(
            icon: entry.icon,
            title: entry.title,
            subtitle: entry.subtitle,
            noticeText: count > 0 ? access.packedBoxesPendingNotice(count) : null,
            onTap: entry.onTap,
          );
        },
      );
    }
    return ProductionWebPremiumActionTile(
      icon: entry.icon,
      title: entry.title,
      subtitle: entry.subtitle,
      noticeText: entry.noticeText,
      onTap: entry.onTap,
    );
  }
}

class _WebPremiumWrap extends StatelessWidget {
  final List<Widget> children;

  const _WebPremiumWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ProductionDashboardHomeModulesView.tileWidthFor(
          constraints.maxWidth,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: ProductionDashboardHomeModulesView.tileGap,
            runSpacing: ProductionDashboardHomeModulesView.tileGap,
            children: [
              for (final child in children) SizedBox(width: width, child: child),
            ],
          ),
        );
      },
    );
  }
}
