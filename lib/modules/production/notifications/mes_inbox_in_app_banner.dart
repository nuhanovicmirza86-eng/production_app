import 'package:flutter/material.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';

import 'mes_inbox_attention.dart';

/// NOTIF-M1-C-UI-HOTFIX-02 — kratak gornji signal, ne crni snackbar.
class MesInboxInAppBanner extends StatelessWidget {
  const MesInboxInAppBanner({
    super.key,
    required this.businessTitle,
    required this.onOpen,
    required this.onDismiss,
    this.accentColor = kOperonixProductionBrandGreen,
  });

  final String businessTitle;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = MesInboxAttention.inAppSubtitle(businessTitle);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        elevation: 4,
        color: theme.colorScheme.surface,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: accentColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        MesInboxAttention.inAppHeadline(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onOpen,
                  child: Text(MesInboxAttention.inAppOpenLabel()),
                ),
                IconButton(
                  tooltip: MesInboxAttention.inAppCloseTooltip(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MesInboxInAppBannerLayer extends StatelessWidget {
  const MesInboxInAppBannerLayer({
    super.key,
    required this.child,
    required this.arrival,
    required this.onOpen,
    required this.onDismiss,
    this.accentColor = kOperonixProductionBrandGreen,
  });

  final Widget child;
  final MesInboxArrival? arrival;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (arrival != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: MesInboxInAppBanner(
                businessTitle: arrival!.title,
                onOpen: onOpen,
                onDismiss: onDismiss,
                accentColor: accentColor,
              ),
            ),
          ),
      ],
    );
  }
}
