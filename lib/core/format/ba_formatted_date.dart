/// Potpuni datum i datum+vrijeme na bosanskom/hrvatskom (bez oslanjanja na EN Material lokal).
class BaFormattedDate {
  BaFormattedDate._();

  static const _weekdays = <String>[
    'ponedjeljak',
    'utorak',
    'srijeda',
    'četvrtak',
    'petak',
    'subota',
    'nedjelja',
  ];

  static const _months = <String>[
    'januar',
    'februar',
    'mart',
    'april',
    'maj',
    'juni',
    'juli',
    'august',
    'septembar',
    'oktobar',
    'novembar',
    'decembar',
  ];

  /// Npr. "utorak, 21. april 2026."
  static String formatFullDate(DateTime d) {
    final local = d.toLocal();
    final wd = _weekdays[local.weekday - 1];
    final mo = _months[local.month - 1];
    return '$wd, ${local.day}. $mo ${local.year}.';
  }

  /// Npr. "utorak, 21. april 2026. u 14:05"
  static String formatDateTime(DateTime d) {
    final local = d.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${formatFullDate(local)} u $h:$min';
  }
}
