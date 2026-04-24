/// Kanonski kalendarski ključ (YYYY-MM-DD) za Workforce F1 dokumente.
String workforceDateKey(DateTime localDay) {
  final d = DateTime(localDay.year, localDay.month, localDay.day);
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
