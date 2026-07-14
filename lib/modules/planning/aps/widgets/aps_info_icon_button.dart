import 'package:flutter/material.dart';

import '../helpers/aps_gantt_info_copy.dart';

/// Kompaktna info ikonica (P5.4) — samo na ključnim mjestima.
class ApsInfoIconButton extends StatelessWidget {
  const ApsInfoIconButton({
    super.key,
    required this.tooltip,
    required this.title,
    required this.body,
    this.size = 20,
  });

  final String tooltip;
  final String title;
  final String body;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 8, minHeight: size + 8),
      tooltip: tooltip,
      icon: Icon(Icons.info_outline, size: size),
      onPressed: () => showApsGanttInfoDialog(
        context,
        title: title,
        body: body,
      ),
    );
  }
}
