import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../packing/services/packing_box_service.dart';
import '../models/production_dashboard_layout.dart';
import '../models/production_dashboard_module.dart';
import '../production_dashboard_access.dart';
import 'production_classic_action_tile.dart';
import 'production_dashboard_action_tile.dart';
import 'production_dashboard_module_group_header.dart';

class ProductionDashboardHomeModulesView extends StatelessWidget {
  static const double tileGap = 10;
  static const double sectionGap = 18;
  static const double afterHeader = 8;

  /// Compact action tile. A wider screen adds another tile; it does not
  /// stretch one card into a large empty rectangle.
  static const double maxTileWidth = 320;

  static double tileWidthFor(double contentWidth) {
    if (!contentWidth.isFinite || contentWidth <= 0) return maxTileWidth;
    if (contentWidth <= maxTileWidth) return contentWidth;
    return maxTileWidth;
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
      out.add(
        _QuickActionWrap(
          children: [
            for (final entry in section.entries)
              _buildStandardEntry(context, entry),
          ],
        ),
      );
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
    return _actionTile(context, entry, noticeText: entry.noticeText);
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
        _QuickActionWrap(
          children: [
            for (final entry in section.entries)
              _buildIconEntry(context, entry),
          ],
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
          return _actionTile(
            context,
            entry,
            noticeText: count > 0 ? access.packedBoxesPendingNotice(count) : null,
          );
        },
      );
    }

    return _actionTile(context, entry, noticeText: entry.noticeText);
  }
}

Widget _actionTile(
  BuildContext context,
  ProductionDashboardModuleEntry entry, {
  String? noticeText,
}) {
  if (entry.customTileBuilder != null) {
    return entry.customTileBuilder!(context);
  }
  if (OperonixVisualTokens.of(context).isPremium) {
    return ProductionDashboardActionTile(
      icon: entry.icon,
      title: entry.title,
      subtitle: entry.subtitle,
      noticeText: noticeText,
      onTap: entry.onTap,
    );
  }
  return ProductionClassicActionTile(
    icon: entry.icon,
    title: entry.title,
    noticeText: noticeText,
    onTap: entry.onTap,
  );
}

class _QuickActionWrap extends StatelessWidget {
  final List<Widget> children;

  const _QuickActionWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final premium = OperonixVisualTokens.of(context).isPremium;
        final width = premium
            ? ProductionDashboardHomeModulesView.tileWidthFor(
                constraints.maxWidth,
              )
            : ProductionClassicActionTile.tileWidthFor(constraints.maxWidth);
        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: ProductionDashboardHomeModulesView.tileGap,
            runSpacing: ProductionDashboardHomeModulesView.tileGap,
            children: [
              for (final child in children)
                SizedBox(
                  width: width,
                  height: premium ? null : ProductionClassicActionTile.tileHeight,
                  child: child,
                ),
            ],
          ),
        );
      },
    );
  }
}
