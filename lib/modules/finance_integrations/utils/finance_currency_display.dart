import 'package:intl/intl.dart';

/// Prikaz novca: agregati u Firestore-u su uvijek u [baseCurrency]; UI množi u [displayCurrency].
/// Tečaj: kolekcija `exchange_rates/{yyyy-MM-dd}` ili privremeni fallback EUR→BAM.
abstract final class FinanceCurrencyDisplay {
  /// Privremeni fallback ako nema dokumenta u `exchange_rates` (EUR→BAM).
  static const double fallbackEurToBam = 1.95583;

  /// Koliko jedinica [displayCurrency] po jednoj jedinici [baseCurrency].
  static double unitsOfDisplayPerOneBase({
    required String baseCurrency,
    required String displayCurrency,
    Map<String, dynamic>? exchangeRatesDoc,
  }) {
    final b = baseCurrency.toUpperCase();
    final d = displayCurrency.toUpperCase();
    if (b == d) return 1.0;

    final ratesRaw = exchangeRatesDoc?['rates'];
    final rates = <String, double>{};
    if (ratesRaw is Map) {
      for (final e in ratesRaw.entries) {
        final v = e.value;
        if (v is num) {
          rates[e.key.toString().trim().toUpperCase()] = v.toDouble();
        }
      }
    }
    final docBase = (exchangeRatesDoc?['base'] ?? '').toString().trim().toUpperCase();
    if (docBase.isNotEmpty && docBase == b && rates.containsKey(d)) {
      return rates[d]!;
    }
    if (b == 'EUR' && d == 'BAM') {
      return rates['BAM'] ?? fallbackEurToBam;
    }
    return 1.0;
  }

  /// `true` kad je faktor iz dokumenta `exchange_rates` (isti `base` i postoji kotacija za prikaz).
  static bool displayRateUsesFirestoreDoc({
    required String baseCurrency,
    required String displayCurrency,
    Map<String, dynamic>? exchangeRatesDoc,
  }) {
    final b = baseCurrency.toUpperCase();
    final d = displayCurrency.toUpperCase();
    if (b == d) return false;
    final ratesRaw = exchangeRatesDoc?['rates'];
    if (ratesRaw is! Map) return false;
    final docBase = (exchangeRatesDoc?['base'] ?? '').toString().trim().toUpperCase();
    if (docBase.isEmpty || docBase != b) return false;
    for (final e in ratesRaw.entries) {
      if (e.key.toString().trim().toUpperCase() != d) continue;
      final v = e.value;
      return v is num && v.toDouble() > 0;
    }
    return false;
  }

  /// Jedna rečenica za podnožje KPI (izvor tečaja).
  static String describeDisplayRateSource({
    required String baseCurrency,
    required String displayCurrency,
    Map<String, dynamic>? exchangeRatesDoc,
  }) {
    final b = baseCurrency.toUpperCase();
    final d = displayCurrency.toUpperCase();
    if (b == d) {
      return 'Prikaz u istoj valuti kao baza — bez konverzije.';
    }
    final fx = unitsOfDisplayPerOneBase(
      baseCurrency: b,
      displayCurrency: d,
      exchangeRatesDoc: exchangeRatesDoc,
    );
    final fromDoc = displayRateUsesFirestoreDoc(
      baseCurrency: b,
      displayCurrency: d,
      exchangeRatesDoc: exchangeRatesDoc,
    );
    if (fromDoc) {
      return 'Tečaj: 1 $b = ${fx.toStringAsFixed(5)} $d (današnji službeni zapis '
          'u postavkama Operonixa).';
    }
    if (b == 'EUR' && d == 'BAM') {
      return 'Tečaj: 1 $b = ${fx.toStringAsFixed(5)} $d (podrazumijevana vrijednost '
          'dok ne učitamo dnevni tečaj iz postavki).';
    }
    return 'Tečaj: 1 $b = ${fx.toStringAsFixed(5)} $d (provjerite postavke tečaja i par valuta).';
  }

  static double toDisplayAmount(
    double amountBase, {
    required String baseCurrency,
    required String displayCurrency,
    Map<String, dynamic>? exchangeRatesDoc,
  }) {
    return amountBase *
        unitsOfDisplayPerOneBase(
          baseCurrency: baseCurrency,
          displayCurrency: displayCurrency,
          exchangeRatesDoc: exchangeRatesDoc,
        );
  }

  static String formatBaseAmountForDisplay(
    double amountBase, {
    required String baseCurrency,
    required String displayCurrency,
    required String locale,
    Map<String, dynamic>? exchangeRatesDoc,
  }) {
    final disp = FinanceCurrencyDisplay.toDisplayAmount(
      amountBase,
      baseCurrency: baseCurrency,
      displayCurrency: displayCurrency,
      exchangeRatesDoc: exchangeRatesDoc,
    );
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: displayCurrency,
    ).format(disp);
  }
}
