/// Format `dd.MM.yyyy` za filter / PDF.
String formatCalendarDay(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Inkluzivni filter po kalendarskom danu (lokalni Y/M/D).
bool dateInInclusiveRange(DateTime? value, DateTime? from, DateTime? to) {
  if (from == null && to == null) return true;
  if (value == null) return false;
  final d = DateTime(value.year, value.month, value.day);
  if (from != null) {
    final f = DateTime(from.year, from.month, from.day);
    if (d.isBefore(f)) return false;
  }
  if (to != null) {
    final t = DateTime(to.year, to.month, to.day);
    if (d.isAfter(t)) return false;
  }
  return true;
}
