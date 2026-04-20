import 'package:flutter/material.dart';

/// Pregled zona i IATF zahtjeva — tab „Pregled“ na centralnom hubu.
class LogisticsHubOverviewTab extends StatelessWidget {
  const LogisticsHubOverviewTab({
    super.key,
    this.onNavigateToHubTab,
  });

  /// Kad je postavljen, klik na karticu zone skače na povezani tab.
  final void Function(int tabIndex)? onNavigateToHubTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const zones = <_ZoneInfo>[
      _ZoneInfo(
        title: 'Receiving',
        subtitle: 'Prijem',
        icon: Icons.move_to_inbox_outlined,
        detail: 'Ulaz robe, dokumenti, generisanje LOT-a → karantin.',
        hubTabIndex: 2,
        tabHint: 'Prijem',
      ),
      _ZoneInfo(
        title: 'Quarantine',
        subtitle: 'Karantin',
        icon: Icons.shield_outlined,
        detail: 'Roba čeka odluku kvaliteta (QUARANTINE).',
        hubTabIndex: 3,
        tabHint: 'Kvaliteta',
      ),
      _ZoneInfo(
        title: 'Approved stock',
        subtitle: 'Odobreno',
        icon: Icons.check_circle_outline,
        detail: 'Nakon odobrenja — dostupno za putaway / FIFO.',
        hubTabIndex: 4,
        tabHint: 'Putaway',
      ),
      _ZoneInfo(
        title: 'Blocked stock',
        subtitle: 'Blokirano',
        icon: Icons.block,
        detail: 'Izolacija — ne smije u proizvodnju / otpremu.',
        hubTabIndex: 3,
        tabHint: 'Kvaliteta',
      ),
      _ZoneInfo(
        title: 'Picking / staging',
        subtitle: 'Priprema',
        icon: Icons.view_module_outlined,
        detail: 'Zona pripreme za izdavanje (FIFO red).',
        hubTabIndex: 5,
        tabHint: 'FIFO',
      ),
      _ZoneInfo(
        title: 'Shipping',
        subtitle: 'Otpremna',
        icon: Icons.local_shipping_outlined,
        detail: 'Završna zona prije otpreme kupcu.',
        hubTabIndex: 6,
        tabHint: 'Otpremna',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Centralni magacin obuhvata logistiku, kvalitet, sljedljivost (LOT) i '
          'kontrolu procesa (FIFO). Bez sva četiri stuba sistem nije ozbiljan za IATF.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 16),
        Text(
          'Zone (fizički i sistemski)',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cross = w >= 700 ? 3 : (w >= 480 ? 2 : 1);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cross,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: w >= 700 ? 1.15 : 1.05,
              children: zones
                  .map(
                    (z) {
                      final interactive = onNavigateToHubTab != null;
                      final cardChild = Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(z.icon, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    z.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (interactive)
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: theme.colorScheme.outline,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              z.subtitle,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              z.detail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      );

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: interactive
                            ? InkWell(
                                onTap: () =>
                                    onNavigateToHubTab!(z.hubTabIndex),
                                child: Tooltip(
                                  message:
                                      'Otvori tab: ${z.tabHint}',
                                  child: cardChild,
                                ),
                              )
                            : cardChild,
                      );
                    },
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'IATF — šta mora biti ispunjeno',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _bullet(theme, 'Sljedljivost: koji LOT je gdje i u kojem proizvodu / kod kupca.'),
        _bullet(theme, 'Status: QUARANTINE / APPROVED / BLOCKED — bez miješanja „sive“ robe.'),
        _bullet(theme, 'Audit: ko je što uradio, kada, na kojem LOT-u (Callable + company_audit_logs gdje je predviđeno).'),
        _bullet(theme, 'Identifikacija: barkod / QR na LOT-u i paleti (sken-first gdje je implementirano).'),
        _bullet(theme, 'FIFO: sistem predlaže najstariji LOT; ručni override zahtijeva audit (kad uvedemo override).'),
        const SizedBox(height: 12),
        Text(
          onNavigateToHubTab != null
              ? 'Klik na zonu otvara odgovarajući tab ispod. Ili ručno: Master (MAG_*), '
                  'Prijem → Kvaliteta → Putaway → FIFO → Otpremna → Evidencija → Rute → '
                  'Korekcije → Interne; QR je alat za sken (zadnji tab).'
              : 'Koristi tabove ispod. QR je alat za sken.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: theme.textTheme.bodyMedium),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ZoneInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final String detail;
  final int hubTabIndex;
  final String tabHint;

  const _ZoneInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.detail,
    required this.hubTabIndex,
    required this.tabHint,
  });
}
