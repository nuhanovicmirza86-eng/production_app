import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/premium_widgets.dart';
import '../../packing/services/packing_box_service.dart';
import '../models/production_dashboard_layout.dart';
import '../models/production_dashboard_module.dart';
import '../production_dashboard_access.dart';
import 'premium_home_icon_grid_metrics.dart';
import 'production_dashboard_action_tile.dart';
import 'production_dashboard_icon_grid_tile.dart';
import 'production_dashboard_module_group_header.dart';

class ProductionDashboardHomeModulesView extends StatelessWidget {
  static const double tileGap = 10;
  static const double sectionGap = 18;
  static const double afterHeader = 8;

  /// Classic ikonska mreža. Premium koristi [PremiumHomeIconGridMetrics].
  static int classicIconGridColumnCount(double screenWidth) {
    if (screenWidth >= 1200) return 6;
    if (screenWidth >= 900) return 5;
    if (screenWidth >= 600) return 4;
    return 3;
  }

  final ProductionDashboardLayout layout;
  final List<ProductionDashboardModuleSection> sections;
  final ProductionDashboardAccess access;

  const ProductionDashboardHomeModulesView({
    super.key,
    required this.layout,
    required this.sections,
    required this.access,
  });

  @override
  Widget build(BuildContext context) {
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
