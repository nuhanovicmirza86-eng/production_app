import 'package:flutter/material.dart';

/// Gornja traka modula (kao na referentnom dashboardu): Pregled / Proizvodnja / …
/// [productionTabIndex] je indeks taba praćenja (0 = Pregled, 1+ = faze).
class ProductionTrackingHubNavStrip extends StatelessWidget {
  const ProductionTrackingHubNavStrip({
    super.key,
    required this.productionTabIndex,
    required this.onSelectPregled,
    required this.onSelectProizvodnjaFaze,
    required this.onSelectPlaceholder,
  });

  final int productionTabIndex;
  final VoidCallback onSelectPregled;
  final VoidCallback onSelectProizvodnjaFaze;
  final void Function(String label) onSelectPlaceholder;

  static const Color _barBg = Color(0xFF0E1117);
  static const Color _border = Color(0xFF2A2F3A);

  @override
  Widget build(BuildContext context) {
    final items = <_HubItem>[
      _HubItem(
        label: 'Pregled',
        hasDropdown: false,
        selected: productionTabIndex == 0,
        onTap: onSelectPregled,
      ),
      _HubItem(
        label: 'Proizvodnja',
        hasDropdown: true,
        selected: productionTabIndex > 0,
        onTap: onSelectProizvodnjaFaze,
      ),
      _HubItem(
        label: 'Kvaliteta',
        hasDropdown: true,
        selected: false,
        onTap: () => onSelectPlaceholder('Kvaliteta'),
      ),
      _HubItem(
        label: 'Stanja strojeva',
        hasDropdown: false,
        selected: false,
        onTap: () => onSelectPlaceholder('Stanja strojeva'),
      ),
      _HubItem(
        label: 'Radna snaga',
        hasDropdown: false,
        selected: false,
        onTap: () => onSelectPlaceholder('Radna snaga'),
      ),
      _HubItem(
        label: 'AI izvještaji',
        hasDropdown: false,
        selected: false,
        onTap: () => onSelectPlaceholder('AI izvještaji'),
      ),
    ];

    return Material(
      color: _barBg,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _HubChip(item: items[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HubItem {
  const _HubItem({
    required this.label,
    required this.hasDropdown,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool hasDropdown;
  final bool selected;
  final VoidCallback onTap;
}

class _HubChip extends StatelessWidget {
  const _HubChip({required this.item});

  final _HubItem item;

  @override
  Widget build(BuildContext context) {
    final fg = item.selected ? Colors.white : const Color(0xFF9CA3AF);
    final bg = item.selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: item.selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (item.hasDropdown) ...[
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 20, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
