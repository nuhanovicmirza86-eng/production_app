import 'package:flutter/material.dart';

/// Kanonski kodovi smjena u bazi — u UI-u uvijek ljudski naziv na bosanskom.
abstract final class WorkforceShiftLabels {
  static const day = 'DAY';
  static const night = 'NIGHT';
  static const afternoon = 'AFTERNOON';
  static const all = '_ALL';

  static String label(String code) {
    switch (code.trim()) {
      case day:
        return 'Dnevna smjena';
      case night:
        return 'Noćna smjena';
      case afternoon:
        return 'Popodnevna smjena';
      case all:
        return 'Sve smjene';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static String shortLabel(String code) => label(code).replaceAll(' smjena', '');

  static List<DropdownMenuItem<String>> dropdownItems({
    bool includeAll = false,
  }) {
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: day, child: Text(label(day))),
      DropdownMenuItem(value: night, child: Text(label(night))),
      DropdownMenuItem(value: afternoon, child: Text(label(afternoon))),
    ];
    if (includeAll) {
      items.add(DropdownMenuItem(value: all, child: Text(label(all))));
    }
    return items;
  }

  static List<PopupMenuEntry<String>> popupEntries({bool includeAll = false}) {
    final codes = [day, night, afternoon];
    if (includeAll) codes.add(all);
    return codes
        .map(
          (code) => PopupMenuItem<String>(
            value: code,
            child: Text(label(code)),
          ),
        )
        .toList();
  }
}
