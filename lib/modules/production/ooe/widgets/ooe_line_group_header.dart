import 'package:flutter/material.dart';

/// Naslov grupe na OOE live kad se kartice slažu po liniji.
class OoeLineGroupHeader extends StatelessWidget {
  const OoeLineGroupHeader({
    super.key,
    required this.lineKey,
    required this.lineDisplayNameByKey,
  });

  /// `null` ili prazan = strojevi bez dodijeljene linije.
  final String? lineKey;

  final Map<String, String> lineDisplayNameByKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final k = lineKey?.trim();
    if (k == null || k.isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.linear_scale_outlined, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bez dodijeljene linije',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
            ),
          ),
        ],
      );
    }

    final rawName = lineDisplayNameByKey[k]?.trim();
    final hasName = rawName != null && rawName.isNotEmpty;
    final title = hasName ? rawName : 'Linija';
    final subtitle = hasName ? 'Referenca: $k' : 'Poslovna šifra: $k';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_tree_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 2),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
