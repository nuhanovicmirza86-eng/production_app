import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Phone vs desktop composition for the whole Planning workspace.
///
/// A nested [LayoutBuilder] is not a safe signal. Its max width can be
/// unbounded or wider than the physical viewport (scroll views, intrinsic
/// parents, a tab page that expands to the incoming max). `infinity < 960`
/// is false, so that path selects the desktop panes and then lays them
/// into the real narrow box — the 157px right overflow.
///
/// Widget tests that pump the layout at 360/411 never built that parent,
/// so the nested width happened to equal the viewport and the tests passed.
///
/// The decision is the tighter of [MediaQuery.sizeOf] and the incoming box.
class PlanningViewport {
  const PlanningViewport._();

  /// Two panes. Below this, every Planning tab is one column.
  static const double multiColumnMinWidth = 960;

  /// Three Nalozi panes. Still keyed off the same viewport width.
  static const double ordersThreeColumnMinWidth = 1180;

  static double decisionWidth(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final viewport = MediaQuery.sizeOf(context).width;
    final incoming = constraints.maxWidth;
    if (!incoming.isFinite) return viewport;
    return math.min(incoming, viewport);
  }

  static bool multiColumn(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return decisionWidth(context, constraints) >= multiColumnMinWidth;
  }

  static bool ordersThreeColumn(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return decisionWidth(context, constraints) >= ordersThreeColumnMinWidth;
  }
}
