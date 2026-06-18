/// Kanonske operativne valute Finance Cash Flow modula (tenant normativ).
abstract final class FinanceOperatingCurrencies {
  static const codes = ['EUR', 'BAM'];

  static bool isAllowed(String? raw) {
    final c = (raw ?? '').trim().toUpperCase();
    return c.length == 3 && codes.contains(c);
  }

  static String normalize(String? raw, {String fallback = 'EUR'}) {
    final c = (raw ?? '').trim().toUpperCase();
    if (isAllowed(c)) return c;
    return fallback;
  }
}
